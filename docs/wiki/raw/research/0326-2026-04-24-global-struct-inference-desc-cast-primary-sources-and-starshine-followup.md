# `global-struct-inference-desc-cast` primary sources and Starshine follow-up

Date: 2026-04-24
Pass: local `global-struct-inference-desc-cast` / upstream `gsi-desc-cast`
Status: absorbed into living wiki pages

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/` folder already had a corrected overview, Binaryen strategy, implementation/test map, descriptor-singleton mechanics page, and shape catalog. It still lacked two pieces that newer pass dossiers now standardize:

- an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`
- a dedicated Starshine status/port-strategy page that points readers to exact local code locations

This follow-up closes that provenance and local-follow-along gap without creating a duplicate pass dossier.

## Sources reviewed

Primary online sources:

- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `GlobalStructInference.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- current `main` `GlobalStructInference.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- dedicated and neighboring lit files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>

Local sources:

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/global_struct_inference.mbt`
- `src/passes/global_struct_inference_test.mbt`
- `src/cmd/fuzz_harness_wbtest.mbt`
- `src/lib/types.mbt`
- `src/wast/keywords.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/`
- `docs/wiki/binaryen/passes/global-struct-inference/`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `agent-todo.md`

## Durable findings

- Binaryen `gsi-desc-cast` remains the shared `GlobalStructInference.cpp` engine with desc-cast mode enabled, not a separate cast optimizer.
- The sibling-only rewrite remains the narrow `visitRefCast` target-descriptor-singleton rule: descriptor type exists, target is exact or has no strict subtypes, and the target descriptor heap type has exactly one global in `typeGlobals`.
- The direct proof surface is `gsi-to-desc-cast.wast`; `gsi-desc.wast` is neighboring descriptor machinery, and `gsi.wast` is broad shared-GSI context.
- Starshine currently keeps `global-struct-inference-desc-cast` as a boundary-only name. Explicit requests are rejected; there is no pass-manager dispatch case, no owner file, no active preset slot, and no backlog slice.
- Starshine's active `global-struct-inference` implementation is not this sibling. It is a smaller closed-world direct-global `struct.get*` fold in `src/passes/global_struct_inference.mbt`.
- Starshine does have important prerequisite syntax/instruction infrastructure for a future port: `RefCastDescEq` exists in the IR, WAT lowering resolves the target type, the binary codec handles the opcode pair, and the validator covers the stack effect.

## Wiki updates made from this note

- Added raw source manifest: `docs/wiki/raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`.
- Added Starshine status page: `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/starshine-strategy.md`.
- Refreshed the `global-struct-inference-desc-cast` living dossier pages so they cite the raw manifest and local status bridge.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.
- Marked older research notes `0170` and `0212` as superseded for raw-source provenance and local status, while preserving `0212` as the source-correction note that fixed the cast-input-origin and dedicated-test overreads.

## Open follow-up

No immediate same-pass dossier gap remains. A future implementation thread should re-check current Binaryen `main` before coding, then decide whether to expand Starshine's existing `global_struct_inference.mbt` owner into a shared GSI-family module pass or create a sibling owner for the descriptor-cast variant. Either path must keep the local-vs-upstream naming split and the effective closed-world dependency explicit.
