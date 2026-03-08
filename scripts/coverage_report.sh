#!/usr/bin/env bash
set -euo pipefail

TOP_N=10
BASELINE_FILE=""
UPDATE_BASELINE=0
MOON_BIN="${MOON_BIN:-/home/jtenner/.moon/bin/moon}"

usage() {
  cat <<'EOF'
Usage: scripts/coverage_report.sh [options]

Options:
  --top N                 Number of files to show in the "top uncovered" list (default: 10)
  --baseline PATH         Baseline file for delta tracking (format: total=<n>, files=<n>)
  --update-baseline       Write current total/files into the baseline file
  --moon PATH             Moon binary path (default: /home/jtenner/.moon/bin/moon, fallback: moon)
  -h, --help              Show this help text
EOF
}

while (($# > 0)); do
  case "$1" in
    --top)
      TOP_N="${2:?missing value for --top}"
      shift 2
      ;;
    --baseline)
      BASELINE_FILE="${2:?missing value for --baseline}"
      shift 2
      ;;
    --update-baseline)
      UPDATE_BASELINE=1
      shift
      ;;
    --moon)
      MOON_BIN="${2:?missing value for --moon}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v "$MOON_BIN" >/dev/null 2>&1; then
  MOON_BIN="moon"
fi

if ! command -v "$MOON_BIN" >/dev/null 2>&1; then
  echo "moon binary not found (tried /home/jtenner/.moon/bin/moon and moon)" >&2
  exit 1
fi

report_file="$(mktemp)"
pairs_file="$(mktemp)"
trap 'rm -f "$report_file" "$pairs_file"' EXIT

"$MOON_BIN" coverage analyze >"$report_file"

total_uncovered="$(
  sed -n 's/^Total: \([0-9][0-9]*\) uncovered line(s) in \([0-9][0-9]*\) file(s)$/\1/p' "$report_file" \
    | tail -n 1
)"
file_count="$(
  sed -n 's/^Total: \([0-9][0-9]*\) uncovered line(s) in \([0-9][0-9]*\) file(s)$/\2/p' "$report_file" \
    | tail -n 1
)"

if [[ -z "${total_uncovered}" || -z "${file_count}" ]]; then
  echo "Unable to parse coverage summary from moon output." >&2
  exit 1
fi

awk '
  /^[0-9]+ uncovered line\(s\) in .*:$/ {
    count = $1
    file = $0
    sub(/^[0-9]+ uncovered line\(s\) in /, "", file)
    sub(/:$/, "", file)
    printf "%s\t%s\n", count, file
  }
' "$report_file" >"$pairs_file"

echo "Coverage summary: total uncovered lines=${total_uncovered}, files=${file_count}"
echo "Top ${TOP_N} uncovered files:"
if [[ -s "$pairs_file" ]]; then
  sort -t $'\t' -k1,1nr -k2,2 "$pairs_file" \
    | head -n "$TOP_N" \
    | awk -F $'\t' '{ printf "  %s\t%s\n", $1, $2 }'
else
  echo "  (no uncovered files reported)"
fi

if [[ -n "$BASELINE_FILE" ]]; then
  baseline_total=0
  baseline_files=0
  if [[ -f "$BASELINE_FILE" ]]; then
    baseline_total="$(
      sed -n 's/^total=\([0-9][0-9]*\)$/\1/p' "$BASELINE_FILE" | tail -n 1
    )"
    baseline_files="$(
      sed -n 's/^files=\([0-9][0-9]*\)$/\1/p' "$BASELINE_FILE" | tail -n 1
    )"
    baseline_total="${baseline_total:-0}"
    baseline_files="${baseline_files:-0}"
  fi

  delta_total=$((total_uncovered - baseline_total))
  delta_files=$((file_count - baseline_files))
  plus_total=""
  plus_files=""
  if ((delta_total > 0)); then
    plus_total="+"
  fi
  if ((delta_files > 0)); then
    plus_files="+"
  fi
  echo "Coverage delta vs baseline (${BASELINE_FILE}): lines ${plus_total}${delta_total}, files ${plus_files}${delta_files}"

  if ((UPDATE_BASELINE == 1)); then
    mkdir -p "$(dirname "$BASELINE_FILE")"
    {
      echo "total=${total_uncovered}"
      echo "files=${file_count}"
    } >"$BASELINE_FILE"
    echo "Updated baseline: ${BASELINE_FILE}"
  fi

  if [[ "${CI:-}" == "true" && $delta_total -gt 0 ]]; then
    echo "::error::Uncovered line count increased by ${delta_total} (baseline ${baseline_total}, current ${total_uncovered})"
    exit 1
  fi
fi
