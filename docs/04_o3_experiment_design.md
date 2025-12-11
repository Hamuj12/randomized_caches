# O3 experiment entry points

Use these scripts for DerivO3CPU runs (all reuse the `_o3_example` config wrappers that inject `--cpu-type=DerivO3CPU` unless overridden):
- randomized_cache_hello_world/run_mirage_o3_lrc.sh
- randomized_cache_hello_world/run_ceaser_o3_lrc.sh
- randomized_cache_hello_world/run_ceaser_s_o3_lrc.sh
- randomized_cache_hello_world/run_sasscache_o3_lrc.sh
- randomized_cache_hello_world/run_mirage_o3_spec.sh
- randomized_cache_hello_world/run_ceaser_o3_spec.sh
- randomized_cache_hello_world/run_ceaser_s_o3_spec.sh

The SPEC wrappers mirror the non-SPEC O3 entry points but use SPEC06 workloads and write `spec_metadata.json` alongside the usual stats to capture the sender configuration (multi-bit by default). Example: `./run_mirage_o3_spec.sh perlbench`.

Hello-world and SPEC scripts share the same cache/memory flag set as the TimingSimpleCPU equivalents (`--num-cpus`, `--mem-size`, `--mem-type`, `--mirage_mode`, `--l2_numSkews`, `--l2_TDR`, `--l2_EncrLat`, `--prog-interval`, cache sizes/assocs). Passing `--cpu-type=TimingSimpleCPU` keeps the rest of those knobs intact if you need a TimingSimple comparison.
