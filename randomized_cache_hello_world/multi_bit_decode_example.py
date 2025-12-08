#!/usr/bin/env python
import argparse
import json
import os
import sys


def parse_thresholds(raw):
    if raw is None:
        return []
    parts = [p.strip() for p in str(raw).split(',') if p.strip()]
    thresholds = []
    for part in parts:
        try:
            thresholds.append(float(part))
        except ValueError:
            pass
    return thresholds


def parse_symbols(raw):
    if raw is None:
        return []
    return [s.strip() for s in str(raw).split(',') if s.strip()]


def read_stats_file(path):
    stats = {}
    with open(path, 'r') as handle:
        for line in handle:
            parts = line.strip().split()
            if len(parts) < 2:
                continue
            key = parts[0]
            try:
                val = float(parts[-1])
            except ValueError:
                continue
            stats[key] = val
    return stats


def resolve_paths(path):
    if os.path.isdir(path):
        stats_path = os.path.join(path, 'stats.txt')
    else:
        stats_path = path
        path = os.path.dirname(path)
    metadata_path = os.path.join(path, 'spec_metadata.json') if path else None
    return stats_path, metadata_path


def extract_group_values(stats, group_count):
    groups = []
    for key, val in stats.items():
        if not key.startswith('system.l2.tags.occ_group::'):
            continue
        try:
            idx = int(key.split('::', 1)[1])
        except (IndexError, ValueError):
            continue
        groups.append((idx, val))

    if groups:
        ordered = [val for _, val in sorted(groups, key=lambda item: item[0])]
        return ordered, 'group'

    legacy = []
    for idx in range(group_count):
        key = 'system.l2.tags.occ_group::%s' % idx
        if key in stats:
            legacy.append(stats[key])
    if legacy:
        return legacy, 'group'

    return None


def extract_occupancies(stats, group_count, task_id):
    group_values = extract_group_values(stats, group_count)
    if group_values:
        return group_values

    task_key = 'system.l2.tags.occ_task_id_percent::%s' % task_id
    if task_key in stats:
        return [stats[task_key]], 'task'

    total_key = 'system.l2.tags.occ_percent::total'
    if total_key in stats:
        return [stats[total_key]], 'total'

    return [], 'missing'


def decode_value(value, thresholds, symbols):
    for idx, threshold in enumerate(thresholds):
        if value < threshold:
            return symbols[idx]
    return symbols[-1]


def decode_occupancies(values, thresholds, symbols):
    decoded = []
    for value in values:
        decoded.append(decode_value(value, thresholds, symbols))
    return ''.join(decoded)


def load_metadata(metadata_path, key):
    if not metadata_path or not os.path.isfile(metadata_path):
        return None
    try:
        with open(metadata_path, 'r') as handle:
            data = json.load(handle)
    except Exception:
        return None

    if key in data:
        return str(data[key])
    upper_key = key.upper()
    lower_key = key.lower()
    for candidate in [upper_key, lower_key, 'SYMBOLS', 'symbols']:
        if candidate in data:
            return str(data[candidate])
    return None


def parse_truth(raw):
    if raw is None:
        return []
    if ',' in raw:
        return [p for p in parse_symbols(raw) if p]
    return list(str(raw))


def format_values(values):
    return ','.join(['%.2f' % v for v in values])


def handle_decode(args):
    thresholds = parse_thresholds(args.thresholds)
    symbols = parse_symbols(args.symbols)
    if not thresholds:
        thresholds = [50.0]
    if not symbols:
        symbols = ['0', '1']
    if len(symbols) != len(thresholds) + 1:
        sys.stderr.write('Symbol count must be thresholds+1\n')
        return 1

    decoded_stream = []
    for path in args.stats:
        stats_path, metadata_path = resolve_paths(path)
        if not os.path.isfile(stats_path):
            sys.stderr.write('Missing stats file: %s\n' % stats_path)
            continue
        stats = read_stats_file(stats_path)
        occupancies, mode = extract_occupancies(stats, args.groups, args.task_id)
        if not occupancies:
            sys.stderr.write('No occupancy counters in %s\n' % stats_path)
            continue
        decoded = decode_occupancies(occupancies, thresholds, symbols)
        decoded_stream.append(decoded)
        label = os.path.basename(os.path.dirname(stats_path)) or os.path.basename(stats_path)
        metadata_symbols = load_metadata(metadata_path, args.metadata_key)
        parts = [label, 'mode=%s' % mode, 'occ=[%s]' % format_values(occupancies), 'decoded=%s' % decoded]
        if metadata_symbols:
            parts.append('truth=%s' % metadata_symbols)
        print(' | '.join(parts))

    if decoded_stream:
        print('Decoded stream: %s' % ''.join(decoded_stream))
    return 0


def summarize_bucket(values):
    if not values:
        return None
    total = sum(values)
    count = len(values)
    mean = total / float(count)
    return {'count': count, 'min': min(values), 'max': max(values), 'mean': mean}


def handle_calibrate(args):
    buckets = {}
    seen_runs = 0
    for path in args.stats:
        stats_path, metadata_path = resolve_paths(path)
        if not os.path.isfile(stats_path):
            sys.stderr.write('Missing stats file: %s\n' % stats_path)
            continue
        truth_raw = load_metadata(metadata_path, args.metadata_key)
        truth = parse_truth(truth_raw)
        if not truth:
            sys.stderr.write('No metadata for %s, skipping\n' % stats_path)
            continue
        stats = read_stats_file(stats_path)
        occupancies, mode = extract_occupancies(stats, args.groups, args.task_id)
        if not occupancies:
            sys.stderr.write('No occupancy counters in %s\n' % stats_path)
            continue
        seen_runs += 1
        label = os.path.basename(os.path.dirname(stats_path)) or os.path.basename(stats_path)
        print('%s | mode=%s | occ=[%s] | truth=%s' % (label, mode, format_values(occupancies), ''.join(truth)))
        limit = min(len(occupancies), len(truth))
        for idx in range(limit):
            symbol = truth[idx]
            buckets.setdefault(symbol, []).append(occupancies[idx])
        if limit < len(occupancies) or limit < len(truth):
            sys.stderr.write('Warning: mismatch between occupancy count and truth in %s\n' % stats_path)

    if not buckets:
        sys.stderr.write('No calibration data collected\n')
        return 1

    print('\nSymbol stats:')
    summary = {}
    for symbol in sorted(buckets.keys()):
        stats = summarize_bucket(buckets[symbol])
        summary[symbol] = stats
        print('  %s: n=%d min=%.2f mean=%.2f max=%.2f' % (symbol, stats['count'], stats['min'], stats['mean'], stats['max']))

    ordered = sorted(summary.items(), key=lambda item: item[1]['mean'])
    if len(ordered) > 1:
        print('\nSuggested thresholds:')
        for idx in range(len(ordered) - 1):
            left_symbol, left_stats = ordered[idx]
            right_symbol, right_stats = ordered[idx + 1]
            threshold = (left_stats['max'] + right_stats['min']) / 2.0
            print('  between %s and %s -> %.2f' % (left_symbol, right_symbol, threshold))

    print('\nCollected %d labeled runs' % seen_runs)
    return 0


def build_arg_parser():
    parser = argparse.ArgumentParser(description='Decode multi-bit occupancy traces or calibrate thresholds.')
    parser.add_argument('--stats', nargs='+', required=True, help='stats.txt files or directories containing them')
    parser.add_argument('--task-id', dest='task_id', type=int, default=0, help='task id for per-task occupancy counters')
    parser.add_argument('--groups', type=int, default=4, help='expected number of occ_group counters')
    parser.add_argument('--thresholds', default='50', help='comma-separated occupancy thresholds')
    parser.add_argument('--symbols', default='0,1', help='comma-separated symbol mapping (length must be thresholds+1)')
    parser.add_argument('--metadata-key', default='symbols', help='metadata key for ground-truth symbols')
    parser.add_argument('--mode', choices=['decode', 'calibrate'], default='decode', help='decoder mode')
    parser.add_argument('--calibrate', action='store_true', help='run calibration mode')
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    if args.calibrate:
        args.mode = 'calibrate'
    if args.mode == 'calibrate':
        return handle_calibrate(args)
    return handle_decode(args)


if __name__ == '__main__':
    sys.exit(main())
