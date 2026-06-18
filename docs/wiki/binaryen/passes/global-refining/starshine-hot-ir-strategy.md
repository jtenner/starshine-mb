---
kind: concept
status: supported
last_reviewed: 2026-06-18
sources:
  - ../../../raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
  - ../../../../../src/validate/typecheck.mbt
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

- **the pass currently refines defined reference globals, preserves exported mutable boundaries, filters open-world immutable exports through a local public-type check, and skips exported globals in closed world**

That is closer to official Binaryen `version_130` than the earlier private-only subset. Starshine still differs architecturally because it uses local boundary/HOT types and does not need Binaryen's cached-`global.get` retagging step today.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/global_refining.mbt:2`
  - summary string used by the registry and preset docs
- `src/passes/global_refining.mbt:131`
  - `gr_expr_result_type(...)`: initializer result typing via the validator expression typechecker, with a direct `ref.null` bottom-reference special case
- `src/passes/global_refining.mbt:139`
  - local public-type helper family: rejects exact exported refinements and recursively checks referenced type bodies
- `src/passes/global_refining.mbt:488`
  - `gr_join_reftypes(...)`: local join over heap type, nullability, and exactness
- `src/passes/global_refining.mbt:533`
  - `gr_scan_candidate_sets(...)`: cheap instruction pre-scan before HOT lifting
- `src/passes/global_refining.mbt:570`
  - `gr_collect_func_global_sets(...)`: HOT-side `global.set` value collection
- `src/passes/global_refining.mbt:760`
  - `global_refining_run_module_pass(...)`: exported-global filtering, initializer seeding, per-function collection, public export guard, and declaration rewrite
- `src/validate/typecheck.mbt:1891`
  - `typecheck_ref_func(...)`: gives concrete `ref.func` results exact heap refs when a type index is available
- `src/validate/typecheck.mbt:2744`
  - `extern.convert_any` / `any.convert_extern` instruction typing preserves operand nullability, which lets initializer expression typing expose non-null conversion results
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

## 1. Candidate discovery is declaration-driven, export-conservative, and closed-world-aware

`global_refining_run_module_pass(...)` first builds a validation environment and computes:

- imported-global count
- exported-global bitmap
- candidate slots for defined globals

A defined global becomes a candidate only when all of these are true:

- it is not imported
- its declared type is a reference type
- if it is exported in open world, it is immutable
- if `closed_world` is set, it is not exported at all

That means current Starshine intentionally skips:

- imported globals
- exported mutable globals
- all exported globals in closed world
- non-reference globals

So the local boundary policy now matches Binaryen's broad open-world mutable-export and closed-world exported-global split.

## 2. Initializer typing uses the local expression typechecker

`gr_expr_result_type(...)` now seeds initializer facts by typechecking the full initializer expression under the module validation environment. That mirrors Binaryen's `global->init->type` contract more closely than the previous syntax whitelist and covers nested reference-producing constant expressions such as arithmetic feeding `ref.i31`, conversions such as `extern.convert_any`, string expressions, exact struct/array aggregate constructors, and dependent `global.get` initializers according to the local validator's result type.

Direct `ref.null` initializers remain a deliberate special case. Starshine classifies them with Binaryen-style bottom reference types (`none`, `nofunc`, `noextern`, `noexn`) instead of reusing the broader declared heap kind directly. This preserves the null-bottom behavior used by the exact `ref.func` LUB fixtures and by abstract null initializer narrowing.

The 2026-06-18 `[GR-003]` compare lane confirmed that the known direct mismatches from nested `ref.i31` and `extern.convert_any(ref.i31)` initializers are gone: `.tmp/pass-fuzz-global-refining-gr003-10000` compared `7602/10000` with `7602` normalized matches and `0` mismatches; the remaining `20` failures were Binaryen/tool command failures.

## 3. The local LUB story is custom but clearly Binaryen-inspired

The local implementation does not call upstream `LUBFinder`; it reconstructs the same broad idea with local helpers:

- `gr_collect_heaptype_candidates(...)`
- `gr_join_heaptypes(...)`
- `gr_join_reftypes(...)`
- `gr_note_ref_type(...)`

The join keeps three main dimensions explicit:

- heap-type compatibility
- nullability
- exactness preservation when both sides are exact on the same precise heap type, or when an exact function/GC reference is joined with the matching nullable bottom (`nofunc` / `none`)

That gives Starshine a local “initializer plus observed writes” join rule even though the details are expressed through MoonBit validation helpers instead of Binaryen `Type::getLeastUpperBound(...)`.

## 4. Write collection is HOT-assisted and prefiltered

Instead of walking every function body directly, the local pass first uses `gr_scan_candidate_sets(...)` as a cheap instruction-tree prefilter.
If a function never writes to a candidate global, Starshine skips HOT lifting entirely.

When a function does mention a candidate global, the pass:

- lifts it with `@ir.hot_lift_func_with_context(...)`
- walks live HOT nodes
- records the value type of each candidate `GlobalSet`, with an explicit local exact-type path for direct `ref.func` writes to keep this pass aligned with Binaryen even if upstream HOT typing changes

This is the biggest architectural difference from Binaryen's tiny AST-side `FindAll<GlobalSet>` approach.
The local pass pays a HOT-lift cost only for functions that matter, then reasons from HOT node result types.

## 5. Exported immutable refinements pass through a local public-type filter

For open-world immutable exports, Starshine checks the Binaryen public-type boundary through the local feature model before rewriting the declaration.
Because the current direct-pass and preset feature model runs with custom descriptors enabled, matching the Binaryen `--all-features` oracle lane, the public-type guard accepts every exported immutable refined type locally. That includes exact reference types and referenced type bodies that mention exact refs.

The non-custom-descriptor scan remains present as the documented fallback shape: without custom descriptors, exact refs are not public and referenced function, struct, and array type bodies would need recursive exact-reference scanning. Starshine does not currently expose that feature-disabled pass mode.

## 6. The actual rewrite surface is declaration-only

After initializer seeding and HOT-side write collection, `global_refining_run_module_pass(...)` rewrites only the global declaration when all of these are true:

- a refined type was actually noted
- the refined type differs from the old one
- the refined type matches the old one as a subtype under the local validator

Then it rebuilds the global section with the narrower declaration. For refined globals with direct `ref.null ...; global.set` writes, Starshine also rewrites the immediate `ref.null` type to the refined target so the boundary validator sees the nullable bottom/exact-reference relationship that Binaryen carries through expression typing. Use [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md) as the shared checklist for global-section validation order, `GlobalIdx` carriers, exports, and name maps.

Important negative fact:

- the local pass does **not** rewrite `global.get` expressions afterward

That is a real source-backed split from Binaryen. Focused `[GR-005]` tests cover the local proof: dependent global initializers remain valid after source-global refinement, and fresh function-body `global.get` typechecking reads the refined declaration from the validation environment. The local representation currently avoids the Binaryen need for a separate `GetUpdater` plus `ReFinalize` pass because it is not carrying the same cached expression-result-type obligations on this path.

## 7. Current tests prove a narrow but clear contract

The focused local tests lock these main families:

- private global narrowing from a declared supertype to a child write type
- exported immutable refinement
- exported mutable bailout
- closed-world exported-global bailout
- abstract `ref.null` bottom-type tightening
- exact `ref.func`, nested `ref.i31`, conversion, exact struct/array constructor initializer facts, including nullable-bottom exact joins for function refs
- exported exact/private initializer refinement under the local all-features/custom-descriptors public-type model
- sibling-write join at the shared declared supertype
- direct `-O4z` option slot execution

That is a much better local floor for the current implementation. The direct audit is closed for ordinary `global-refining`; future work should reopen only if Starshine adds feature-disabled pass modes or typed caches that need a local `global.get` repair equivalent.

## Feature-model note: GC is assumed enabled locally

Binaryen `version_130` has two GC gates for this pass: `GlobalRefining::run` returns when `module->features.hasGC()` is false, and the default prepass scheduler adds `global-refining` only for GC-enabled modules at optimize level 2 or higher.

Starshine does not expose a Binaryen-style per-module no-GC feature bit to passes. This repo targets Wasm 3.0 / `wasm-gc`, and direct-pass plus preset execution assumes GC is enabled. Therefore adding a local `hasGC() == false` bailout would model an unavailable execution mode rather than an observable Starshine direct-pass behavior. Reopen this only if Starshine gains feature-disabled pass execution or a compare lane intentionally runs Binaryen without GC enabled.

## What the local pass does not do

Compared with upstream Binaryen `version_130`, Starshine currently does **not** do these `global-refining` behaviors here:

- broad AST-side `FindAll<GlobalSet>` collection; Starshine now recognizes direct HOT `ref.func` writes as exact for the local collection path, but the traversal strategy remains different
- feature-disabled non-custom-descriptor public-type validation mode; Starshine currently matches the Binaryen `--all-features` custom-descriptor lane for direct pass execution
- explicit `global.get` retagging after declaration rewrites
- `runOnModuleCode(...)` repair of dependent global initializers
- `ReFinalize` after changed `global.get` users

The local pass now does implement the formerly missing public-boundary filter and closed-world exported-global distinction. The explicit Binaryen GC gate is not implemented because it is unobservable under Starshine's current Wasm 3.0 / `wasm-gc` feature model.

Those are real capability and representation differences, not just documentation wording differences.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `global-refining` is a boundary-sensitive declaration-tightening pass with export/public-type logic and mandatory `global.get` repair
- local Starshine `global-refining` is currently a **defined-global declaration-tightening subset with mutable-export preservation, closed-world export bailout, and local public-type filtering**

That narrower local strategy is still useful, and it is already green on the saved generated-artifact slot documented in `parity.md`.
But it should not be described as if it were the entire official Binaryen pass.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree module pass
- a conservative defined-global subset of Binaryen `global-refining`
- a HOT-assisted declaration-tightener whose correctness currently depends on the local IR not needing Binaryen-style post-rewrite `global.get` retagging

Future work on this pass should answer one question explicitly:

- are we preserving the current boundary-aware declaration-tightening subset,
- or are we expanding toward broader Binaryen retagging/refinalization behavior because a future local IR starts caching expression result types?

For `global-refining`, those are meaningfully different projects.
