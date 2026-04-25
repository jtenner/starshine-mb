---
kind: source-capture
status: supported
last_reviewed: 2026-04-25
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast
related:
  - ../research/0068-2026-03-25-global-struct-inference.md
  - ../research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
  - ../research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/global-struct-inference/implementation-structure-and-tests.md
---

# Binaryen `global-struct-inference` primary-source capture

Captured: 2026-04-25

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GlobalStructInference.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - Key reviewed locations: the file-level pass rationale, `GlobalStructInference(bool optimizeToDescCasts)`, `requiresNonNullableLocalFixups()`, `run(Module*)`, `analyzeClosedWorld(Module*)`, `FunctionOptimizer`, `readFromStructNew(...)`, `getReadValue(...)`, `visitStructGet(...)`, `visitRefGetDesc(...)`, `visitRefCast(...)`, un-nesting work items, nested `reorder-globals-always`, and the public factories `createGlobalStructInferencePass()` / `createGlobalStructInferenceDescCastPass()`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed locations: public pass registration for `gsi` and `gsi-desc-cast`, plus global-prepass scheduler placement around `global-refining`, `remove-unused-module-elements`, and neighboring closed-world GC/type passes.
- `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Key reviewed locations: pass factory declarations for the plain and descriptor-cast siblings.
- Helper headers:
  - `src/ir/possible-constant.h`: literal and immutable-`global.get` value classification used when grouping candidate field values.
  - `src/ir/subtypes.h`: subtype and supertype traversal used for closed-world poisoning, candidate propagation, and desc-cast legality.
  - `src/ir/bits.h`: packed-field materialization helper surface.
  - `src/ir/module-utils.h`: parallel function-analysis helper used to collect function-local `struct.new` poison sources.
  - `src/ir/names.h`: fresh immutable-global name generation for un-nesting.
  - `src/passes/ReorderGlobals.cpp`: `reorder-globals-always`, which the GSI pass runs as a nested repair when un-nesting inserts globals.
- `test/lit/passes/gsi.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
  - Key reviewed families: immutable/mutable field gates, direct global reads, one-global reference rewrites, one-value and two-value grouped rewrites, unique-value bailouts, subtype poisoning and propagation, non-constant un-nesting, immutable-`global.get` field values, packed-field repair, atomic gets, broad `eqref` versus `anyref` declaration boundaries, bottom/no-crash coverage, and null-result refinalization.

## Durable facts captured

- Binaryen exposes the public pass name `gsi` for plain `global-struct-inference`; Starshine exposes the longer local name `global-struct-inference`.
- The plain pass and the sibling `gsi-desc-cast` share `GlobalStructInference.cpp`. The plain factory constructs `GlobalStructInference(false)`; the descriptor-cast sibling constructs `GlobalStructInference(true)`.
- `requiresNonNullableLocalFixups()` returns false in the source owner. The pass repairs changed expression types through function refinalization rather than through the pass-runner non-nullable-local fixup path.
- `run(Module*)` has a hard GC feature gate. In closed world it builds the `typeGlobals` map with `analyzeClosedWorld(module)`, but it still runs `optimize(module)` afterward in all modes.
- The open-world direct-global layer is real: reads from immutable globals initialized by `struct.new` can optimize even when closed-world type inference is absent.
- Closed-world analysis has two negative sources: function-local `struct.new` and nested non-top-level `struct.new` in global initializers poison the relevant heap types.
- Mutable globals are not trusted as candidate origins, and a global's declared type must be equality-comparable enough for the pass's `ref.eq` strategy.
- Subtype reasoning runs both directions in effect: unoptimizable children poison supertypes, while candidate child globals propagate upward so parent-typed reads can still optimize when the candidate/value set stays small.
- Candidate grouping is based on possible read values, not merely on the number of candidate globals. One unique value can fold directly; two unique values can synthesize a single `ref.eq`-guarded `select` only when one value group is singleton; larger or symmetric groups bail.
- `PossibleConstantValues` is part of the contract because immutable `global.get` operands can be materialized as stable values, while arbitrary equal-looking expression trees are not treated as semantically equal here.
- Packed fields are repaired through Binaryen's bit helper surface so signedness and truncation/extension match the original read.
- Atomic gets can still optimize when the field is immutable; the pass relies on field immutability rather than treating the atomic opcode as a universal barrier.
- Non-constant field or descriptor operands can participate through un-nesting: the pass records work during function optimization, adds fresh immutable globals afterward, rewrites the original `struct.new` operands to `global.get`s, retargets placeholders, and runs nested `reorder-globals-always`.
- Plain `gsi` also visits `ref.get_desc`; `gsi-desc-cast` is the sibling-only cast rewrite, not the canonical no-DWARF plain-GSI slot.
- `gsi.wast` is a broad direct proof surface for the plain pass. It is not just a smoke test for one direct-global constant-fold shape.

## Current-`main` drift note

A 2026-04-25 spot check of current `main` on the reviewed `run`, `analyzeClosedWorld`, un-nesting, factory, and dedicated `gsi.wast` surfaces did not surface a teaching-relevant contract change from the `version_129` story captured here. The current `main` owner still shows the same open-world comment, closed-world `typeGlobals` gate, `optimize(module)` call after optional closed-world analysis, un-nesting plus nested `reorder-globals-always`, and plain/sibling factory split.

This is a focused source bridge, not a full semantic diff of all Binaryen trunk changes after `version_129`.

## Uncertainty and contradiction notes

- Older local notes summarized Starshine's implementation accurately as closed-world-only, but that statement must not be generalized to Binaryen. Binaryen's source keeps the open-world direct-global optimization layer alive.
- The local saved-artifact parity evidence remains useful but narrow. It shows the current Starshine subset was enough for that artifact's `gsi` slot; it does not prove coverage of Binaryen's local/param, subtype, select, un-nesting, atomic, or descriptor shapes.
- `gsi-desc-cast` shares the owner file and infrastructure, but it is a separate public pass. Plain `gsi` documentation should mention the shared descriptor surfaces without implying that Starshine's active plain pass implements the descriptor-cast sibling.
- Current-main drift should be rechecked before future implementation work because this capture only spot-checked the primary owner, registration, helper, and lit surfaces that matter for the dossier.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` registers `global-struct-inference` as an active module pass and places it in the local `optimize` / `shrink` presets after `global-refining`.
- `src/passes/pass_manager.mbt` dispatches the pass through `global_struct_inference_run_module_pass(mod_, options.closed_world)`.
- `src/passes/global_struct_inference.mbt` remains a closed-world-only direct-global subset. It scans immutable defined globals with top-level `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` initializers; materializes only simple values; rewrites immediate `global.get` + `struct.get*` instruction pairs; preserves nullable-global traps with `ref.as_non_null` + `drop`; and rebuilds changed functions only.
- `src/passes/global_struct_inference_test.mbt` currently proves the closed-world gate and the direct-global / non-global-producer split, not the full Binaryen `gsi.wast` surface.
- No Starshine code path currently implements Binaryen's open-world direct-global layer, `typeGlobals` map, subtype poisoning/propagation, local/param-origin rewrite, `select(ref.eq(...))` synthesis, un-nesting into fresh globals, `ref.get_desc`, atomic-get-specific proof cases, or `gsi-desc-cast` rewriting.
