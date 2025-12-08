#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CC=${CC:-gcc}
CFLAGS_STATIC=( -static -O2 -Wall -Wextra -Wno-unused-parameter )
NOLIBC_FLAGS=( -nostdlib -static -s -Wl,--build-id=none -fno-pic -fno-pie -no-pie -fomit-frame-pointer -ffreestanding -fdata-sections -ffunction-sections -Wl,--gc-sections )

build_libc_sender() {
  local src=$1 out=$2
  echo "[*] Building ${out} (static libc)" >&2
  "$CC" "${CFLAGS_STATIC[@]}" "$src" -o "$out"
}

build_nolibc_sender() {
  local src=$1 out=$2
  echo "[*] Building ${out} (nolibc static)" >&2
  "$CC" "${NOLIBC_FLAGS[@]}" "$src" -o "$out"
}

build_libc_sender spurious_occupancy.c spurious_occupancy
build_nolibc_sender spurious_occupancy_nolibc.c spurious_occupancy_nolibc

build_libc_sender multi_bit_sender.c multi_bit_sender
build_nolibc_sender multi_bit_sender_nolibc.c multi_bit_sender_nolibc

echo "[✔] Sender binaries ready: spurious_occupancy{,_nolibc}, multi_bit_sender{,_nolibc}" >&2
