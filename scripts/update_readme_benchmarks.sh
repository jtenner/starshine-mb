#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README_PATH="${README_PATH:-${ROOT_DIR}/README.mbt.md}"
MOON_BIN="${MOON_BIN:-/home/jtenner/.moon/bin/moon}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --readme)
      README_PATH="$2"
      shift 2
      ;;
    --moon)
      MOON_BIN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${README_PATH}" ]]; then
  echo "README not found: ${README_PATH}" >&2
  exit 1
fi

if [[ ! -x "${MOON_BIN}" ]]; then
  echo "moon binary not executable: ${MOON_BIN}" >&2
  exit 1
fi

START_MARKER="<!-- README_BENCHMARK_TABLE_START -->"
END_MARKER="<!-- README_BENCHMARK_TABLE_END -->"

start_line="$(grep -nF "${START_MARKER}" "${README_PATH}" | head -n1 | cut -d: -f1 || true)"
end_line="$(grep -nF "${END_MARKER}" "${README_PATH}" | head -n1 | cut -d: -f1 || true)"
if [[ -z "${start_line}" || -z "${end_line}" ]]; then
  echo "benchmark markers missing in README" >&2
  exit 1
fi
if (( start_line >= end_line )); then
  echo "benchmark marker order invalid in README" >&2
  exit 1
fi

measure_seconds() {
  local command="$1"
  local start_ns end_ns elapsed_ns
  start_ns="$(date +%s%N)"
  if ! bash -lc "${command}" >/dev/null; then
    echo "benchmark command failed: ${command}" >&2
    exit 1
  fi
  end_ns="$(date +%s%N)"
  elapsed_ns=$((end_ns - start_ns))
  awk -v ns="${elapsed_ns}" 'BEGIN { printf "%.3fs", ns / 1000000000 }'
}

declare -a BENCH_NAMES
declare -a BENCH_COMMANDS

BENCH_NAMES+=("Single CLI pipeline test (\`run_cmd_with_adapter runs requested passes for each module\`)")
BENCH_COMMANDS+=("${MOON_BIN} test --quiet --package jtenner/starshine/cmd --file cmd_test.mbt --index 5")

BENCH_NAMES+=("Fuzz harness smoke (\`run_wasm_smith_fuzz_harness smoke covers full pipeline\`)")
BENCH_COMMANDS+=("${MOON_BIN} test --quiet --package jtenner/starshine/cmd --file fuzz_harness_test.mbt --index 2")

BENCH_NAMES+=("Full test suite")
BENCH_COMMANDS+=("${MOON_BIN} test --quiet")

today="$(date -u +%Y-%m-%d)"
block_lines=()
block_lines+=("Measured on \`${today}\` in this repository with warm local build cache (\`moon test --quiet\`, debug profile, \`wasm-gc\` target). These are smoke/reference numbers, not strict performance guarantees.")
block_lines+=("")
block_lines+=("| Workload | Command | Wall time |")
block_lines+=("| --- | --- | --- |")

for i in "${!BENCH_NAMES[@]}"; do
  name="${BENCH_NAMES[$i]}"
  command="${BENCH_COMMANDS[$i]}"
  seconds="$(measure_seconds "${command}")"
  block_lines+=("| ${name} | \`${command}\` | \`${seconds}\` |")
done

if [[ "${DRY_RUN}" == true ]]; then
  printf '%s\n' "${block_lines[@]}"
  exit 0
fi

tmp_file="$(mktemp)"
head -n "${start_line}" "${README_PATH}" > "${tmp_file}"
printf '%s\n' "${block_lines[@]}" >> "${tmp_file}"
tail -n +"${end_line}" "${README_PATH}" >> "${tmp_file}"
mv "${tmp_file}" "${README_PATH}"

echo "Updated benchmark table in ${README_PATH}"
