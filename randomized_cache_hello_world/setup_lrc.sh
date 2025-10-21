#!/usr/bin/env bash
set -eo pipefail

# -----------------------------
# CONFIGURATION
# -----------------------------
THREADS=$(nproc)
SCR="/misc/scratch/hm25936"
CONDA_ENV="py27-gem5"

WRAP="$SCR/toolchain-wrap/bin"
PREFIX="$SCR/toolchains/py27local"
ZP="$SCR/toolchains/zlib"
SCONS_BIN="$SCR/miniconda3/envs/$CONDA_ENV/bin/scons"
DEBUG=${DEBUG:-0}

# -----------------------------
# ENVIRONMENT SETUP
# -----------------------------
echo "[*] Activating $CONDA_ENV and preparing wrapper paths..."
source "$SCR/miniconda3/bin/activate" "$CONDA_ENV"

mkdir -p "$WRAP"
export PATH="$WRAP:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$ZP/lib:${LD_LIBRARY_PATH:-}"
export PYTHON_CONFIG="$WRAP/python2.7-config"

# Force SCons to use our wrappers for compile AND link
export CC="$WRAP/gcc"
export CXX="$WRAP/g++"
export LINK="$WRAP/g++"

# Global flags (belt & suspenders)
export CFLAGS="${CFLAGS:-} -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -fPIC"
export LDFLAGS="${LDFLAGS:-} -no-pie -Wl,--no-as-needed"

write_wrappers () {
  mkdir -p "$WRAP"

  # Remove stale wrappers so we don't discover ourselves
  rm -f "$WRAP/gcc" "$WRAP/g++" \
        "$WRAP/x86_64-conda_cos6-linux-gnu-gcc" \
        "$WRAP/x86_64-conda_cos6-linux-gnu-g++" \
        "$WRAP/python2.7-config" || true

  # Discover real tools not inside $WRAP
  local REAL_GCC REAL_GPP REAL_PYCFG
  REAL_GCC="$(/usr/bin/which -a gcc 2>/dev/null | grep -v "^$WRAP/" | head -n1)"
  REAL_GPP="$(/usr/bin/which -a g++ 2>/dev/null | grep -v "^$WRAP/" | head -n1)"
  REAL_PYCFG="$(/usr/bin/which -a python2.7-config 2>/dev/null | grep -v "^$WRAP/" | head -n1 || true)"
  [[ -z "$REAL_GCC" || -z "$REAL_GPP" ]] && { echo "Failed to find real gcc/g++"; exit 1; }
  [[ "$DEBUG" == 1 ]] && echo "[dbg] REAL_GCC=$REAL_GCC REAL_GPP=$REAL_GPP REAL_PYCFG=${REAL_PYCFG:-<none>}"

  # --- gcc wrapper (C) --------------------------------------------------------
  cat > "$WRAP/gcc" <<EOF
#!/usr/bin/env bash
set -e
[[ "\${DEBUG:-0}" == 1 ]] && echo "[gcc.wrap] \$@" >&2
REAL_GCC="$REAL_GCC"
ZP="$ZP"
PREFIX="$PREFIX"
BASE=(-I"\$ZP/include" -L"\$ZP/lib" -Wl,-rpath,"\$ZP/lib" -L"\$PREFIX/lib" -Wl,-rpath,"\$PREFIX/lib")
NOWARN=(-Wno-error -Wno-error=type-limits -Wno-deprecated-declarations \
       -Wno-maybe-uninitialized -Wno-sign-compare -Wno-reorder -Wno-unused-parameter)
DEFS=(-D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS)
FORCE_INC=(-include stdint.h)

# compile step -> add -fPIC, disable WERRORs, force-include stdint.h
for a in "\$@"; do
  if [ "\$a" = "-c" ]; then
    exec "\$REAL_GCC" -fPIC "\${BASE[@]}" "\${NOWARN[@]}" "\${DEFS[@]}" "\${FORCE_INC[@]}" "\$@" -Wno-error
  fi
done

# diagnostic-only invocations
for a in "\$@"; do
  case "\$a" in
    -v|-print*|-dump*|-E|-S) exec "\$REAL_GCC" "\$@";;
  esac
done

exec "\$REAL_GCC" "\${BASE[@]}" "\$@"
EOF
  chmod +x "$WRAP/gcc"

  # --- g++ wrapper (C++) ------------------------------------------------------
  cat > "$WRAP/g++" <<'EOF'
#!/usr/bin/env bash
set -e
[[ "${DEBUG:-0}" == 1 ]] && echo "[g++.wrap] $@" >&2

ZP="/misc/scratch/hm25936/toolchains/zlib"
PREFIX="/misc/scratch/hm25936/toolchains/py27local"
REAL="$(/usr/bin/which -a g++ 2>/dev/null | grep -v "^/misc/scratch/hm25936/toolchain-wrap/bin/" | head -n1)"

BASE=(-I"$ZP/include" -L"$ZP/lib" -Wl,-rpath,"$ZP/lib" -L"$PREFIX/lib" -Wl,-rpath,"$PREFIX/lib")
NOWARN=(-Wno-error -Wno-error=type-limits -Wno-error=deprecated-copy \
       -Wno-deprecated-declarations -Wno-maybe-uninitialized \
       -Wno-sign-compare -Wno-reorder -Wno-unused-parameter -Wno-address-of-packed-member)
DEFS=(-D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS)
# ✅ Only stdint.h here to avoid _POSIX_C_SOURCE conflicts from <cstdint>
FORCE_INC=(-include stdint.h)

# compile step -> ensure PIC, C++14, silence WERRORs, force-include stdint.h
for a in "$@"; do
  if [ "$a" = "-c" ]; then
    exec "$REAL" -fPIC -std=gnu++14 "${BASE[@]}" "${NOWARN[@]}" "${DEFS[@]}" "${FORCE_INC[@]}" "$@" -Wno-error
  fi
done

# diagnostic-only invocations
for a in "$@"; do
  case "$a" in
    -v|-print*|-dump*|-E|-S) exec "$REAL" "$@";;
  esac
done

# detect output name (for final link tweaks)
out=""
for ((i=1; i<=$#; i++)); do
  if [ "${!i}" = "-o" ]; then j=$((i+1)); out="${!j}"; break; fi
done

# detect partial link (-r or -Wl,-r)
is_partial=0
for a in "$@"; do
  [[ "$a" == "-r" || "$a" == "-Wl,-r" ]] && is_partial=1
done

# Final gem5 binary link: add non-PIE and system libs (but NOT on partial links)
if [[ $is_partial -eq 0 && "$out" == *"/gem5."* ]]; then
  exec "$REAL" "${BASE[@]}" "$@" -Wl,--no-as-needed -lpthread -lrt -ldl -no-pie -fuse-ld=bfd
fi

# Default: pass through
exec "$REAL" "${BASE[@]}" "$@"
EOF
  chmod +x "$WRAP/g++"

  # Triplet shims so nothing bypasses wrappers
  cat > "$WRAP/x86_64-conda_cos6-linux-gnu-gcc" <<'EOF'
#!/usr/bin/env bash
exec "$(dirname "$0")/gcc" "$@"
EOF
  cat > "$WRAP/x86_64-conda_cos6-linux-gnu-g++" <<'EOF'
#!/usr/bin/env bash
exec "$(dirname "$0")/g++" "$@"
EOF
  chmod +x "$WRAP"/x86_64-conda_cos6-linux-gnu-gcc "$WRAP"/x86_64-conda_cos6-linux-gnu-g++

  # python2.7-config passthrough (if present)
  if [[ -n "$REAL_PYCFG" ]]; then
    cat > "$WRAP/python2.7-config" <<EOF
#!/usr/bin/env bash
exec "$REAL_PYCFG" "\$@"
EOF
    chmod +x "$WRAP/python2.7-config"
  else
    # Fallback shim that at least prevents 'command not found'
    cat > "$WRAP/python2.7-config" <<'EOF'
#!/usr/bin/env bash
echo "python2.7-config not found" >&2
exit 127
EOF
    chmod +x "$WRAP/python2.7-config"
  fi
}

write_wrappers

# -----------------------------
# HELPER FUNCTION
# -----------------------------
build_repo () {
    local name="$1"
    local dir="$2"
    if [ ! -d "$dir" ]; then
        echo "↷  Skipping $name (not found at $dir)"
        return 0
    fi
    echo -e "\n==> Building $name ..."
    cd "$dir"

    # Clean SCons cache so non-PIC / old-std objects don’t linger
    rm -rf build/X86 build/variables .sconsign.dblite || true

    # Build (verbose only for SCons, not for compilers)
    EXTRA_NOWARN='-Wno-error -Wno-maybe-uninitialized -Wno-deprecated-declarations -Wno-sign-compare -Wno-reorder -Wno-unused-parameter -Wno-type-limits -Wno-deprecated-copy -Wno-address-of-packed-member'
    SHCXXFLAGS="-fPIC $EXTRA_NOWARN" \
    SHCCFLAGS="-fPIC $EXTRA_NOWARN" \
    CXXFLAGS="-fPIC $EXTRA_NOWARN" \
    CFLAGS="-fPIC $EXTRA_NOWARN" \
    "$SCONS_BIN" -Q -j"$THREADS" V=1 WERROR=0 build/X86/gem5.opt

    echo "✔  $name build finished"
}

# -----------------------------
# BUILD EACH VARIANT
# -----------------------------
# build_repo "MIRAGE"        "$SCR/randomized_caches/mirage/perf_analysis/gem5"
# build_repo "CEASER"        "$SCR/randomized_caches/ceaser/perf_analysis/gem5"
# build_repo "CEASER-S"      "$SCR/randomized_caches/ceaser-s/perf_analysis/gem5"
build_repo "SASSCache"     "$SCR/randomized_caches/sasscache/"

echo -e "\nAll builds complete!"