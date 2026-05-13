---
kind: concept
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./exports-public-types-and-retagging.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `global-refining` module-pass strategy

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `GlobalRefining.cpp` contract.

## Current local surface

Starshine exposes `global-refining` as an active module pass with:

- descriptor name: `global-refining`
- summary text: `Refine defined global reference types from their initializer and observed writes, while preserving mutable export boundaries.`
- module-pass dispatch through `pass_manager.mbt`
- preset placement in the early module cluster between `once-reduction` and `global-struct-inference`

The most important immediate local rule is:

- **the pass currently refines defined reference globals, but still preserves exported mutable boundaries**

That is closer to official Binaryen `version_129` than the earlier private-only subset, but it is still narrower because Starshine does not yet model public-type validation or the closed-world exported-global distinction.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/global_refining.mbt:2`
  - summary string used by the registry and preset docs
- `src/passes/global_refining.mbt:103`
  - `gr_expr_result_type(...)`: initializer classification for `ref.null`, immutable `global.get`, and `ref.func`
- `src/passes/global_refining.mbt:284`
  - `gr_join_reftypes(...)`: local join over heap type, nullability, and exactness
- `src/passes/global_refining.mbt:332`
  - `gr_scan_candidate_sets(...)`: cheap instruction pre-scan before HOT lifting
- `src/passes/global_refining.mbt:369`
  - `gr_collect_func_global_sets(...)`: HOT-side `global.set` value collection
- `src/passes/global_refining.mbt:419`
  - `global_refining_run_module_pass(...)`: exported-global filtering, initializer seeding, per-function collection, and declaration rewrite
- `src/passes/global_refining_test.mbt:17`
  - private narrowing positive
- `src/passes/global_refining_test.mbt:46`
  - exported immutable positive
- `src/passes/global_refining_test.mbt:70`
  - exported mutable bailout
- `src/passes/global_refining_test.mbt:97`
  - abstract `ref.null` bottom-type coverage
- `src/passes/global_refining_test.mbt:160`
  - sibling-write join case
- `src/passes/pass_manager.mbt:8643`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:235`
  - registry entry
- `src/passes/optimize.mbt:245`
  - preset placement after `once-reduction`

## How the local pass works today

## 1. Candidate discovery is declaration-driven and export-conservative

`global_refining_run_module_pass(...)` first builds a validation environment and computes:

- imported-global count
- exported-global bitmap
- candidate slots for defined globals

A defined global becomes a candidate only when all of these are true:

- it is not imported
- its declared type is a reference type
- if it is exported, it is immutable

That means current Starshine intentionally skips:

- imported globals
- exported mutable globals
- non-reference globals

So the local boundary policy now matches the broad open-world mutable-export split, but it is still simpler than Binaryen's full open-vs-closed-world plus public-type matrix.

## 2. Initializer typing is tiny and syntax-driven

`gr_expr_result_type(...)` seeds the pass's initial facts from a very small initializer vocabulary:

- `ref.null`
- `global.get`
- `ref.func`

If an initializer is not recognized as one of those reference-producing forms, it simply contributes nothing to the candidate type.

One important 2026-05-07 correction is that `ref.null` is now classified using Binaryen-style bottom reference types (`none`, `nofunc`, `noextern`, `noexn`) instead of reusing the broader declared heap kind directly.

That is still smaller than Binaryen's broad AST-plus-refinalization context, but it now covers the focused nullability/type-tightening mismatch family that direct fuzz exposed.

## 3. The local LUB story is custom but clearly Binaryen-inspired

The local implementation does not call upstream `LUBFinder`; it reconstructs the same broad idea with local helpers:

- `gr_collect_heaptype_candidates(...)`
- `gr_join_heaptypes(...)`
- `gr_join_reftypes(...)`
- `gr_note_ref_type(...)`

The join keeps three main dimensions explicit:

- heap-type compatibility
- nullability
- exactness preservation only when both sides are exact and on the same precise heap type

That gives Starshine a local “initializer plus observed writes” join rule even though the details are expressed through MoonBit validation helpers instead of Binaryen `Type::getLeastUpperBound(...)`.

## 4. Write collection is HOT-assisted and prefiltered

Instead of walking every function body directly, the local pass first uses `gr_scan_candidate_sets(...)` as a cheap instruction-tree prefilter.
If a function never writes to a candidate global, Starshine skips HOT lifting entirely.

When a function does mention a candidate global, the pass:

- lifts it with `@ir.hot_lift_func_with_context(...)`
- walks live HOT nodes
- records the value type of each candidate `GlobalSet`

This is the biggest architectural difference from Binaryen's tiny AST-side `FindAll<GlobalSet>` approach.
The local pass pays a HOT-lift cost only for functions that matter, then reasons from HOT node result types.

## 5. The actual rewrite surface is declaration-only

After initializer seeding and HOT-side write collection, `global_refining_run_module_pass(...)` rewrites only the global declaration when all of these are true:

- a refined type was actually noted
- the refined type differs from the old one
- the refined type matches the old one as a subtype under the local validator

Then it rebuilds the global section with the narrower declaration. Use [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md) as the shared checklist for global-section validation order, `GlobalIdx` carriers, exports, and name maps.

Important negative fact:

- the local pass does **not** rewrite `global.get` expressions afterward

That is a real source-backed split from Binaryen. The local representation currently avoids the Binaryen need for a separate `GetUpdater` plus `ReFinalize` pass because it is not carrying the same cached expression-result-type obligations on this path.

## 6. Current tests prove a narrow but clear contract

The focused local tests lock five main families:

- private global narrowing from a declared supertype to a child write type
- exported immutable refinement
- exported mutable bailout
- abstract `ref.null` bottom-type tightening
- sibling-write join at the shared declared supertype

That is a much better local floor for the current implementation.
It is still smaller than the official `global-refining.wast` surface, which is why the parity page keeps the remaining public-type, closed-world, and Binaryen-retagging differences explicit.

## What the local pass does not do

Compared with upstream Binaryen `version_129`, Starshine currently does **not** do these `global-refining` behaviors here:

- explicit `PublicTypeValidator`-style public-boundary filtering for immutable exports
- closed-world-vs-open-world exported-global distinction
- broad AST-side `FindAll<GlobalSet>` collection
- explicit `global.get` retagging after declaration rewrites
- `runOnModuleCode(...)` repair of dependent global initializers
- `ReFinalize` after changed `global.get` users
- explicit GC feature gating at the top of the pass

Those are real capability and representation differences, not just documentation wording differences.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `global-refining` is a boundary-sensitive declaration-tightening pass with export/public-type logic and mandatory `global.get` repair
- local Starshine `global-refining` is currently a **defined-global declaration-tightening subset with mutable-export preservation**

That narrower local strategy is still useful, and it is already green on the saved generated-artifact slot documented in `parity.md`.
But it should not be described as if it were the entire official Binaryen pass.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree module pass
- a conservative defined-global subset of Binaryen `global-refining`
- a HOT-assisted declaration-tightener whose correctness currently depends on the local IR not needing Binaryen-style post-rewrite `global.get` retagging

Future work on this pass should answer one question explicitly:

- are we preserving the current mutable-export-preserving subset,
- or are we expanding toward full Binaryen public-type and closed-world behavior?

For `global-refining`, those are meaningfully different projects.
