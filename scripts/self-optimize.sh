moon clean
moon build --target wasm
STARSHINE_TRACING=PASS OPTIMIZE_DUMP_FAILED_MODULE_STATE=1 \
  moon run src/cmd \
  --target native \
  --release \
  -- \
  --optimize -O4z \
  --out tests/node/dist/starshine-self-optimized-wasi.wasm ./_build/wasm/debug/build/cmd/cmd.wasm > output.log 2>&1
