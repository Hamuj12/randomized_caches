# O3 experiment entry points

Use these scripts for DerivO3CPU runs:
- randomized_cache_hello_world/run_mirage_o3_lrc.sh
- randomized_cache_hello_world/run_ceaser_o3_lrc.sh
- randomized_cache_hello_world/run_ceaser_s_o3_lrc.sh
- randomized_cache_hello_world/run_sasscache_o3_lrc.sh
- randomized_cache_hello_world/run_mirage_o3_spec.sh
- randomized_cache_hello_world/run_ceaser_o3_spec.sh
- randomized_cache_hello_world/run_ceaser_s_o3_spec.sh

The SPEC wrappers mirror the non-SPEC O3 entry points but use SPEC06 workloads and write `spec_metadata.json` alongside the usua
l stats to capture the sender configuration (multi-bit by default). Example: `./run_mirage_o3_spec.sh perlbench`.
