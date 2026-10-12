# Starshine GC host for Wago

This runner supplies the scalar bulk protocol used by `src/cmd_gc`. It reads and
writes complete file buffers through exported linear memory. The input and output
need four host calls total. Arguments, environment queries and trace output use
separate requests. The runner does not install a MoonBit plugin.

Build from the repository root:

```sh
moon build --target wasm-gc --release src/cmd_gc
go build -C tools/wago-host -o starshine-wago .
tools/wago-host/starshine-wago _build/wasm-gc/release/build/cmd_gc/cmd_gc.wasm input.wasm -O4z --out output.wasm
```

The Go module pins the fixes from [Wago PR 948](https://github.com/wago-org/wago/pull/948).
The local runner uses explicit bounds, a 64 MiB native stack, a 64 MiB nursery and
a 2 GiB Wasm heap. It leaves Wago's collection admission checks active. Old unused
filesystem imports are bound to traps so an accidental byte-wise path fails.

Set `STARSHINE_BENCH_REPORT=report.json` for cold compile/instantiate/invoke wall
times, allocation totals, exact-root status and I/O operation counts. Use
`--tracing phase` for command and pass timers. Report totals include runtime close;
Go allocation totals are not a Wasm heap limit or peak RSS.

The same artifact runs with:

```sh
node --stack-size=65536 tools/run-gc-cli.mjs _build/wasm-gc/release/build/cmd_gc/cmd_gc.wasm input.wasm -O4z --out output.wasm
BUN_JSC_maxPerThreadStackUsage=67108864 bun tools/run-gc-cli.mjs _build/wasm-gc/release/build/cmd_gc/cmd_gc.wasm input.wasm -O4z --out output.wasm
```

The large artifact comparison used a 128 MiB OS stack. See the
[measurement record](../../docs/wiki/tooling/tracing-playbook.md#october-11-2026-bulk-host-and-wago-fixes)
for versions, hashes, phase times and the remaining Wago performance cost.

Tests:

```sh
go test -C tools/wago-host ./...
STARSHINE_BULK_WASM=_build/wasm-gc/release/build/cmd_gc/cmd_gc.wasm node --stack-size=65536 --test node/test/bulk-cli-host.test.mjs
BUN_JSC_maxPerThreadStackUsage=67108864 STARSHINE_BULK_WASM=_build/wasm-gc/release/build/cmd_gc/cmd_gc.wasm bun test node/test/bulk-cli-host.test.mjs
```
