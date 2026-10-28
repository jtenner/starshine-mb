# Local filesystem dependency

This package copies the filesystem implementation from `moonbitlang/x@0.5.1`.
`src/fs` uses this copy so builds and published source include the native
resource-lifetime repair without edits to an installed dependency cache.
The remaining dependency supplies `moonbitlang/x/unicode`.

Source archive: `moonbitlang/x/0.5.1.zip`, SHA-256
`cdceed523974dbd2833930f70e7e7ee087b77220659c55f87ab678197976aeae`.
Upstream: <https://github.com/moonbitlang/x>. Copyright 2025 International
Digital Economy Academy. Apache-2.0 terms and source headers are retained;
see [`licenses/Apache-2.0.txt`](../../../licenses/Apache-2.0.txt).

Starshine changes, 2026-10-28:

- `fs_native.mbt` closes an owned stream after seek, tell, rewind, read, write
  or flush failure. It saves the original error before close. The normal close
  and its error handling are unchanged.
- `moon.pkg` omits the upstream test-only encoding import. Platform selection
  is unchanged: native/LLVM, Wasm/WasmGC and JS each retain their implementation.
- `pkg.generated.mbti` uses this package's local name.

The C bridge, common API and Wasm/JS implementations are copied without edits.
When updating the upstream version, review these six failure paths and run
[`tests/resource_lifetime/native.test.mjs`](../../../tests/resource_lifetime/native.test.mjs)
and the `src/fs` tests. The fault injector compiles the exact local native
owner and C bridge, replaces only libc calls in a temporary test package, and
checks the returned error plus the exact stream's close count and live state.
