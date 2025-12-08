#!/usr/bin/env bash
# Shared helpers for randomized cache hello world runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR=${BASE_DIR:-"$(cd "$SCRIPT_DIR/.." && pwd)"}
export RC_SYMBOLS=${RC_SYMBOLS:-0123}
export SENDER_MODE=${SENDER_MODE:-single}

rc_activate_py27() {
  local env_name=${PY27_ENV_NAME:-py27-gem5}
  local venv_root=${PY27_VENV_ROOT:-"$BASE_DIR/randomized_cache_hello_world/venv27"}
  local conda_home=${MINICONDA_HOME:-"${SCR:-$HOME}/miniconda3"}

  if [[ -x "$venv_root/bin/activate" ]]; then
    # virtualenv-based setup
    # shellcheck source=/dev/null
    source "$venv_root/bin/activate"
  elif [[ -x "$conda_home/bin/activate" ]]; then
    # conda-based setup
    # shellcheck source=/dev/null
    source "$conda_home/bin/activate" "$env_name"
  fi

  if command -v python >/dev/null 2>&1; then
    local py_prefix
    py_prefix=$(python - <<'PY'
import sys
print(sys.prefix)
PY
    ) || py_prefix=""
    if [[ -n "$py_prefix" ]]; then
      export PYTHONHOME="$py_prefix"
      export PYTHONPATH="$py_prefix/lib/python2.7/site-packages"
    fi
  fi
}

rc_build_senders() {
  bash "$BASE_DIR/randomized_cache_hello_world/build_sender.sh"
}

rc_select_sender() {
  local sender="spurious_occupancy_nolibc"
  if [[ "$SENDER_MODE" == "multibit" ]]; then
    sender="multi_bit_sender_nolibc"
  fi
  rc_build_senders
  pushd "$BASE_DIR/randomized_cache_hello_world" >/dev/null
  ln -sf "$sender" spurious_occupancy
  popd >/dev/null
  echo "[*] Using sender: $sender (mode=$SENDER_MODE, symbols=$RC_SYMBOLS)" >&2
}
