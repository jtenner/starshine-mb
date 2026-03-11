set -euo pipefail

moon clean
moon build --target wasm
moon build --target native --release --package jtenner/starshine/cmd

OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
  ./_build/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --optimize -O4z \
  --out tests/node/dist/starshine-self-optimized-wasi.wasm ./_build/wasm/debug/build/cmd/cmd.wasm > output.log 2>&1
