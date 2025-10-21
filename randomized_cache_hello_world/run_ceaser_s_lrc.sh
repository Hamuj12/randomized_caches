#!/usr/bin/env bash
set -eo pipefail

# --- required by you ---
export BASE_DIR="/misc/scratch/hm25936/randomized_caches"

SCR="/misc/scratch/hm25936"
ENV="py27-gem5"
GEM5="$BASE_DIR/ceaser-s/perf_analysis/gem5/build/X86/gem5.opt"
CFG="$BASE_DIR/ceaser-s/perf_analysis/gem5/configs/example/spec06_config_multiprogram.py"
OUTDIR="./stats_ceaser_s"

source "$SCR/miniconda3/bin/activate" "$ENV"
export PYTHONHOME="$SCR/miniconda3/envs/$ENV"
export PYTHONPATH="$SCR/miniconda3/envs/$ENV/lib/python2.7/site-packages"

if [[ ! -x ./spurious_occupancy_nolibc ]]; then
  echo "Missing ./spurious_occupancy_nolibc. Build it via the minimal sanity script first." >&2
  exit 1
fi
rm -f ./spurious_occupancy
ln -s spurious_occupancy_nolibc spurious_occupancy

mkdir -p "$OUTDIR"

echo "[*] Running CEASER-S with no-libc test binary..."
"$GEM5" --outdir "$OUTDIR" \
  "$CFG" \
  --num-cpus=1 \
  --mem-size=8GB \
  --mem-type=DDR4_2400_8x8 \
  --cpu-type=TimingSimpleCPU \
  --caches --l2cache \
  --l1d_size=512B --l1i_size=32kB --l2_size=16MB \
  --l1d_assoc=8 --l1i_assoc=8 --l2_assoc=16 \
  --mirage_mode=ceaser \
  --l2_numSkews=2 \
  --l2_TDR=1.75 \
  --l2_EncrLat=3 \
  --prog-interval=300Hz

echo "✔ CEASER-S done. See $OUTDIR/"