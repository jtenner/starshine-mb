#!/usr/bin/env bash
set -euo pipefail

fuzz_profile="${1:-ci}"
seed=""
target="wasm-gc"

if [[ $# -gt 3 ]]; then
  echo "usage: scripts/run-full-test.sh [fuzz_profile] [seed|target] [target]" >&2
  echo "target must be one of: native, wasm, wasm-gc, llvm, js" >&2
  exit 1
fi

if [[ $# -ge 2 ]]; then
  case "${2}" in
    native|wasm|wasm-gc|llvm|js)
      target="${2}"
      ;;
    *)
      seed="${2}"
      ;;
  esac
fi

if [[ $# -ge 3 ]]; then
  target="${3}"
fi

case "${target}" in
  native|wasm|wasm-gc|llvm|js)
    ;;
  *)
    echo "usage: scripts/run-full-test.sh [fuzz_profile] [seed|target] [target]" >&2
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

seed_label="${seed:-auto}"
echo "[full-test] fuzz suites profile=${fuzz_profile} seed=${seed_label} target=${target}"
if [[ -n "${seed}" ]]; then
  bash scripts/run-fuzz.sh "${fuzz_profile}" all "${seed}" "${target}"
else
  bash scripts/run-fuzz.sh "${fuzz_profile}" all "${target}"
fi
