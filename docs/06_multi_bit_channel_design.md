# Multi-bit channel design

## Occupancy grouping
The multi-bit sender and cache stats share a simple grouping rule of `group = setIdx % numGroups`, with a default of four groups matching the sender's `g_group_count` in `randomized_cache_hello_world/multi_bit_sender.c`. The tags expose `occ_group` counters (e.g., `system.l2.tags.occ_group::0`) so decoders can attribute occupancy to each logical set group instead of relying only on aggregate `occ_percent` statistics. Adjust `numGroups` alongside the sender if a different channel layout is required.

## Run-level sequencing
Each SPEC run currently carries one symbol alphabet and sequence via `RC_SYMBOLS`/`RC_MESSAGE`; decoding uses `spec_metadata.json` plus `occ_group` counters to line up the expected pattern. A future extension could pack multiple epochs into a single gem5 run if we add message scheduling support.

## Decoder and calibration pipeline
`randomized_cache_hello_world/multi_bit_decode_example.py` turns the prototype decoder into a reusable tool with two modes:
- **Decode (default):** read one or more stats files or directories, pull `occ_group` counters when present (falling back to per-task or aggregate occupancy), map them to symbols using configurable thresholds, and print both per-run lines and the reconstructed stream.
- **Calibrate:** load the same stats paths but also consume the ground-truth symbols from `spec_metadata.json`, bucket occupancies by symbol, and suggest threshold midpoints between adjacent clusters.

`randomized_cache_hello_world/run_decode_example.sh` wraps the decoder so you can sweep multiple runs without remembering flags. Example workflow:
- Calibrate on a few labeled runs (with `spec_metadata.json` present):
  - `MODE=calibrate RUN_GLOB="stats_o3_spec_*" ./run_decode_example.sh`
- Apply the suggested thresholds to future runs:
  - `THRESHOLDS="22,46,70" SYMBOLS="A,B,C,D" RUN_GLOB="stats_o3_spec_*" ./run_decode_example.sh`
- Compare decoded streams against the ground truth embedded in each run's metadata (when available) to spot drift across forks or CPU types.

The decoder remains compatible with older runs that lack group counters or metadata; it will automatically fall back to task-level occupancy or total occupancy and emit a decoded stream based on the provided thresholds.
