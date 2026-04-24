---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
  - ../../../raw/research/0206-2026-04-21-string-gathering-source-confirmation-followup.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# `string-gathering`: implementation structure and tests

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md).
This page is the compact source-confirmed map for how Binaryen `version_129` actually implements `string-gathering` and where the shipped tests pin that behavior down.

## Why this page exists

The folder already had a useful dossier, but it still missed one compact page answering four recurring questions in one place:

- which official files really own the pass,
- what the exact implementation phases are,
- which helpers are actually part of the contract,
- and which shipped tests prove the important positive and negative cases.

That gap mattered because `string-gathering` is easy to mis-teach as vague “string lowering prep” instead of the small late canonicalization pass Binaryen actually ships.

## Official owner files

## `src/passes/StringLowering.cpp`

This is the real owner file.
It contains both:

- the standalone `StringGathering` pass class, and
- the full `StringLowering` subclass that reuses it.

That shared-file structure is the first big practical fact to remember:

- `string-gathering` is a real public pass,
- but it also serves as the first phase of full `string-lowering`.

Inside this file, `StringGathering` owns essentially the whole pass contract:

- scanning `StringConst` sites,
- collecting exact `Expression**` slots,
- deduplicating literal payloads,
- reusing or creating defining globals,
- preserving defining initializer slots,
- validity-first global reordering,
- and final `StringConst` → `global.get` rewrites.

## `src/passes/pass.cpp`

This file proves:

- the public pass name is `string-gathering`,
- the help text is `hoists string constants into globals`,
- the pass is scheduled in the late post-pass cluster,
- and the gate is `optimizeLevel >= 2 && wasm->features.hasStrings()`.

It also contains the most important scheduler comment for this pass family:

- gather strings to globals first,
- then let `reorder-globals` sort them properly.

## `src/passes/passes.h`

This file proves the pass is a real public constructor surface, not merely a private helper hidden behind `string-lowering`.

## `src/passes/string-utils.{h,cpp}`

These files matter here for the generated-name contract.
`StringGathering` uses the shared string-lowering prefix constant and string-printing helpers to derive readable, collision-safe global names for fresh canonical defining globals.

## `src/ir/module-utils.h`

This file matters because `StringGathering` uses:

- `ModuleUtils::ParallelFunctionAnalysis<StringPtrs>`

for the defined-function scan.
That makes the function-body collection phase explicitly parallel.

## `src/wasm-traversal.h`

This file matters because `StringGathering` also walks module-level expression code through:

- `walkModuleCode(module)`

That is the source-backed reason the pass covers more than just function bodies.

## Real implementation phases in `StringLowering.cpp`

## Phase 0: scan exact `StringConst` slots, not abstract “string users”

The scan helper is a tiny `PostWalker` named `StringScanner`.
It only overrides:

- `visitStringConst(StringConst* curr)`

and records:

- `getCurrentPointer()`

That means the pass is keyed to exact mutable AST slots containing literal string constants.
It does not first build a general-purpose string-use graph.

## Phase 1: collect defined-function sites in parallel

The pass runs `StringScanner` over each defined function body via:

- `ModuleUtils::ParallelFunctionAnalysis<StringPtrs>`

Imported functions are skipped.
Each defined function contributes a vector of exact `Expression**` sites.

## Phase 2: collect module-code sites separately

After the parallel function scan, the pass also runs `StringScanner` over:

- `walkModuleCode(module)`

This is the source-backed reason `string-gathering` is broader than a function-local optimization.
It is intended to canonicalize `StringConst` sites in module expression code such as defined global initializers and other module-expression surfaces reachable through that helper.

## Phase 3: deduplicate literal payloads and sort them deterministically

Once all exact sites have been collected into `stringPtrs`, the pass also builds a deduplicated literal list `strings` keyed by the literal payload itself.
Then it sorts that literal list.

This split matters:

- `stringPtrs` keeps all exact rewrite locations,
- `strings` keeps one representative per literal for canonical-global planning.

## Phase 4: find reusable existing defining globals

The pass scans module globals and reuses one only if all of these are true:

- defined, not imported,
- immutable,
- exact non-null string type,
- direct `StringConst` initializer.

When several reusable globals match the same literal, the first one encountered in module order wins.

This phase also records the initializer slot of the chosen reusable global in:

- `stringPtrsToPreserve`

so the final rewrite does not turn the defining initializer into a self-referential `global.get`.

## Phase 5: create fresh canonical globals for literals still lacking one

For literals with no reusable defining global, the pass creates a fresh immutable `(ref string)` global whose initializer is a direct `string.const`.

The generated name is:

- based on the literal contents,
- made readable by WTF-16 → WTF-8 conversion plus escaping,
- prefixed with the shared string-global prefix,
- then made collision-safe with `Names::getValidGlobalName(...)`.

So fresh global names are intentionally readable, but the semantic identity key remains the literal payload.

## Phase 6: reorder globals only enough to preserve validity

After canonical defining globals are known, the pass performs a stable sort over globals so that:

- defining string globals appear before non-defining globals.

This is not a profitability sort.
It is a validity repair so later global initializers that now use `global.get` can refer to already-defined canonical string globals.

That is why the scheduler follows this pass immediately with `reorder-globals`.

## Phase 7: rewrite non-defining literal sites to `global.get`

Finally, the pass walks all collected `Expression**` literal sites and, unless the site is preserved as a defining initializer, replaces the `StringConst` with:

- `global.get` of the canonical global for that literal.

This explains two important boundaries:

- the pass rewrites only `StringConst` nodes,
- and it leaves preexisting `global.get` users alone.

## Important negative facts

The pass does **not** use:

- `Effects`
- CFG or dominance analyses
- a fixpoint loop
- refinalization helpers
- a nested `PassRunner` rerun
- generic string-op lowering

So a faithful Starshine port should stay small and structural.

## Shipped tests and what they prove

## `test/lit/passes/string-gathering.wast`

This is the dedicated official test file for the standalone pass.
It directly proves several important families:

- repeated function-body literals become one canonical defining global,
- an existing immutable direct `(ref string)` global can be reused,
- when several reusable globals match, the first one in module order wins,
- nullable and mutable string globals are not reused as canonical definers,
- nested global-initializer users can be rewritten to `global.get`,
- and defining globals may be moved earlier to keep rewritten global initializers valid.

The especially valuable test shapes are:

- the multi-global `foo` case proving first-match reuse,
- the nullable and mutable `bar` cases proving non-reuse,
- the nested `struct.new` global case proving module-code rewriting plus validity-first reorder.

## What the dedicated test does **not** directly prove

The lit file does not isolate dedicated positives for all of the broader `walkModuleCode(...)` surfaces, such as:

- element items,
- table initializer expressions,
- data or element offsets.

So the best source-backed teaching split is:

- global-initializer and reuse/order behavior are directly test-proven,
- broader module-code coverage is source-proven from the helper surface.

## Exact file/test ownership summary

| File | What it proves |
| --- | --- |
| `src/passes/StringLowering.cpp` | The whole real `StringGathering` algorithm: exact-slot scan, deduped literals, reusable-global detection, preserve-set handling, fresh-global creation, validity-first reorder, and final `global.get` rewrites |
| `src/passes/pass.cpp` | Public registration, strings-only optimize gate, and late scheduler placement before `reorder-globals` |
| `src/passes/passes.h` | Public constructor surface for the standalone pass |
| `src/passes/string-utils.{h,cpp}` | Shared generated-name prefix and name-building helper surface |
| `src/ir/module-utils.h` | The parallel defined-function analysis helper used during scanning |
| `src/wasm-traversal.h` | The broader module-code walk surface that explains non-function coverage |
| `test/lit/passes/string-gathering.wast` | The dedicated positive and negative reuse, alias, and global-reorder cases |

## Current-main drift check

A 2026-04-23 spot check against current Binaryen `main` found no reviewed drift on the `StringGathering` surface that changes the `version_129` contract summarized here.

So this page is not only historical tag archaeology.
It still matches the reviewed upstream implementation surface on the key behaviors covered here.
