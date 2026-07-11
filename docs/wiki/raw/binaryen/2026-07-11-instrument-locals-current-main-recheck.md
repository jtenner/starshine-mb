# Binaryen `instrument-locals` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness capture for `docs/wiki/binaryen/passes/instrument-locals/`

## Question and scope

Did current Binaryen `main` change the documented `instrument-locals` contract since the prior 2026-05-06 source recheck?

This is a focused owner/registration/lit reread, not a claim that every upstream use or downstream interaction was audited. The current public release horizon is recorded separately in [`../../binaryen/release-horizon-and-oracles.md`](../../binaryen/release-horizon-and-oracles.md); this capture uses current `main` only to detect behavior-bearing drift in this pass.

## Primary sources reread

- [`InstrumentLocals.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp)
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/InstrumentLocals.cpp>
- [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- [`instrument-locals_all-features_disable-gc.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast)
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- [`instrument-locals_effects.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast)
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_effects.wast>
- [`instrument-locals-eh-legacy.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast)
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals-eh-legacy.wast>

## Confirmed current contract

No behavior-bearing drift was found on the reread surfaces.

1. **Public identity remains unchanged.** `pass.cpp` still registers `instrument-locals` with the broad help text “intercept all loads and stores.” The owner-file comment is narrower: it instruments **local** reads and writes. Keep that wording mismatch explicit; `instrument-memory` is the sibling for memory/heap traffic.
2. **The transform remains effectful.** `InstrumentLocals::addsEffects()` still returns `true`. The effects lit lane still runs `generate-global-effects -> instrument-locals -> vacuum` and shows that inserted import calls prevent cleanup available in the non-instrumented comparison lane.
3. **Supported local traffic is wrapped postwalk.** `local.get` becomes a value-returning `get_*` call; `local.set` / `local.tee` retain the outer write while their value becomes a `set_*` call. A single module-wide counter supplies call IDs across both visitors.
4. **The helper/import asymmetry remains intentional current behavior.** The owner injects scalar `get_i64` / `set_i64` imports, but both visitors still return without wrapping ordinary `i64` locals. The all-features lit fixture checks both the imports and unchanged `i64` accesses.
5. **The narrow reference/SIMD/EH boundaries remain.** Nullable `funcref` and `externref`, plus `v128` when SIMD is enabled, are supported; general reference types remain an explicit TODO/fatal boundary, typed function-reference values on sets are skipped, `unreachable` set values are skipped, and legacy-EH `Pop` payloads remain uninstrumented. The legacy-EH fixture still checks the `Pop` preservation shape.
6. **Helper ABI and scope remain unchanged.** Helpers are `env` function imports with `(i32 call_id, i32 local_id, value) -> value`; scalar imports are unconditional, reference imports require reference types, and `v128` imports require SIMD.

## Starshine reconciliation

Checked repository evidence remains sufficient for the local-status claim:

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) contains no `instrument-locals` active, boundary-only, or removed entry; the unknown-name path still returns `unknown pass flag ...`.
- [`src/passes/registry_test.mbt`](../../../../src/passes/registry_test.mbt) has no `instrument-locals` compatibility expectation.
- `agent-todo.md` has no dedicated `instrument-locals` slice.

So Starshine remains **unknown-pass / upstream-only**, not partially implemented. Its existing local/import/HOT primitives are future-port prerequisites only; they are not evidence that this transform exists.

## Supersession and limits

- This capture supersedes the **current-main freshness claim** in [`2026-05-06-instrument-locals-current-main-recheck.md`](2026-05-06-instrument-locals-current-main-recheck.md), not the older document's historical provenance.
- No local implementation, Binaryen execution, fuzzing, or performance measurement was run. This is documentation/source reconciliation only.
- Raw GitHub rendering may flatten source lines. The stable file URLs and the explicitly named owner/registration/fixture surfaces are the durable anchors rather than volatile `main` line numbers.
