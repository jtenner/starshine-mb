---
kind: entity
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-analysis-and-unnesting.md
  - ./starshine-strategy.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../global-refining/index.md
  - ../ssa-nomerge/index.md
---

# `global-struct-inference`

## Role

- `global-struct-inference` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is basically:
  - globally optimize struct values

That description is true, but very underspecified.

A better beginner summary is:

- Binaryen can optimize some reads directly from immutable globals **even in open world**,
- can do stronger origin reasoning in closed world by mapping struct types to the immutable globals that create them,
- can rewrite a read to a known global origin, a constant value, or a single `ref.eq`-guarded `select`,
- can un-nest non-constant field operands into fresh immutable globals when that preserves the proof,
- and refinalizes when the rewrite makes types more precise.

So this is **not** generic whole-program struct analysis and **not** just Starshine's current direct-global constant folder.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `global-struct-inference` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` scheduler it sits in the early GC/module cluster:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`
- That placement is meaningful:
  - `global-refining` tightens global declarations first
  - the second `remove-unused-module-elements` can then discard newly dead baggage
  - `gsi` turns the surviving global-instance story into more precise field reads before the function-pass cluster starts
- The 2026-06-03 `[O4Z-AUDIT-GSI]` slice upgraded and signed off the direct-global subset, then moved the remaining full-Binaryen surfaces to follow-up scope; follow-ups added a subtype-aware closed-world candidate/poison fact table, consume a narrow exact-type single-candidate subset for local/param origin rewrites, fold exact and subtype-propagated local/param reads when every safe candidate yields the same materializable value, and synthesize exact or subtype-propagated two-value singleton-group `select(ref.eq(...))` rewrites.
- In the saved generated-artifact `-O4z` audit, slot `7` (`gsi`) was already green before the O4z audit upgrade, and the 2026-06-03 direct-pass audit refreshed that evidence after enabling the open-world direct-global layer:
  - exact wasm equal: `yes`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `410.401 ms`
  - Binaryen wall/runtime: `197.827 ms`
  - old saved-audit Starshine/Binaryen in-pass time: `0.002 ms` / `2.008 ms`
  - 2026-06-03 debug-artifact timing after the upgrade: Starshine/Binaryen pass-local `0.349 ms` / `2.815 ms`
- The 2026-06-03 O4z audit direct revalidation is also green after the open-world upgrade: 9975 / 10000 compared cases, 9975 normalized matches, 0 semantic mismatches, and 25 Binaryen/tool command failures (`22` empty-recursion-group, plus one each bad-section-size, table-index-out-of-range, and invalid-tag-index).
- The subtype-propagated closed-world facts follow-up direct compare stayed green at 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and 25 Binaryen/tool command failures; the debug-artifact timing replay was canonical-equal with Starshine/Binaryen pass-local `0.345 ms` / `2.970 ms`.
- The exact single-candidate local/param follow-up direct compare stayed green at 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and 25 Binaryen/tool command failures; the debug-artifact timing replay was canonical-equal with Starshine/Binaryen pass-local `0.371 ms` / `5.017 ms`.
- The one-value multi-candidate follow-up direct compare used `--jobs auto` and a prebuilt native Starshine binary, stayed green at 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and 25 Binaryen/tool command failures; the debug-artifact timing replay was canonical-equal with Starshine/Binaryen pass-local `0.440 ms` / `3.275 ms`.
- The two-value singleton-group follow-up direct compare used `--jobs auto` and a prebuilt native Starshine binary, stayed green at 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and the same 25 Binaryen/tool command failures; the debug-artifact timing replay was canonical-equal with Starshine/Binaryen pass-local `0.695 ms` / `3.087 ms`.
- The subtype-propagated parent one/two-value follow-up direct compare used `--jobs auto` and a prebuilt native Starshine binary, stayed green at 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and the same 25 Binaryen/tool command failures; the debug-artifact timing replay was canonical-equal with Starshine/Binaryen pass-local `0.376 ms` / `3.106 ms`.

## Most important durable takeaways

- Upstream `global-struct-inference` is **not closed-world-only**.
  - closed world enables the broad type-to-global candidate map
  - but the pass still has an open-world direct immutable-global fast path
- The real optimization is about **origin restriction**, not just constant folding.
  - if a read can only come from one global, Binaryen rewrites the reference to that global
  - if it can only produce one value, Binaryen can return that value directly after preserving the null trap
  - if it can produce two unique values and one is testable with a single `ref.eq`, Binaryen emits a `select`
- The profitability rule is source-backed and narrow:
  - more than two unique values => bail
  - two equal pairs => bail
  - many globals with one shared value => fine
- Non-constant nested operands can still optimize.
  - Binaryen can un-nest them into fresh immutable globals and then continue the rewrite
- The pass is more than just `struct.get`.
  - the same source handles `ref.get_desc`
  - and the sibling `gsi-desc-cast` variant can rewrite some `ref.cast` checks to descriptor-equality casts
- Atomic gets are **not automatically excluded**.
  - if the field is immutable, Binaryen treats atomic reads as safe to optimize because there are no writes to synchronize with
- A focused 2026-05-06 current-main recheck found **no teaching-relevant post-`version_129` drift** in the reviewed owner, registration, helper, and dedicated-lit surfaces.

## Biggest beginner correction

The easy wrong mental model is:

- Binaryen tracks the contents of every struct type globally and infers field values wherever possible

The safer mental model is:

- Binaryen only reasons about a narrow family of objects whose origins are provably tied to immutable globals,
- rejects many cases where allocation happens in functions or nested global positions,
- only emits very small replacement programs (known-global, known-value, or one-compare select),
- and relies on later passes plus refinalization to clean up the rest.

That is why the pass is much narrower than the name sounds, but also much richer than the current local MoonBit subset.

## What the pass sounds like versus what it actually does

What it sounds like:

- infer struct field values globally

What it actually is in `version_129`:

- a GC-gated module pass,
- an optional closed-world type-to-global analysis,
- an always-on function walker for direct immutable-global and candidate-global reads,
- a tiny grouping algorithm over at most two unique read values,
- an un-nesting mechanism for non-constant nested operands,
- and a typed-AST repair step when replacements become more precise.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `GlobalStructInference.cpp` structure, helper dependencies, scheduler placement, open-world versus closed-world layers, and the actual algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, and Starshine code-map page, including the exact local line-number surfaces and the current local-vs-Binaryen matrix.
- [`./closed-world-analysis-and-unnesting.md`](./closed-world-analysis-and-unnesting.md)
  - Focused guide to the hardest parts to misunderstand: the type-global map, subtype poisoning and upward propagation, the one-vs-two-unique-values rule, un-nesting into fresh globals, and the nearby descriptor-facing helper surface.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering open-world direct-global positives, one-global and two-value closed-world positives, subtype and anyref bailouts, un-nesting, packed and atomic gets, null-refinement, and the main non-goals.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: the open-world direct-global subset, the exact MoonBit code locations, and the concrete gaps from upstream Binaryen's broader closed-world origin-analysis pass.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current Starshine module-pass implementation detail: the direct-global subset, rewrite shape, and the code-map-backed gap list.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, the green saved generated-artifact evidence, and the honest remaining gaps between the local MoonBit pass and the full official Binaryen contract.

## Freshness note

A focused 2026-05-06 current-main recheck found **no teaching-relevant post-`version_129` drift** in the owning official surfaces used for this dossier.

- current `main` still shows the same `run` mode split, open-world optimizer call, closed-world `typeGlobals` gate, un-nesting repair, and plain/sibling factory split
- current `main` `test/lit/passes/gsi.wast` remains the relevant dedicated plain-pass proof surface in the reviewed source bridge

So the durable rule is:

- treat Binaryen `version_129` as the released oracle for this dossier
- keep the current-main note explicit only to say there is no visible source or dedicated-lit semantic drift right now

## Current maintenance rule

- Treat this folder as the canonical home for future `global-struct-inference` parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `global-struct-inference` is layered open-world direct-global optimization plus closed-world candidate-global reasoning, not just a closed-world constant folder
- Keep the one-vs-two-unique-values rule, the subtype poisoning rule, the un-nesting mechanism, the atomic-get caveat, and the descriptor-facing sibling surface explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md)
- [`../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md`](../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md`](../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md)
- [`../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md`](../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md)
- [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
