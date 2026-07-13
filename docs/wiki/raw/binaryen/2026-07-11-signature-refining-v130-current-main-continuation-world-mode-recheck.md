# Binaryen `signature-refining` version_130 / current-main continuation and world-mode recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for [`../../binaryen/passes/signature-refining/`](../../binaryen/passes/signature-refining/)

## Scope

This source reconciliation compares the `SignatureRefining.cpp` owner at Binaryen `version_129`, public `version_130`, and current `main`. It corrects a behavior-bearing claim retained by the older 2026-05-05 freshness bridge: current Binaryen no longer treats continuation use as a params-only refinement blocker.

This capture also records the version_130/current-main threading of `PassOptions::worldMode` through public-type discovery and the atomic global signature rewrite. It is a focused owner/registration/lit reread, not an execution run or evidence that Starshine implements the pass.

## Primary sources reread

### Owner

- `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
- `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/SignatureRefining.cpp>
- current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>

### Registration and scheduler context

- `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Dedicated fixture oracle

- `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/signature-refining.wast>
- current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>

### Historical provenance retained

- [`2026-04-24-signature-refining-primary-sources.md`](2026-04-24-signature-refining-primary-sources.md) - `version_129` source dossier.
- [`2026-05-05-signature-refining-current-main-recheck.md`](2026-05-05-signature-refining-current-main-recheck.md) - superseded freshness conclusion; still useful for its narrow historical review scope.

## Durable correction: continuations now freeze the whole signature

`version_129` marks a continuation's underlying signature with `canModifyParams = false`. That blocks parameter refinement but can still allow result refinement.

`version_130` and current `main` instead mark the same underlying signature with `canModify = false`. The nearby source comment says Binaryen does not update continuation users such as `cont.bind` and `resume` with new types. Therefore current Binaryen freezes **both parameters and results** for any function signature used by a continuation.

This is not a cosmetic wording change:

- a current-port design must treat continuation use as a full no-change boundary;
- a test that only asserts unchanged params is incomplete because it could miss an invalid result-only refinement; and
- pages that group continuations with JS-called signatures as params-only blockers are stale.

JS-called signatures remain different: their current source path still sets `canModifyParams = false`, so result refinement may remain eligible there.

## Current API-shaped change: world mode reaches both type-boundary helpers

`version_130` and current `main` pass `getPassOptions().worldMode` to:

- `ModuleUtils::getPublicHeapTypes(...)`; and
- `GlobalTypeRewriter::updateSignatures(...)`.

The pass still has the same visible GC and no-table gates, heap-type aggregation, LUB computation, intrinsic repair, public registration, and closed-world default-pipeline neighborhood on the reviewed surfaces. However, future ports must carry one coherent world/visibility policy through both public-type classification and type rewriting; a local implementation must not treat those as unrelated switches.

This capture does not infer every behavioral consequence of Binaryen's `worldMode` helpers. Their exact open/closed-world semantics require a helper-specific source review before a Starshine port broadens beyond the documented conservative boundary.

## Dedicated fixture and scheduler result

The current public registration still exposes `signature-refining` with the summary “apply more specific subtypes to signature types where possible.” The default scheduler remains the closed-world GC/type-cluster route after `signature-pruning` and before `global-refining`.

The dedicated `signature-refining.wast` fixture remains the primary proof surface for direct and `call_ref` parameter/result LUBs, body repair, public/import/tag/subtype boundaries, intrinsic repair, and continuation coverage. The focused reread found no additional reviewed owner/registration/fixture drift beyond the continuation blocker and world-mode API threading above.

## Local-status boundary

Starshine remains unchanged by this source capture:

- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) keeps `signature-refining` boundary-only.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--signature-refining` in `SUPPORTED_PASS_FLAGS`.

So a rejected local request remains a status check, not parity evidence. A future port must add continuation-as-full-blocker fixtures before a pass-fuzz lane becomes meaningful.

## Consumability rule

Use this capture for current Binaryen `signature-refining` claims about continuation blocking and world-mode threading. Keep the `version_129` pages as historical algorithm context, but do not repeat their params-only continuation rule as current behavior.
