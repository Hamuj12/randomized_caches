# CPU model migration notes

DerivO3CPU became the default for the O3 entry points by wrapping the existing SPEC06 multiprogram config. The wrappers leave cache and memory knobs untouched so we can switch between TimingSimpleCPU and DerivO3CPU without rewriting the config.

## Wrapper behavior
- `mirage/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`
- `ceaser/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`
- `ceaser-s/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`

Each wrapper appends `--cpu-type=DerivO3CPU` to `sys.argv` unless the user already provided `--cpu-type`. They import `spec06_config_multiprogram` afterwards, so cache sizes, associativity, memory type, and other options still flow through the existing parser unchanged.

## Switching CPU models
- DerivO3CPU default: use the `_o3_example` wrappers (the run scripts pick them automatically).
- TimingSimpleCPU: pass `--cpu-type=TimingSimpleCPU` through any run script and the wrappers will preserve it. The legacy `_lrc.sh` helpers already add this flag explicitly.

## Run scripts relying on the wrappers
Hello-world O3 scripts (nolibc sender):
- `randomized_cache_hello_world/run_mirage_o3_lrc.sh`
- `randomized_cache_hello_world/run_ceaser_o3_lrc.sh`
- `randomized_cache_hello_world/run_ceaser_s_o3_lrc.sh`
- `randomized_cache_hello_world/run_sasscache_o3_lrc.sh`

SPEC06 O3 scripts (emit `spec_metadata.json`):
- `randomized_cache_hello_world/run_mirage_o3_spec.sh`
- `randomized_cache_hello_world/run_ceaser_o3_spec.sh`
- `randomized_cache_hello_world/run_ceaser_s_o3_spec.sh`

All of these call into the `_o3_example` config, so cache/memory parameters stay aligned with the TimingSimpleCPU flow.
