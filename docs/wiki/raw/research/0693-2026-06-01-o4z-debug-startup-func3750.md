# 0693 - O4z debug startup func3750 bucket-array trap investigation

Date: 2026-06-01

## Context

Continuation of the full self/debug `-O4z` recovery after commit `4ab7e1bc2` repaired the previous `func21` TLSF allocator initialization hang. The next blocker is a Node/WASI startup trap in the self-optimized debug command artifact:

- input: `tests/node/dist/starshine-debug-wasi.wasm`
- latest candidate inspected: `.tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm`
- startup path: `func4676 -> func473 -> func3748 -> func3750 -> func28`
- trap: `RuntimeError: unreachable` in range-check helper `func28`

The candidate externally validates with `wasm-tools validate --features all`, so the remaining failure is runtime semantics rather than wasm validation.

## Reproduction shape

The relevant run shape remains:

```sh
export MOONBIT_BIN_DIR=$PWD/.tmp/moonbit.backup-20260601T014334Z/bin
export PATH=$PWD/.tmp/moonbit.backup-20260601T014334Z/bin:$PATH
moon build --target native --release src/cmd
_build/native/release/build/cmd/cmd.exe -O4z \
  --out .tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
wasm-tools validate --features all .tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm
node - <<'NODE'
import { runWasmStart } from './scripts/lib/moonbit-wasi-runner.mjs';
const code = await runWasmStart({
  wasmPath: '.tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm',
  args: ['--help'],
  cwd: process.cwd(),
  preopens: { '.': process.cwd() },
});
console.log('exit', code);
NODE
```

## Instrumentation findings

Temporary WAT instrumentation was applied only under `.tmp/o4z-bench/` and was not committed. The instrumentation removed the module start wrapper when needed and exported `func4676` as `__init` so memory could be inspected after the trap.

### `func28` arguments

Instrumenting `func28` to store its arguments before trapping showed the failing range check is:

```text
idx   = 110
lower = 0
upper = -1
```

This means `func3750` is not failing because the hash index is directly outside the intended `0..511` mask. It is calling the helper with an upper bound derived from an array whose runtime length has become zero (`0 - 1 == -1`).

### Map and bucket-array state

Further instrumentation around the first range-check call in `func3750` and the map constructor `func3752` showed:

```text
map pointer                   = 181248
map capacity field offset=8   = 512
map mask field offset=12      = 511
map count field offset=16     = 2
bucket array pointer          = 179184
bucket array header in 3750   = 0
bucket array created in 3752  = 512
```

Interpretation: `func3752` correctly allocates the bucket array with length `512`, stores it in the map at offset `20`, and initializes the map capacity/mask as expected. By the failing call in `func3750`, the same bucket array pointer is still in the map, but its header has been overwritten/freed/zeroed, so `call 26` reports length `0`.

### Early insertion timing

Instrumentation of `func473` and `func3748` showed the failure occurs during very early startup global-map population. At the observed trap, the map count is `2`, so the failing insertion is around the third insert into the map initialized by `func473`.

The caller-side map retain pattern in `func473` is present before insertion calls. The `func3748` wrapper retains the key/value argument shape, but the broader evidence points to the bucket array lifetime/header becoming invalid after early insertion rather than to a bad initial capacity or bad hash mask.

## Temporary patch experiments

- Reintroducing/storing the second typed loop-carried value in `func3750` was not sufficient. One direct variant failed validation due stack arity at loop fallthrough; an adjusted variant validated but still trapped in `func28`.
- Removing `local.get 0; call 45` map releases inside `func3750` avoided the immediate `func28` trap but later failed with an allocator/memory out-of-bounds trap. This is not a fix, but it supports treating the issue as lifetime/refcount or ownership-adjacent rather than a pure hash-index arithmetic bug.

## Current hypothesis

The blocker is likely corruption of the bucket array object header after early insertions in `func3750`. Plausible owner families:

1. a local-like rewrite in or before `func3750` corrupts ownership/refcount flow for the map or bucket array;
2. a loop-param/local rewrite in `func3750` still mishandles a carried value or live local despite the earlier TypeIdx-loop guards;
3. a pass rewrites a `call 43`/`call 45` retain/release pair or its surrounding local traffic unsafely;
4. less likely: allocator/data initialization is still corrupting nearby headers, but `func3752`'s immediate construction evidence makes this secondary.

## Recommended next slice

1. Add cleaner temporary instrumentation to count `func3748`/`func3750` insert calls and snapshot the bucket-array header before and after each insertion.
2. Identify the exact branch in `func3750` where the bucket array header changes from `512` to `0`.
3. Compare that branch against the unoptimized printed input and a fresh debug source build where function mapping permits.
4. Once the owner rewrite is known, add a focused regression in the owning pass before implementation.

## Evidence status

No production source changes were made during this investigation. The findings are observational and based on temporary `.tmp/o4z-bench/` WAT instrumentation plus Node/WASI replay.
