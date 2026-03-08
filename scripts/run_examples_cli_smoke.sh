#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOON_BIN="${MOON_BIN:-${HOME}/.moon/bin/moon}"
if [[ ! -x "${MOON_BIN}" ]]; then
  MOON_BIN="moon"
fi

SMOKE_ROOT="${1:-${ROOT_DIR}/_build/examples-smoke}"
mkdir -p "${SMOKE_ROOT}"

run_case() {
  local name="$1"
  local expected_csv="$2"
  shift 2

  local out_dir="${SMOKE_ROOT}/${name}"
  rm -rf "${out_dir}"
  mkdir -p "${out_dir}"

  "${MOON_BIN}" run src/cmd --target native -- "$@" --out-dir "${out_dir}"

  IFS=',' read -r -a expected <<< "${expected_csv}"
  local expected_file
  for expected_file in "${expected[@]}"; do
    local path="${out_dir}/${expected_file}"
    if [[ ! -s "${path}" ]]; then
      echo "ERROR: expected non-empty output file missing: ${path}" >&2
      exit 1
    fi
  done

  echo "OK: ${name}"
}

run_case \
  "optimize-memory64" \
  "memory64_data.wasm" \
  --optimize \
  examples/modules/memory64_data.wat

run_case \
  "release-config" \
  "feature_mix.wasm,memory64_data.wasm,simple.wasm" \
  --config \
  examples/config/optimize-release.json

run_case \
  "advanced-features" \
  "table_dispatch.wasm,simd_lane_mix.wasm" \
  --global-effects \
  --flatten \
  --vacuum \
  examples/modules/table_dispatch.wat \
  examples/modules/simd_lane_mix.wat

echo "Example CLI smoke checks passed."
