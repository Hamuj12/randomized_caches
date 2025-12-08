#!/usr/bin/env bash
# SASSCache TimingSimpleCPU (legacy LRC helper) using nolibc sender.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run_common.sh"

GEM5="$BASE_DIR/sasscache/build/X86/gem5.opt"
CFG="$BASE_DIR/sasscache/configs/example/se.py"
OUTDIR="${OUTDIR:-./stats_sasscache}"

NUM_CPUS=${NUM_CPUS:-1}
MEM_SIZE=${MEM_SIZE:-8GB}
MEM_TYPE=${MEM_TYPE:-DDR4_2400_8x8}
L1D_SIZE=${L1D_SIZE:-512B}
L1I_SIZE=${L1I_SIZE:-32kB}
L2_SIZE=${L2_SIZE:-16MB}
L1D_ASSOC=${L1D_ASSOC:-8}
L1I_ASSOC=${L1I_ASSOC:-8}
L2_ASSOC=${L2_ASSOC:-16}

rc_activate_py27
rc_select_sender

mkdir -p "$OUTDIR"

echo "[*] Running SASSCache with sender: $SENDER_MODE"

set -- "$CFG" \
  -c "$(pwd)/spurious_occupancy" \
  --cpu-type=TimingSimpleCPU \
  --num-cpus="$NUM_CPUS" \
  --mem-size="$MEM_SIZE" \
  --mem-type="$MEM_TYPE" \
  --caches --l2cache \
  --l1d_size="$L1D_SIZE" --l1i_size="$L1I_SIZE" --l2_size="$L2_SIZE" \
  --l1d_assoc="$L1D_ASSOC" --l1i_assoc="$L1I_ASSOC" --l2_assoc="$L2_ASSOC"

"$GEM5" --outdir "$OUTDIR" "$@"
