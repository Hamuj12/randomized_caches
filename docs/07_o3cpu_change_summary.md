# DerivO3CPU change summary

## Why add O3?
DerivO3CPU models an out-of-order core with realistic pipeline back-pressure and speculation. Swapping from TimingSimpleCPU gives more believable latency/throughput interactions with randomized caches and lets SPEC06 experiments stress the cache designs under deeper reordering.

## Files touched for O3 support
- Config wrappers
  - `mirage/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`
  - `ceaser/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`
  - `ceaser-s/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py`
- Run scripts (hello-world O3)
  - `randomized_cache_hello_world/run_mirage_o3_lrc.sh`
  - `randomized_cache_hello_world/run_ceaser_o3_lrc.sh`
  - `randomized_cache_hello_world/run_ceaser_s_o3_lrc.sh`
  - `randomized_cache_hello_world/run_sasscache_o3_lrc.sh`
- Run scripts (SPEC06 O3)
  - `randomized_cache_hello_world/run_mirage_o3_spec.sh`
  - `randomized_cache_hello_world/run_ceaser_o3_spec.sh`
  - `randomized_cache_hello_world/run_ceaser_s_o3_spec.sh`
- Documentation
  - `docs/02_current_experiment_workflow.md`
  - `docs/03_cpu_model_migration_notes.md`
  - `docs/04_o3_experiment_design.md`
  - `docs/07_o3cpu_change_summary.md`

## How the O3 wrappers work
- Each `_o3_example` file pushes `--cpu-type=DerivO3CPU` (and `--mem-type=DDR4_2400_8x8`) onto `sys.argv` only when the user did not provide a CPU type.
- They then import `spec06_config_multiprogram`, so existing cache sizing, associativity, memory system, and mirage/CEASER mode flags are parsed exactly as before.
- Passing a different `--cpu-type` from the command line (e.g., `TimingSimpleCPU`) skips the default and keeps all other options intact.

## How to run O3 experiments now
Hello-world (nolibc sender defaults to DerivO3CPU):
- `cd randomized_cache_hello_world`
- `./run_mirage_o3_lrc.sh --num-cpus=1 --mirage_mode=skew-vway-rand`
- `./run_ceaser_o3_lrc.sh --num-cpus=1 --mirage_mode=ceaser`
- `./run_ceaser_s_o3_lrc.sh --num-cpus=1 --mirage_mode=ceaser-s`
- `./run_sasscache_o3_lrc.sh --num-cpus=1`

SPEC06 (writes `spec_metadata.json`; set `SPEC_BENCH` or use `--benchmark=`):
- `cd randomized_cache_hello_world`
- `./run_mirage_o3_spec.sh perlbench`
- `./run_ceaser_o3_spec.sh --benchmark=bzip2`
- `SPEC_BENCH=mcf ./run_ceaser_s_o3_spec.sh --bp-type=tournament`

Common knobs across these scripts: `NUM_CPUS`, `MEM_SIZE`, `MEM_TYPE`, `L1D_SIZE`, `L1I_SIZE`, `L2_SIZE`, `L1D_ASSOC`, `L1I_ASSOC`, `L2_ASSOC`, `MIRAGE_MODE`, `L2_NUM_SKEWS`, `L2_TDR`, `L2_ENCR_LAT`, `PROG_INTERVAL`, `SENDER_MODE`, and `RC_SYMBOLS`/`SYMBOLS`.

## Switching between TimingSimpleCPU and DerivO3CPU
- Use the O3 wrappers for defaults; they inject DerivO3CPU only when no `--cpu-type` is present.
- Add `--cpu-type=TimingSimpleCPU` to any command if you want to reuse the same cache/memory knobs under the in-order model.
- The legacy `_lrc.sh` TimingSimpleCPU scripts remain available for reference and match the O3 variants except for CPU type and config import path.

## Caveats and TODOs
- Performance and runtime: DerivO3CPU runs longer than TimingSimpleCPU; schedule accordingly for SPEC06.
- SPEC paths: the SPEC06 binaries/inputs must already be configured for `spec06_config_multiprogram` (no automatic discovery here).
- Hard-coded defaults: cache sizes, associativity, memory type, and mirage/CEASER mode defaults mirror the TimingSimple flow; override via command-line flags when experimenting with other cache hierarchies.
