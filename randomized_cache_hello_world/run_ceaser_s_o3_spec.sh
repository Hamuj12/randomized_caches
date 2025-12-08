#!/usr/bin/env bash
# Run CEASER-S SPEC06 with DerivO3CPU defaults.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run_common.sh"

GEM5="$BASE_DIR/ceaser-s/perf_analysis/gem5/build/X86/gem5.opt"
CONFIG="$BASE_DIR/ceaser-s/perf_analysis/gem5/configs/example/spec06_config_multiprogram_o3_example.py"
OUTDIR="${OUTDIR:-./stats_o3_spec_ceaser_s}"

NUM_CPUS=${NUM_CPUS:-1}
MEM_SIZE=${MEM_SIZE:-8GB}
MEM_TYPE=${MEM_TYPE:-DDR4_2400_8x8}
L1D_SIZE=${L1D_SIZE:-512B}
L1I_SIZE=${L1I_SIZE:-32kB}
L2_SIZE=${L2_SIZE:-16MB}
L1D_ASSOC=${L1D_ASSOC:-8}
L1I_ASSOC=${L1I_ASSOC:-8}
L2_ASSOC=${L2_ASSOC:-16}
MIRAGE_MODE=${MIRAGE_MODE:-ceaser-s}
L2_NUM_SKEWS=${L2_NUM_SKEWS:-2}
L2_TDR=${L2_TDR:-1.75}
L2_ENCR_LAT=${L2_ENCR_LAT:-3}
PROG_INTERVAL=${PROG_INTERVAL:-300Hz}

BENCH_ARG=${SPEC_BENCH:-}
if [[ -z "$BENCH_ARG" && $# -gt 0 ]]; then
  BENCH_ARG=$1
  shift
fi
EXTRA_ARGS="$@"

rc_activate_py27
rc_select_sender

mkdir -p "$OUTDIR"

echo "[*] Running CEASER-S O3 SPEC06 with sender: $SENDER_MODE"

set -- "$CONFIG" \
  --num-cpus="$NUM_CPUS" \
  --mem-size="$MEM_SIZE" \
  --mem-type="$MEM_TYPE" \
  --caches --l2cache \
  --l1d_size="$L1D_SIZE" --l1i_size="$L1I_SIZE" --l2_size="$L2_SIZE" \
  --l1d_assoc="$L1D_ASSOC" --l1i_assoc="$L1I_ASSOC" --l2_assoc="$L2_ASSOC" \
  --mirage_mode="$MIRAGE_MODE" \
  --l2_numSkews="$L2_NUM_SKEWS" \
  --l2_TDR="$L2_TDR" \
  --l2_EncrLat="$L2_ENCR_LAT" \
  --prog-interval="$PROG_INTERVAL"

if [[ -n "$BENCH_ARG" ]]; then
  set -- "$@" --benchmark="$BENCH_ARG"
fi
if [[ -n "$EXTRA_ARGS" ]]; then
  set -- "$@" $EXTRA_ARGS
fi

"$GEM5" --outdir "$OUTDIR" "$@"
