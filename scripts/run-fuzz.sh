#!/usr/bin/env bash
set -euo pipefail

profile="${1:-ci}"
suite="${2:-all}"
seed="${3:-0x5eed}"
target="${4:-wasm-gc}"

case "${target}" in
  native)
    moon run --target native src/fuzz -- "${suite}" "${profile}" --seed "${seed}"
    ;;
  wasm|wasm-gc|llvm|js)
    moon run --target "${target}" src/fuzz -- "${suite}" "${profile}" --seed "${seed}"
    ;;
  *)
    echo "usage: scripts/run-fuzz.sh [profile] [suite] [seed] [target]" >&2
    echo "target must be one of: native, wasm, wasm-gc, llvm, js" >&2
    exit 1
    ;;
esac
