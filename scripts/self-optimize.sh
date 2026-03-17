set -euo pipefail

moon clean
moon build --target wasm
moon build --target native --release --package jtenner/starshine/cmd

trace_level="${SELF_OPT_TRACING_LEVEL:-pass}"
output_path="${SELF_OPT_OUTPUT_LOG:-output.log}"
moon_bin="${MOON_BIN:-moon}"
native_release_cmd_exe="./_build/native/release/build/cmd/cmd.exe"
native_release_cmd="./_build/native/release/build/cmd/cmd"

if [[ -x "$native_release_cmd_exe" ]]; then
  cmd=(
    "$native_release_cmd_exe"
    --tracing "$trace_level"
    --optimize -O4z
    --out tests/node/dist/starshine-self-optimized-wasi.wasm
    ./_build/wasm/debug/build/cmd/cmd.wasm
  )
elif [[ -x "$native_release_cmd" ]]; then
  cmd=(
    "$native_release_cmd"
    --tracing "$trace_level"
    --optimize -O4z
    --out tests/node/dist/starshine-self-optimized-wasi.wasm
    ./_build/wasm/debug/build/cmd/cmd.wasm
  )
else
  cmd=(
    "$moon_bin"
    run
    --target native
    --release
    src/cmd
    --
    --tracing "$trace_level"
    --optimize -O4z
    --out tests/node/dist/starshine-self-optimized-wasi.wasm
    ./_build/wasm/debug/build/cmd/cmd.wasm
  )
fi

rm -f "$output_path"

if command -v stdbuf >/dev/null 2>&1; then
  OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
    stdbuf -oL -eL "${cmd[@]}" >"$output_path" 2>&1
else
  OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
    "${cmd[@]}" >"$output_path" 2>&1
fi
