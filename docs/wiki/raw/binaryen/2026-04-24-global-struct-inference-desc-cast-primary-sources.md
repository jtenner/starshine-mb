---
kind: source-capture
status: supported
last_reviewed: 2026-04-24
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast
related:
  - ../research/0170-2026-04-21-global-struct-inference-desc-cast-binaryen-research.md
  - ../research/0212-2026-04-21-global-struct-inference-desc-cast-source-confirmation-followup.md
  - ../research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/global-struct-inference-desc-cast/index.md
---

# Binaryen `gsi-desc-cast` primary-source capture

Captured: 2026-04-24

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GlobalStructInference.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - Key reviewed locations: `GlobalStructInference(bool optimizeToDescCasts)`, `run(Module*)`, `typeGlobals`, `visitRefCast(RefCast*)`, descriptor-value un-nesting, nested `reorder-globals-always`, and the public factories `createGlobalStructInferencePass()` / `createGlobalStructInferenceDescCastPass()`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: public pass registration for `gsi` and sibling `gsi-desc-cast`.
- `test/lit/passes/gsi-to-desc-cast.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
  - Key reviewed location: direct `--gsi` versus `--gsi-desc-cast` delta, including positive `ref.cast_desc_eq` cases, strict-subtype bailouts, exact-cast cases, zero/many descriptor-global bailouts, no-descriptor bailouts, nullable casts, and unreachable-cast preservation.
- `test/lit/passes/gsi-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
  - Key reviewed location: neighboring descriptor-read and descriptor-un-nesting coverage inherited from the shared GSI engine.
- `test/lit/passes/gsi.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
  - Key reviewed location: broad plain-GSI context for the shared engine; not the headline oracle for the desc-cast-specific rewrite.

## Durable facts captured

- Binaryen publishes the descriptor-cast sibling under the public pass name `gsi-desc-cast`; Starshine tracks the same surface locally under the longer registry name `global-struct-inference-desc-cast`.
- `gsi` and `gsi-desc-cast` share one owner file and one pass class. The sibling difference is the constructor flag: `createGlobalStructInferencePass()` uses `GlobalStructInference(false)`, while `createGlobalStructInferenceDescCastPass()` uses `GlobalStructInference(true)`.
- The pass has a hard GC feature gate. When desc-cast mode is enabled, it also builds `SubTypes` so `visitRefCast` can reject non-exact targets that still have strict subtypes.
- The desc-cast-specific rewrite depends on `typeGlobals`, which is populated by closed-world analysis. The pass can still run without `--closed-world`, but the `ref.cast` -> `ref.cast_desc_eq` delta is effectively closed-world-dependent because an empty `typeGlobals` map gives no singleton descriptor global.
- `visitRefCast` is the sibling-only direct rewrite surface. It rejects non-desc-cast mode, unreachable cast result types, targets without descriptor types, non-exact targets with strict subtypes, descriptor types absent from `typeGlobals`, and descriptor types with zero or multiple globals.
- The positive rewrite is direct: Binaryen builds a `global.get` of the singleton descriptor global and replaces the original cast with a descriptor-equality cast at the original target type.
- Fresh-global descriptor un-nesting remains inherited shared-engine behavior. If un-nesting adds globals, Binaryen runs nested `reorder-globals-always` so new globals appear before their uses.
- `gsi-to-desc-cast.wast` is the primary direct lit oracle for this public sibling. `gsi-desc.wast` proves neighboring descriptor machinery, and `gsi.wast` remains broad family context.

## Current-`main` drift note

A 2026-04-24 spot check of `main` on the reviewed `visitRefCast`, un-nesting, factory, registration, and dedicated lit-test surfaces did not surface teaching-relevant drift from the `version_129` contract captured here. The only inspected source difference noted in the current-main view was comment spelling cleanup around the parallel optimization comment; the `visitRefCast` gates and rewrite still match the tagged source on the reviewed lines.

## Uncertainty and contradiction notes

- The older `0170` research note found the public pass and owner-file split but missed the dedicated `gsi-to-desc-cast.wast` proof file and over-weighted `gsi.wast` as the visible test surface. The later `0212` note corrected that source-story mistake; this capture closes the remaining immutable raw-manifest and local-status-bridge gap.
- The page should keep the word "effectively" when describing closed-world dependency for the desc-cast delta: the pass itself still runs without closed-world options, but the sibling-only cast rewrite needs `typeGlobals` data.
- The reviewed sources do not place `gsi-desc-cast` in Starshine's current no-DWARF / saved-`-O4z` parity queue. Keep it documented as a public upstream sibling and local boundary-only future-port surface, not as an active preset blocker.
- A future implementation review should re-check current Binaryen `main` because this capture intentionally spot-checked the owner, registration, and lit surfaces rather than every shared GSI helper.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` lists `global-struct-inference-desc-cast` in `pass_registry_boundary_only_names()`.
- `run_hot_pipeline_expand_passes(...)` in `src/passes/optimize.mbt` rejects boundary-only names with a not-implemented-in-hot-pipeline message.
- `src/cmd/fuzz_harness_wbtest.mbt` uses `global-struct-inference-desc-cast` as a generic boundary-only optimize-failure probe, so the local test surface proves request rejection, not pass behavior.
- `src/passes/pass_manager.mbt` dispatches active `global-struct-inference` but has no `global-struct-inference-desc-cast` dispatch case.
- `src/passes/global_struct_inference.mbt` implements only the narrower Starshine plain-GSI direct-global `struct.get*` fold. It has no `ref.cast_desc_eq` synthesis, no `typeGlobals` map, no subtype legality table, and no descriptor-singleton cast rewrite.
- Starshine already models prerequisite instruction and syntax surfaces: `RefCastDescEq` in `src/lib/types.mbt`, WAT parsing/lowering for `ref.cast_desc_eq`, binary encode/decode for the GC opcode pair, and validator stack effects. Those are enabling infrastructure, not a pass implementation.
- No dedicated `src/passes/global_struct_inference_desc_cast*.mbt` owner file, preset slot, pass-manager case, or active `agent-todo.md` backlog slice was found in the 2026-04-24 local recheck.
