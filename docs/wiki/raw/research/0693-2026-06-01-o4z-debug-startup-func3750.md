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

The blocker is corruption of the startup map's bucket-array object header after early insertions in `func3750`. The June 1 evidence showed the corruption follows a map release/destruction path rather than bad initial capacity or hash masking.

June 2 follow-up narrowed the owner further: the trap is **latent before the current `-O4z` pass sequence**. A raw-input binary patch that only stubs the externally invalid huge-local `func535` validates and still traps on the same startup path (`func4686 -> func473 -> func3749 -> func3751 -> func28` in that unoptimized/stubbed numbering). Coalesce-locals is therefore the first pass that makes the committed input externally runnable, but it is not the pass that introduces the startup map trap.

Remaining plausible owner families:

1. the committed debug-WASI input already contains bad MoonBit runtime/refcount ownership traffic around the startup `HashMap.set` population;
2. an earlier build-time pass or artifact-generation step produced the committed input with stale map ownership semantics;
3. a lower-level ABI/runtime convention around `call 43` retain and `call 45` release is being misunderstood by the startup map code;
4. less likely after the raw-stub evidence: a current `-O4z` local-like pass corrupts the map functions, because those functions are unchanged by coalesce-only and the full-pipeline trap survives omitting `ssa-nomerge`, `tuple-optimization`, `reorder-locals`, and `simplify-locals-nostructure`.

## June 2 continuation evidence

Current direct `-O4z` was rebuilt with the backup MoonBit toolchain and matched an explicit 39-pass shrink-list run byte-for-byte (`.tmp/o4z-bench/current-direct-o4z.wasm` and `.tmp/o4z-bench/current-prefix-dumps/final.wasm`, both `3,172,802` bytes). The output validates and traps under Node/WASI on the same map startup path.

Prefix dumps from the explicit pass list showed:

- prefixes `00` through `24` remain externally invalid only because `func535` exceeds the local-count limit;
- prefix `25` (`coalesce-locals`) is the first validating prefix;
- prefix `25` and every later prefix trap in the startup map path;
- `coalesce-locals` alone is enough to make the input validate and reproduce the startup trap.

Function print snapshots before and after coalesce-only showed `func473`, `func3748`, `func3749`, `func3750`, `func3751`, `func3752`, and `func3753` are unchanged by coalesce-only. Full-pipeline snapshots showed the relevant map bodies only change textually under tuple/reorder-local reshaping, and ablation runs still trap when `tuple-optimization`, `reorder-locals`, both together, `simplify-locals-nostructure`, or `ssa-nomerge` are omitted.

A scratch binary patch replaced only absolute `func535` (code index `518`, after `17` imported functions) with a tiny `unreachable` body. The resulting `.tmp/o4z-bench/raw-stub-f535.wasm` validates without applying any optimizer pass and still traps:

```text
RuntimeError: unreachable
    at wasm-function[28]
    at wasm-function[3751]
    at wasm-function[3749]
    at wasm-function[473]
    at wasm-function[4686]
```

That proves the startup trap is not introduced by the current self/debug `-O4z` recovery passes. It is present as soon as the committed input's unrelated huge-local validation blocker is removed.

Additional scratch instrumentation on the reduced fixture refined the June 1 release hypothesis. In the extracted numbering (`func20 -> func25 -> func27 -> func11`, with retain/release as `func15`/`func17`):

```text
tracked map pointer = 181248
retain1 before/after = 1 -> 2
func27 first empty-branch start map header = 0
first empty-branch new entry pointer = 181328
release2 before = 1
third entry map header = 0
third entry bucket header = 0
```

This means the first caller-side retain does happen, but the map header is already zero by the time the first empty insert branch starts in `func27`, before the branch's final tracked `release`. That refines the earlier inference: the final release/free path is still where the stale object becomes visible, but the earliest observed map-header clobber in the reduced fixture is before the first empty-branch insertion body, between the caller retain and the insert branch. The exact write that zeroes the map header is still unknown.

## Focused TDD slice

A reduced startup-root fixture was extracted from the raw-stub module and patched to export memory plus the extracted start function as `_start`:

- fixture: `tests/repros/o4z-debug-startup-map-init-repro.wasm`
- failing test: `scripts/lib/o4z-debug-startup-map.test.ts`
- confirmation command: `bun test scripts/lib/o4z-debug-startup-map.test.ts`
- current result: fails with `RuntimeError: Unreachable code should not be executed` in the same map startup family.

This is the active TDD slice for the remaining startup trap. Production fixes should make this reduced fixture complete runtime initialization before retrying the full self/debug `-O4z --help` candidate.

## Recommended next slice

1. Treat `scripts/lib/o4z-debug-startup-map.test.ts` as the failing TDD guard.
2. Use the reduced `tests/repros/o4z-debug-startup-map-init-repro.wasm` fixture for instrumentation before returning to the full `tests/node/dist/starshine-debug-wasi.wasm` artifact.
3. Identify why the startup map's caller-visible retain traffic does not keep the map alive across repeated inserts, now without conflating the issue with `func535` validation repair or current local-like optimizer passes.
4. Once the runtime/source owner is known, add the smallest adjacent MoonBit pass/runtime/source regression if the Bun fixture remains too integration-shaped for the final fix.

## Evidence status

The June 1 findings were observational and based on temporary `.tmp/o4z-bench/` WAT instrumentation plus Node/WASI replay. The June 2 follow-up adds a focused failing repo test and reduced fixture. Scratch generation helpers and large temporary artifacts remain under `.tmp/o4z-bench/` and should not be committed.

## Reference semantics

The `RuntimeError: unreachable` surface is consistent with the WebAssembly JavaScript interface, not a separate Node-only trap mode: MDN documents `WebAssembly.RuntimeError` as the error type WebAssembly throws for traps, and documents `unreachable` as an unconditional trap instruction that raises that runtime error when executed.

Primary references:

- <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/RuntimeError>
- <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/unreachable>

This keeps the remaining failure classified as a real runtime trap while the reduced fixture stays the active TDD guard.
