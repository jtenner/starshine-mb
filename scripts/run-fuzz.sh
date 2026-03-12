#!/usr/bin/env bash
set -euo pipefail

profile="${1:-ci}"
suite="${2:-all}"
seed=""
target="wasm-gc"

if [[ $# -gt 4 ]]; then
  echo "usage: scripts/run-fuzz.sh [profile] [suite] [seed|target] [target]" >&2
  echo "target must be one of: native, wasm, wasm-gc, llvm, js" >&2
  exit 1
fi

if [[ $# -ge 3 ]]; then
  case "${3}" in
    native|wasm|wasm-gc|llvm|js)
      target="${3}"
      ;;
    *)
      seed="${3}"
      ;;
  esac
fi

if [[ $# -ge 4 ]]; then
  target="${4}"
fi

case "${target}" in
  native|wasm|wasm-gc|llvm|js)
    args=(--target "${target}" src/fuzz -- "${suite}" "${profile}")
    if [[ -n "${seed}" ]]; then
      args+=(--seed "${seed}")
    fi
    moon run "${args[@]}"
    ;;
  *)
    echo "usage: scripts/run-fuzz.sh [profile] [suite] [seed|target] [target]" >&2
    echo "target must be one of: native, wasm, wasm-gc, llvm, js" >&2
    exit 1
    ;;
esac
