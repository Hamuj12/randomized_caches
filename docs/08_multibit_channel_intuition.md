# Multi-bit channel intuition

## Recap: single-bit channel
The single-bit prototype relied on a single sender footprint and aggregate L2 occupancy stats such as `system.l2.tags.occ_percent::total`. That made it easy to count binary presence/absence of the sender, but it limited throughput (one bit per run) and robustness (background noise moves the aggregate counter without a clear reference).

## Core concepts
- **Symbol:** a discrete occupancy level the sender can intentionally produce. The default alphabet is `"0123"`, giving four levels.
- **Group:** a bucket of L2 sets. Both the sender and the cache stats use `group = setIdx % numOccGroups` with `numOccGroups = 4`, so each group represents every 4th physical set in the cache.
- **Epoch / run:** one gem5 run where the sender walks through a fixed message once (or repeats it a few times) and the simulator dumps `stats.txt` plus optional `spec_metadata.json`. Each symbol in the message corresponds to one occupancy reading (one group slot) in the stats dump.

## Sender intuition (multi_bit_sender.c)
The libc and nolibc variants share the same cache-touching pattern. Important parameters:
- `CHANNEL_WORDS = 1 << 20` creates a 1M-element array to span many cache sets while keeping accesses deterministic.
- `BASE_TOUCHES = 4096` sets the occupancy for symbol 0; `TOUCH_STEP = 1536` increments touches per symbol level. With the default alphabet, symbol 0 touches 4096 lines, symbol 1 touches 5632, symbol 2 touches 7168, and symbol 3 touches 8704. More touches → more occupied lines in the targeted set groups.
- `SYMBOL_AMPLIFY = 3` repeats the touch loop to strengthen the signal for each symbol.

### Mapping symbols to groups and sets
The sender hashes the loop index with two large constants and a per-round offset, masking by `CHANNEL_WORDS - 1`. That pseudo-random walk spreads touches across many addresses, but the physical sets the touches land on are congruent modulo the cache’s set count. Because the cache stats bucket sets with `setIdx % 4`, every fourth set contributes to the same `occ_group` counter. The sender doesn’t need explicit set math; the modulo grouping in gem5 aligns with the natural spread of addresses.

### Parameter effects
- **group_count:** Fixed at 4 inside gem5 tags and the decoder defaults. More groups would give more bits per epoch but dilute the per-group signal because the same total touches would be split across more buckets.
- **lines_per_group:** Controlled indirectly by `BASE_TOUCHES` and `TOUCH_STEP`; higher values raise occupancy and make separation between symbols easier at the cost of more interference with co-running code.
- **repetitions (RC_REPEAT):** Loops over the whole message; useful when you want multiple identical epochs in one run for averaging.
- **Inter-symbol delay:** Not explicit in the sender; separation comes from `SYMBOL_AMPLIFY` loops and the simulator’s progress. If you need slower symbol cadence, you would add pauses between `touch_symbol` calls.

### libc vs. nolibc
`build_sender.sh` produces both statically linked libc binaries and `-nostdlib` nolibc binaries. The nolibc versions avoid glibc/ld.so startup syscalls that previously contaminated early cache state and altered task IDs; they log with raw syscalls instead of `printf`. The run scripts symlink the selected variant into the filenames gem5 expects, so toggling `SENDER_MODE` automatically swaps in the nolibc sender for clean traces.

## Run scripts and orchestration
- `run_common.sh` exports `RC_SYMBOLS` (from `SYMBOLS` if provided) and sets `SENDER_MODE` (`single` vs `multibit`). `rc_select_sender` builds senders and symlinks `spurious_occupancy` and `multi_bit_sender` to either the single-bit placeholder or the multi-bit sender, matching gem5 config expectations.
- SPEC06 wrappers such as `run_mirage_o3_spec.sh` and `run_ceaser_o3_spec.sh` default to `SENDER_MODE=multibit`. They call `rc_write_spec_metadata`, which writes `spec_metadata.json` with the benchmark name, sender mode, and `symbols` string. That file is the ground truth the decoder uses during calibration.
- O3/LRC/SPEC variants differ in CPU/cache parameters but follow the same pattern: source `run_common.sh`, select the sender, and launch gem5 with an `--outdir` that will contain `stats.txt` plus metadata.

## Stats instrumentation (MIRAGE, CEASER, CEASER-S)
- Each cache tag implementation adds `numOccGroups = 4` and an `occGroup` Stat object. During `computeStats`, every valid block increments `occGroup[setIdx % numOccGroups]`, keeping the grouping rule in lockstep with the sender’s implicit distribution.
- `regStats` initializes `occ_group::0..3` counters with `nozero|nonan` flags, so they appear in `stats.txt` alongside legacy `occ_percent` and `occ_task_id_percent` metrics.
- Because the grouping is purely modulo-based, it doesn’t depend on MIRAGE/CEASER indexing quirks; the sender’s spread naturally populates these bins.

## Decoder pipeline
- `multi_bit_decode_example.py` reads one or more `stats.txt` files (or directories) and prefers `occ_group::*` counters. If missing, it falls back to `occ_task_id_percent::<task>` and finally `occ_percent::total`, preserving compatibility with old single-bit runs.
- Thresholds (`--thresholds`) and symbol mapping (`--symbols`) must satisfy `len(symbols) = len(thresholds) + 1`. Defaults are `50` and `0,1` but calibration mode will suggest better values.
- Calibration (`--calibrate` or `MODE=calibrate` in `run_decode_example.sh`) loads `spec_metadata.json`, buckets occupancy by symbol, prints min/mean/max per symbol, and proposes thresholds midway between adjacent buckets.
- The driver script glob (`RUN_GLOB`) collects run directories, forwards CLI overrides, and compares decoded streams with metadata truth when present, printing both the per-run breakdown and a concatenated stream.

## Worked examples
1. **Alphabet `0123`, message `0123` over one run**
   - Sender touches roughly 4k/5.6k/7.2k/8.7k lines for symbols 0–3, amplified three times. In stats, `occ_group::0..3` will show an ascending pattern aligned with the symbol order (e.g., group 0 ≈ lowest occupancy, group 3 ≈ highest). Decoding with thresholds `22,46,70` and symbols `0,1,2,3` yields `0123`.
2. **Alphabet `01`, message `1110` with `RC_REPEAT=2`**
   - Two epochs back-to-back. Groups will show a high-high-high-low pattern twice. Calibration sees two tight clusters (high for symbol `1`, lower for `0`) and suggests a single threshold between them. Decoding over the concatenated occupancies reconstructs `11101110`.

## Tradeoffs and tuning
- **More groups:** Increases symbol bandwidth but lowers per-group occupancy, making thresholds noisier. Requires changing `numOccGroups` in gem5 and decoder defaults to stay aligned with the sender.
- **Heavier touches:** Raising `BASE_TOUCHES`/`TOUCH_STEP` improves separation but perturbs co-runners more and may saturate occupancy counters.
- **Repeats/epochs:** Multiple `RC_REPEAT` loops give averaging opportunities; future work could schedule multi-epoch messages within one run for time-series decoding.

## TODOs and extensions
- Add intentional inter-symbol delays for time-based decoding.
- Support variable `numOccGroups` wired through gem5 params and metadata.
- Emit per-epoch metadata from the sender so a single run can encode multiple messages without external bookkeeping.
- Expand stats to capture per-set histograms or time slices for more robust decoding under noise.
