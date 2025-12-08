#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DECODER="$SCRIPT_DIR/multi_bit_decode_example.py"
PYTHON_BIN=${PYTHON:-python}

MODE=${MODE:-decode}
PATTERN=${RUN_GLOB:-${1:-stats_*}}
TASK_ID=${TASK_ID:-0}
GROUPS=${GROUPS:-4}
THRESHOLDS=${THRESHOLDS:-}
SYMBOLS=${SYMBOLS:-}
METADATA_KEY=${METADATA_KEY:-symbols}
shift $(( $# > 0 ? 1 : 0 )) || true
EXTRA_ARGS=${DECODER_ARGS:-}

shopt -s nullglob
stats_paths=()
for path in $PATTERN; do
  if [[ -d "$path" ]]; then
    if [[ -f "$path/stats.txt" ]]; then
      stats_paths+=("$path")
    fi
  elif [[ -f "$path" ]]; then
    stats_paths+=("$path")
  fi
done
shopt -u nullglob

if [[ ${#stats_paths[@]} -eq 0 ]]; then
  echo "No stats paths found for pattern: $PATTERN" >&2
  exit 1
fi

set -- --stats "${stats_paths[@]}" --task-id "$TASK_ID" --groups "$GROUPS" --metadata-key "$METADATA_KEY"
if [[ -n "$THRESHOLDS" ]]; then
  set -- "$@" --thresholds "$THRESHOLDS"
fi
if [[ -n "$SYMBOLS" ]]; then
  set -- "$@" --symbols "$SYMBOLS"
fi
if [[ "$MODE" == "calibrate" ]]; then
  set -- "$@" --calibrate
fi
if [[ -n "$EXTRA_ARGS" ]]; then
  set -- "$@" $EXTRA_ARGS
fi

cd "$SCRIPT_DIR"
"$PYTHON_BIN" "$DECODER" "$@"
