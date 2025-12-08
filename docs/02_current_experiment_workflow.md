# Current experiment workflow

Use the helper scripts under `randomized_cache_hello_world` to launch common runs. They keep the default TimingSimpleCPU flow intact while adding DerivO3CPU entry points for SPEC06.

## SPEC06 + multi-bit workflow

- Build the sender binaries once with `./build_sender.sh` (or let the run scripts call it automatically). `SENDER_MODE` defaults to `multibit` for SPEC06 wrappers; set `SENDER_MODE=single` to fall back.
- Choose symbols with `RC_SYMBOLS` (alias: `SYMBOLS`). Each run emits that sequence in order and records it in `spec_metadata.json` inside the stats directory.
- Launch MIRAGE/CEASER/CEASER-S SPEC06 runs:
  - `./run_mirage_o3_spec.sh perlbench` → `stats_o3_spec_mirage/`
  - `./run_ceaser_o3_spec.sh --benchmark=bzip2` → `stats_o3_spec_ceaser/`
  - `SPEC_BENCH=mcf ./run_ceaser_s_o3_spec.sh --bp-type=tournament` → `stats_o3_spec_ceaser_s/`
- The O3 wrappers pick DerivO3CPU by default through the SPEC configs. Pass through extra gem5 args to override cache/cpu options or even switch to TimingSimpleCPU (`--cpu-type=TimingSimpleCPU`) if you want a TimingSimple SPEC pass.
- Outputs per run:
  - `simout` with sender logs (multi-bit emission lines)
  - `stats.txt` including occupancy and `occ_group` counters
  - `spec_metadata.json` recording the benchmark, sender mode, and symbol alphabet

The legacy scripts (`run_mirage.sh`, `run_ceaser.sh`, `run_ceaser_s.sh`) continue to use TimingSimpleCPU by default for non-SPEC runs.
