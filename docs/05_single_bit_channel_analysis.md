# Single-bit channel analysis

The original single-bit experiments relied on aggregate L2 occupancy counters such as `system.l2.tags.occ_percent::total`. The new decoder at `randomized_cache_hello_world/multi_bit_decode_example.py` can still process those runs by falling back to the aggregate counter when group or task-level stats are missing. Use `run_decode_example.sh` with an appropriate `RUN_GLOB` to sweep historical results and recover the transmitted bits without changing the existing scripts.

For intuition on how the multi-bit path extends this mechanism (and how the decoder chooses between group/task/aggregate sources), see `docs/08_multibit_channel_intuition.md`.
