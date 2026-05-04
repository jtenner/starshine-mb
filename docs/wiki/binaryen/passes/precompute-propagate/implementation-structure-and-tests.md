---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
---

# `precompute-propagate`: implementation structure and tests

This page is the file-and-test map for Binaryen `version_129` `precompute-propagate`. The committed tagged-source manifest for the reviewed official URLs is [`../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md), the 2026-04-25 current-main/code-map refresh is [`../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md), and the 2026-05-04 current-main freshness recheck is [`../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md).

## Core source files

### `src/passes/Precompute.cpp`

This is the real implementation for **both** public names:

- `precompute`
- `precompute-propagate`

For the chosen pass, the most important durable facts visible in the reviewed file are:

- the family is built on `PrecomputingExpressionRunner`, which subclasses `ConstantExpressionRunner`
- the pass does bottom-up speculative compile-time evaluation rather than only syntax matching
- `precompute-propagate` enables a real extra propagation phase after the ordinary walk
- that phase uses local-flow information and then reruns the main walk once
- propagated sets are analyzed through `Properties::getFallthrough(...)`
- propagated gets require all reaching sets to agree on one concrete literal tuple
- function-entry values are treated differently for params, defaultable vars, and nondefaultable vars
- the same child-retention, emitability, GC-identity, and refinalization rules still apply

### `src/passes/pass.cpp`

This file matters because it proves:

- `precompute-propagate` is a public upstream pass name in `version_129`
- the public description explicitly says the variant propagates through locals
- the top-level higher-aggression scheduler uses `precompute-propagate` in the early and late propagation slots where lower-aggression no-DWARF `-O` / `-Os` uses plain `precompute`
- the public split from plain `precompute` is intentional and user-visible

### `src/passes/opt-utils.h`

This file matters because it proves the nested scheduler meaning of the pass:

- `optimizeAfterInlining(...)` prepends `precompute-propagate`
- that helper then reruns the default function optimization pipeline on changed functions

Without this file, it would be easy to document the pass as only an aggressive top-level variant and miss the nested-rerun contract.

### `src/ir/local-graph.h`

This is the key helper dependency for the chosen variant.

It matters because it explains the real meaning of “propagate through locals”:

- the pass is not inventing generic propagation from scratch inside `Precompute.cpp`
- it relies on the existing get/set influence graph machinery
- the extra phase is a local worklist over set-to-get and get-to-set influences, not a broad new CFG solver

### `src/wasm-interpreter.h`

This file matters because the pass family's semantic model comes from `ConstantExpressionRunner` and `Flow`.

That is what makes `precompute-propagate` more than a bag of peepholes.

## Official tests and what they prove

### `test/lit/passes/precompute-propagate-partial.wast`

This is the most useful propagate-specific bug-boundary file.

It proves that the propagate variant has a real extra public surface, especially around:

- local-carried constant facts
- partial `select` precompute that becomes possible after propagation
- temporary heap-value-cache isolation during speculative arm evaluation
- concrete parent expressions that only collapse once the second pass sees more local facts

### `test/lit/passes/precompute-propagate_all-features.wast`

This is the clearest broad behavior oracle for the local worklist itself.

It proves the real contract for families like:

- direct local-carried arithmetic folding
- identical-constant merge consensus after `if` joins
- zero/default entry-value participation for defaultable locals
- propagation through `local.tee` / fallthrough carriers
- chained get-to-set and set-to-get propagation
- tuple-local propagation
- loop, mismatch, and unknown-input bailout families

Without this file it is too easy to summarize the phase as vaguely “more constant propagation through locals.”

## Neighboring `precompute*` tests still matter

Even though there are dedicated propagate files, the neighboring `precompute` tests still define much of the chosen pass contract because the core evaluator is shared.

Important examples include the already-cited lit files for:

- effects and child-retention behavior
- partial precompute without propagation
- GC and immutable-heap cases
- GC atomic boundaries
- strings
- `ref.func`
- relaxed SIMD
- stack switching

Those tests matter here because the propagate variant is not allowed to violate the shared family contract while gaining the extra local phase.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/Precompute.cpp` | Core algorithm | `precompute-propagate` is shared-core semantic precompute plus a bounded local worklist and one extra rerun |
| `src/passes/pass.cpp` | Public registration and top-level scheduling | The propagate variant is a real public pass, not a hidden mode, and higher-aggression top-level paths really use it |
| `src/passes/opt-utils.h` | Nested scheduler contract | Post-inlining cleanup prepends `precompute-propagate` |
| `src/ir/local-graph.h` | Helper dependency | The extra phase is grounded in existing get/set influence analysis |
| `src/wasm-interpreter.h` | Semantic engine | The pass family is built on bounded compile-time execution and `Flow` reasoning |
| `test/lit/passes/precompute-propagate-partial.wast` | Bug-boundary oracle | The propagate variant changes real reachable rewrites and needs temporary heap-cache isolation during partial precompute |
| `test/lit/passes/precompute-propagate_all-features.wast` | Behavioral oracle | The exact get/set consensus, fallthrough, join, zero-init, tee, and bailout surfaces are source-backed |
| neighboring `precompute*` lit files | Shared-family oracle | Emitability, effects, GC identity, and other family boundaries still apply in propagate mode |

## Current-main recheck result

The 2026-05-04 primary-source recheck found no teaching-relevant drift in the current `main` surfaces that matter for this pass: `Precompute.cpp`, `pass.cpp`, `opt-utils.h`, `local-graph.h`, `properties.h`, `wasm-interpreter.h`, and the two dedicated propagate lit files still support the same contract described here. Keep `version_129` as the tagged oracle, but cite the 2026-05-04 manifest when readers need the freshest official source and exact local Starshine bridge anchors.

## What this source map says about the real contract

The source map prevents two common teaching mistakes.

### Mistake 1: treating the chosen pass as too small

If you only look at the CLI name, the pass can sound like “constant propagation through locals.”

The source map shows it is really:

- the full semantic `precompute` family contract
- plus one extra local-propagation phase
- plus scheduler importance in aggressive top-level and nested optimizing reruns

### Mistake 2: treating the chosen pass as too broad

If you focus only on the word “propagate,” the pass can sound like a generic CFG-wide dataflow engine.

The source map shows the extra phase is still narrow and helper-driven.
It feeds more facts into the same evaluator rather than turning into a different optimizer entirely.

## Porting takeaway

If Starshine ever ports this pass, the source/test map suggests a clean design target:

1. keep the shared evaluator core aligned with plain `precompute`
2. add a dedicated local-propagation phase using the local-flow helper layer
3. preserve the exact fallthrough and merge-consensus rules from `propagateLocals(...)`
4. rerun the main evaluator once when propagation changed facts
5. preserve the existing write-retention, emitability, and GC-identity rules
6. test both the standalone pass surface and the nested `optimizeAfterInlining(...)` scheduler role

## Starshine status pointer

Current Starshine keeps this pass as a removed registry name and implements only the narrower active plain `precompute` pass today. See [`./starshine-strategy.md`](./starshine-strategy.md) for the exact MoonBit code map and missing local-flow / nested-rerun surfaces.

## Recommended local teaching rule

When this pass is cited elsewhere in the wiki:

- link here for the public-variant and scheduler story
- link to [`./local-worklist-fallthrough-and-merge-boundaries.md`](./local-worklist-fallthrough-and-merge-boundaries.md) for the exact propagation mechanics
- link to [`../precompute/index.md`](../precompute/index.md) for the broader family contract
- avoid describing the pass as either a mere alias or a generic propagation engine
