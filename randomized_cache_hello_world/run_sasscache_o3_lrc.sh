#!/usr/bin/env bash
# No -u here: conda deactivate hooks don't like nounset.
set -eo pipefail

BASE_DIR=${BASE_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
: ${SCR:=/misc/scratch/hm25936}
: ${ENV:=py27-gem5}
GEM5="$BASE_DIR/sasscache/build/X86/gem5.opt"
CFG="$BASE_DIR/sasscache/configs/example/se.py"
OUTDIR="./stats_sasscache_o3"

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

echo "[*] Running SASSCache O3 (SE mode) with no-libc test binary..."
"$GEM5" --outdir "$OUTDIR" \
  "$CFG" \
  -c "$(pwd)/spurious_occupancy" \
  --cpu-type=DerivO3CPU \
  --num-cpus=1 \
  --mem-size=8GB \
  --mem-type=DDR4_2400_8x8 \
  --caches --l2cache \
  --l1d_size=512B --l1i_size=32kB --l2_size=16MB \
  --l1d_assoc=8 --l1i_assoc=8 --l2_assoc=16

echo "✔ SASSCache run done. See $OUTDIR/"
