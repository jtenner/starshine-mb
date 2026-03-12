#!/usr/bin/env bash
set -euo pipefail

fuzz_profile="${1:-ci}"
seed="${2:-0x5eed}"
target="${3:-wasm-gc}"

case "${target}" in
  native|wasm|wasm-gc|llvm|js)
    ;;
  *)
    echo "usage: scripts/run-full-test.sh [fuzz_profile] [seed] [target]" >&2
    echo "target must be one of: native, wasm, wasm-gc, llvm, js" >&2
    exit 1
    ;;
esac

echo "[full-test] moon info && moon fmt"
moon info
moon fmt

echo "[full-test] moon check --target ${target}"
moon check --target "${target}"

echo "[full-test] moon test --target ${target}"
moon test --target "${target}"

echo "[full-test] fuzz suites profile=${fuzz_profile} seed=${seed} target=${target}"
bash scripts/run-fuzz.sh "${fuzz_profile}" all "${seed}" "${target}"
