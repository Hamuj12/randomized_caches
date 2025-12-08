# Current experiment workflow

Use the helper scripts under `randomized_cache_hello_world` to launch common runs. They keep the default TimingSimpleCPU flow intact while adding DerivO3CPU entry points for SPEC06.

## O3 + SPEC06 workflow

The SPEC06 O3 scripts default to DerivO3CPU through the O3 wrapper configs. Provide a benchmark with the `--benchmark` flag (via `SPEC_BENCH` or the first positional argument), and pass any extra gem5 flags afterward to override defaults like `--cpu-type`.

- MIRAGE: `./run_mirage_o3_spec.sh perlbench` (outputs to `stats_o3_spec_mirage/` with `stats.txt`, `config.ini`, etc.)
- CEASER: `./run_ceaser_o3_spec.sh --benchmark=bzip2` (outputs to `stats_o3_spec_ceaser/`)
- CEASER-S: `SPEC_BENCH=mcf ./run_ceaser_s_o3_spec.sh --bp-type=tournament` (outputs to `stats_o3_spec_ceaser_s/`)

The legacy scripts (`run_mirage.sh`, `run_ceaser.sh`, `run_ceaser_s.sh`) continue to use TimingSimpleCPU by default, while the new `*_o3_spec.sh` scripts pick DerivO3CPU unless you override `--cpu-type` in the forwarded arguments.
