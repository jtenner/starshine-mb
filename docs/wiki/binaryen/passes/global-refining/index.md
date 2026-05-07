---
kind: entity
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md
  - ../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalRefining.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/public-type-validator.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-refining.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalRefining.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-refining.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./exports-public-types-and-retagging.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../once-reduction/index.md
  - ../global-struct-inference/index.md
---

# `global-refining`

## Role

- `global-refining` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is basically:
  - refine the types of globals

That description is accurate, but too vague.

A better beginner summary is:

- Binaryen scans every defined function for `global.set`s,
- combines the initializer type plus every assigned value type for each global,
- computes a least upper bound,
- refuses imported or boundary-dangerous exported cases,
- rewrites the global declaration if the result is a stricter subtype,
- and then retags `global.get` users so the module remains type-correct.

So this is **not** global constant propagation and not control-flow-sensitive global analysis.
It is a small whole-module **global declaration tightening** pass.

## Why this pass matters

- The existing dossier was already useful, but this follow-up matters because `global-refining` still lacked a dedicated Starshine strategy/code-map page, which made it too easy to describe the current local subset only indirectly from the parity notes instead of from exact MoonBit owner files and pass wiring.
- In the canonical no-DWARF `-O` / `-Os` scheduler it sits in the early module GC cluster:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`
- That placement is meaningful:
  - `once-reduction` can simplify run-once scaffolding first
  - `global-refining` then tightens defined global reference types based on surviving observed writes while preserving mutable export boundaries
  - the next `remove-unused-module-elements` and later `gsi` see a cleaner, more precise module
- `agent-todo.md` still has **no dedicated `GR` slice** today.
  - The live repo intent is only indirect through the canonical ordered-path notes and the shared `DFE -> RUME -> MP -> OR -> GR -> GSI` replay context.
- In the saved generated-artifact `-O4z` audit, slot `5` (`global-refining`) was already green:
  - exact wasm equal: `yes`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `403.297 ms`
  - Binaryen wall/runtime: `198.980 ms`
  - Starshine in-pass time: `0.611 ms`
  - Binaryen in-pass time: `2.100 ms`

## Most important durable takeaways

- Upstream `global-refining` is a **small LUB-based type-tightening pass**, not a global dataflow optimizer.
- The pass is intentionally **flow-insensitive**:
  - control-flow shape, dominance, and liveness do not matter here
  - every observed `global.set` value type counts toward the global's candidate type
- The real subtlety is the **boundary matrix**, not the scan algorithm:
  - imported globals are never refined
  - open-world exported mutable globals are not refined
  - open-world exported immutable globals may still refine, but only to a valid public type
  - current official `version_129` closed-world behavior still skips **all** exported globals here
- The actual upstream Binaryen rewrite surface is tiny:
  - change the declared global type
  - update `global.get` result types
  - refinalize changed code
- The current local Starshine pass is narrower:
  - it refines defined reference globals, but still skips exported mutable ones
  - it does not yet model Binaryen's explicit public-type validation or closed-world exported-global conservatism
  - it collects writes through HOT lifting only for functions that mention candidate globals
  - and it rewrites declarations without Binaryen-style post-pass `global.get` retagging because the local representation does not use the same cached expression-type model here
- The pass does **not** remove `global.set`s, replace `global.get`s with constants, or run `gsi`-style field-value inference.
- A narrow 2026-04-21 source comparison found **no semantic post-`version_129` drift** in the owning pass file or the dedicated lit file.

## Biggest beginner correction

The easy wrong mental model is:

- Binaryen watches how globals flow through the program and infers a best type from control-flow and use patterns

The safer mental model is:

- Binaryen mostly looks at the declared initializer and the types of values assigned by `global.set`
- then computes a least upper bound that still covers all of them
- then asks whether changing the declaration is legal at module boundaries
- and finally repairs cached `global.get` result types

That is why the pass is much smaller than it sounds.

## What the pass sounds like versus what it actually does

What it sounds like:

- refine globals based on global usage

What it actually is in `version_129`:

- a GC-gated early module pass,
- a parallel `global.set` collector,
- a tiny `LUBFinder` aggregation loop,
- an export/open-vs-closed-world legality filter,
- and a `global.get` retag plus `ReFinalize` repair step.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `GlobalRefining.cpp` structure, helper dependencies, scheduler placement, and the exact algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner-file and lit-test map for `global-refining`, including the tiny `GlobalRefining.cpp` / `lubs.h` / `public-type-validator.h` ownership split and what the dedicated `global-refining.wast` file directly proves.
- [`./exports-public-types-and-retagging.md`](./exports-public-types-and-retagging.md)
  - Focused guide to the easiest part to misunderstand: imported vs exported globals, open-world vs closed-world rules, public-type validity, and why Binaryen must retag `global.get` users after a declaration change.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering init-only null and `ref.func` positives, exactness/nullability outcomes, heterogeneous `anyref`-to-`eqref` joins, exported/imported bailouts, and the main non-goals.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy: immutable-export-aware candidate selection, HOT-assisted `global.set` collection, Binaryen-style bottom-null tightening, declaration rewrite, and the remaining differences from upstream Binaryen's public-type / closed-world / retagging contract.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, the green saved generated-artifact evidence, and the honest remaining gaps between the local MoonBit pass and the full official Binaryen boundary matrix.

## Freshness note

A narrow 2026-04-21 direct source comparison found **no semantic post-`version_129` drift** in the owning official surfaces used for this dossier.

- `src/passes/GlobalRefining.cpp` is identical on current `main` and `version_129`
- `test/lit/passes/global-refining.wast` is also identical on current `main` and `version_129`

So the durable rule is:

- treat Binaryen `version_129` as the released oracle for this dossier
- keep the current-main note explicit only to say there is no visible source or dedicated-lit drift right now

## Current maintenance rule

- Treat this folder as the canonical home for future `global-refining` parity and scheduler research.
- Treat `implementation-structure-and-tests.md` as the compact owner/test-map page for future follow-ups so the file/test surface stays source-confirmed instead of getting re-inferred from broad prose.
- Keep the main beginner correction explicit:
  - upstream `global-refining` is a declaration-tightening plus retagging pass, not a broad control-flow-sensitive global optimizer
- Keep the exported immutable open-world case, the closed-world exported-global conservatism, the `PublicTypeValidator` rule, the Starshine-local mutable-export-preserving subset page, and the `global.get` retagging contract explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md`](../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md)
- [`../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md`](../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md)
- [`../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md`](../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md)
- [`../../../../../src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt)
- [`../../../../../src/passes/global_refining_test.mbt`](../../../../../src/passes/global_refining_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalRefining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/public-type-validator.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-refining.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalRefining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-refining.wast>
