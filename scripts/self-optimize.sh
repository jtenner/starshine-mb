set -euo pipefail

moon clean
moon build --target wasm
moon build --target native --release --package jtenner/starshine/cmd

trace_level="${SELF_OPT_TRACING_LEVEL:-helper}"
output_path="${SELF_OPT_OUTPUT_LOG:-output.log}"

cmd=(
  ./_build/native/release/build/cmd/cmd.exe
  --tracing "$trace_level"
  --optimize -O4z
  --out tests/node/dist/starshine-self-optimized-wasi.wasm
  ./_build/wasm/debug/build/cmd/cmd.wasm
)

rm -f "$output_path"

if command -v stdbuf >/dev/null 2>&1; then
  OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
    stdbuf -oL -eL "${cmd[@]}" 2>&1 | tee "$output_path"
else
  OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
    "${cmd[@]}" 2>&1 | tee "$output_path"
fi
