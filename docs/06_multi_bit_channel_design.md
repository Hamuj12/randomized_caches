# Multi-bit channel design

## Occupancy grouping
The multi-bit sender and cache stats share a simple grouping rule of `group = setIdx % numGroups`, with a default of four groups m
atching the sender's `g_group_count` in `randomized_cache_hello_world/multi_bit_sender.c`.
The tags now expose `occ_group` counters (e.g., `system.l2.tags.occ_group::0`) so decoders can attribute occupancy to each logic
al set group instead of relying only on aggregate `occ_percent` statistics.
The grouping is always enabled when the tag stats are registered; adjust `numGroups` alongside the sender if a different channel 
layout is required.

## Run-level sequencing
Each SPEC run currently carries one symbol alphabet and sequence via `RC_SYMBOLS`/`RC_MESSAGE`; decoding uses `spec_metadata.json
` plus `occ_group` counters to line up the expected pattern. A future extension could pack multiple epochs into a single gem5 ru
n if we add message scheduling support.
