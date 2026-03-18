#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

input_path="$tmpdir/input.wasm"
printf '\0asm' >"$input_path"

fake_binary="$tmpdir/fake-starshine"
cat >"$fake_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
input=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      out="$2"
      shift 2
      ;;
    *)
      input="$1"
      shift
      ;;
  esac
done

if [[ -z "$out" ]]; then
  printf 'missing --out\n' >&2
  exit 1
fi

printf '0123456789' >"$out"

cat >&2 <<TRACE
[trace] input ${input}:read bytes=20
[trace] input ${input}:lowered bytes=16
[trace] input ${input}:pass_count=2 optimize:start
[trace] input ${input}:opt pass[1/2]:done pass=SimplifyLocals changed=true funcs_visited=4 funcs_changed=2 instrs_before=20 instrs_after=15 transform_elapsed_ms=4 validation_elapsed_ms=1 elapsed_ms=5
[trace] input ${input}:opt pass[2/2]:done pass=Vacuum changed=false funcs_visited=4 funcs_changed=0 instrs_before=15 instrs_after=14 transform_elapsed_ms=2 validation_elapsed_ms=0 elapsed_ms=2
[trace] input ${input}:opt done elapsed_ms=8
[trace] input ${input}:encode bytes=10
TRACE
EOF
chmod +x "$fake_binary"

output="$(
  cd "$repo_root" &&
    node scripts/benchmark-optimize.mjs \
      --binary "$fake_binary" \
      --passes simplify-locals,vacuum \
      --input "$input_path" \
      --repeat 1
)"

if [[ "$output" != *"Benchmark Summary"* ]]; then
  printf 'expected benchmark summary header, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ "$output" != *"aggregate_wasm_bytes: 16 -> 10 (-6, -37.50%)"* ]]; then
  printf 'expected aggregate wasm byte delta, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ "$output" != *"SimplifyLocals"* ]]; then
  printf 'expected SimplifyLocals row, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ "$output" != *"Vacuum"* ]]; then
  printf 'expected Vacuum row, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ "$output" != *"-6"* ]]; then
  printf 'expected instruction or size delta in output, got:\n%s\n' "$output" >&2
  exit 1
fi
