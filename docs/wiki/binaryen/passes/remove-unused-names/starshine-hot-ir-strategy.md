---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0703-2026-06-03-remove-unused-names-o4z-audit.md
  - ../../../raw/research/0517-2026-05-06-remove-unused-names-direct-revalidation.md
  - ../../../raw/research/0235-2026-04-21-remove-unused-names-starshine-strategy-followup.md
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - ../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md
  - ../../../../../src/passes/remove_unused_names.mbt
  - ../../../../../src/passes/remove_unused_names_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./control-names-implicit-blocks-and-delegates.md
  - ./wat-shapes.md
  - ./invalid-tag-index-parser-gap.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `remove-unused-names` HOT-IR strategy

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `RemoveUnusedNames.cpp` contract.

## Current local surface

Starshine exposes `remove-unused-names` as an active hot pass with:

- descriptor name: `remove-unused-names`
- summary text: `Peel redundant same-typed block wrappers and demote loops whose labels have no remaining continue targets.`
- no required HOT analyses
- broad invalidation after mutation:
  - CFG
  - dominance
  - liveness
  - use-def
  - effects
  - loop info
  - SSA

The 2026-06-03 O4z audit keeps this active direct-pass surface current: `.tmp/pass-fuzz-remove-unused-names-audit-10000` recorded 9975 compared cases, 9975 normalized matches, 0 semantic mismatches, and 25 Binaryen/canonicalization command failures under `--count 10000 --seed 0x5eed --keep-going-after-command-failures`. The command failures were parser/canonicalizer failures, not Starshine semantic mismatches.

That already makes the local pass smaller and more structural than the upstream Binaryen story.
The local contract is **not** “remove all dead control labels.”
It is specifically:

- detect loop wrappers whose labels are dead and demote them,
- detect single-child same-typed block chains whose intermediate labels are dead and peel them,
- and skip the function entirely when the raw WAT shape makes those two families impossible.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/remove_unused_names.mbt:2`
  - `remove_unused_names_descriptor()` declares the public pass name and invalidation set
- `src/passes/remove_unused_names.mbt:15`
  - `remove_unused_names_summary()` owns the registry/help text
- `src/passes/remove_unused_names.mbt:43`
  - `remove_unused_names_compute_label_used(...)` builds the label-use bitset from live HOT nodes
- `src/passes/remove_unused_names.mbt:113`
  - `remove_unused_names_peel_same_typed_blocks(...)` collects a peelable same-type block chain and surviving roots
- `src/passes/remove_unused_names.mbt:152`
  - `remove_unused_names_detach_peeled_blocks(...)` clears the detached child block bodies after the parent body is rewritten
- `src/passes/remove_unused_names.mbt:166`
  - `remove_unused_names_has_candidate(...)` runs the cheap HOT-side candidate test before the full walk
- `src/passes/remove_unused_names.mbt:203`
  - `remove_unused_names_visit_region(...)` recursively walks root lists in postorder
- `src/passes/remove_unused_names.mbt:236`
  - `remove_unused_names_demote_loop(...)` calls the HOT helper that rewrites a loop into a block wrapper
- `src/passes/remove_unused_names.mbt:241`
  - `remove_unused_names_visit_control_node(...)` applies the block-peel and loop-demotion rewrites
- `src/passes/remove_unused_names.mbt:351`
  - `remove_unused_names_run(...)` ties together candidate gating, label-use collection, recursion, and mutation marking
- `src/passes/pass_manager.mbt:7095`
  - `run_hot_pipeline_instr_has_remove_unused_names_candidate(...)` is the raw WAT pre-scan helper
- `src/passes/pass_manager.mbt:7126`
  - `run_hot_pipeline_raw_remove_unused_names(...)` skips lift/writeback when a function has no loop or nested-block candidate shape
- `src/passes/pass_manager.mbt:8693`
  - hot-pass dispatch site
- `src/passes/optimize.mbt:182`
  - registry entry wiring for the public pass name
- `src/passes/optimize.mbt:246`
  - first preset slot after `dead-code-elimination`
- `src/passes/optimize.mbt:247`
  - second preset slot after the first `remove-unused-brs`
- `src/passes/optimize.mbt:249`
  - late preset slot after `merge-blocks -> remove-unused-brs`
- `src/passes/remove_unused_names_test.mbt:14`
  - same-typed nested-block peel test
- `src/passes/remove_unused_names_test.mbt:40`
  - branch-retarget-through-peeled-blocks test
- `src/passes/remove_unused_names_test.mbt:53`
  - nested-control bailout test
- `src/passes/remove_unused_names_test.mbt:86`
  - `try_table` catch-target bailout test
- `src/passes/remove_unused_names_test.mbt:144`
  - delegate target label-use helper coverage
- `src/passes/remove_unused_names_test.mbt:164`
  - non-label name-section preservation expectation
- `src/passes/remove_unused_names_test.mbt:194`
  - stale label-name metadata drop expectation after control rewrites
- `src/passes/remove_unused_names_test.mbt:235`
  - loop-demotion test
- `src/passes/remove_unused_names_test.mbt:243`
  - live-continue-target loop bailout test

## How the local pass works today

### 1. Candidate discovery is intentionally tiny

The HOT-side fast path is much narrower than the upstream Binaryen AST pass.
The local implementation looks only for:

- any live `Loop`, or
- any live `Block` whose body has exactly one live child and that child is another `Block` with the same control-block type

If neither family exists, `remove_unused_names_run(...)` returns unchanged even before the recursive walk.
The pass manager adds an even earlier raw WAT pre-scan with the same basic idea so functions without those shapes can skip lift entirely.

That means the local pass is optimized around the only two rewrite families Starshine currently implements.
It does **not** try to model every Binaryen label-clear case first and discover later that nothing structural changed.

### 2. Label liveness is a HOT bitset, not an upstream-style name-to-user map

`remove_unused_names_compute_label_used(...)` scans live HOT nodes and marks used label ids for:

- `br`
- `br_if`
- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- `delegate`
- every `br_table` target plus default target
- every `try_table` catch target

This is the core local-vs-upstream design difference.
Upstream Binaryen keeps a `branchesSeen` map from names to exact using expressions because it rewrites generic scope-name uses directly.
Local Starshine keeps only a used/not-used bitset because the implemented rewrites need only one question:

- is any peeled or loop label still targeted?

That is cheaper, but it is also less expressive.

### 3. Same-typed block peeling works by removing dead intermediate wrappers only

`remove_unused_names_peel_same_typed_blocks(...)` starts from one block and walks down while all of these stay true:

- the current region has exactly one root
- that child root is live
- the child is another `Block`
- the child control-block type matches the original block type

It records every removable intermediate child block id in `removed_ids`, then snapshots the innermost surviving region roots into `peeled_roots`.

`remove_unused_names_visit_control_node(...)` only commits the peel when **none** of the removed block labels are still marked used.
If any removed label is still targeted, the original nesting remains intact.

On success the pass:

- rewrites the outer block body to the innermost surviving roots, and
- clears the detached peeled child bodies so the dead wrappers no longer hold nested regions alive.

This is the local equivalent of Binaryen's same-type parent/child merge story, but it is narrower in two ways:

- it peels an entire same-type chain instead of retargeting explicit parent-vs-child named blocks one at a time, and
- it refuses the rewrite based on dead-label checks rather than rewriting generic scope-name uses directly.

### 4. Loop demotion is the other implemented rewrite family

For loops, `remove_unused_names_visit_control_node(...)` asks one question after visiting the body:

- is this loop label still used?

If yes, the loop stays.
If no, `remove_unused_names_demote_loop(...)` calls `@ir.hot_control_demote_loop_to_block(...)`.

That preserves the loop body while removing the continue-target semantics.
The focused local tests cover both sides:

- a label-dead loop demotes
- a loop with a surviving `br 0` stays a loop

### 5. Recursion covers control bodies, not every instruction kind

The recursive walker descends through:

- `Block`
- `Loop`
- `If`
- `Try`
- `TryTable`

and visits child regions before attempting the current node rewrite.
So the pass is still postorder in spirit, like upstream.
But the local visitor only has structural work to do on:

- `Block`
- `Loop`

For `If`, `Try`, and `TryTable`, recursion exists so nested block/loop candidates can still be rewritten inside those regions.
The local pass does **not** currently implement the upstream `handleBreakTarget(...)` / `visitTry(...)` style of clearing labels on every named scope.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `remove-unused-names` is a general control-label cleanup pass with explicit name-use tracking, dead-label clearing, same-type block retargeting, loop demotion, and caller-delegate sentinel cleanup
- local Starshine `remove-unused-names` is currently a **structural subset** that only peels dead-label same-typed block chains and demotes dead-label loops

Concretely, the local pass does **not** do these upstream behaviors today:

- generic control-label clearing on named `block`, `try`, or other scopes that remain structurally present
- a `branchesSeen`/exact-user map keyed by symbolic names
- generic scope-target retargeting via a `branch-utils` equivalent
- the explicit caller-delegate sentinel cleanup story from Binaryen's `DELEGATE_CALLER_TARGET`
- the broader implicit-block-oriented “clear the label now, let emission erase the wrapper later” style of rewrite

So the safe teaching headline is not “Starshine already implements `remove-unused-names`.”
It is:

- Starshine already implements the highest-value **block-peel plus loop-demotion subset** of `remove-unused-names` in HOT IR.

## Current local tests and what they prove

The focused tests in `src/passes/remove_unused_names_test.mbt` currently prove these local contracts:

- same-typed nested blocks peel into one surviving wrapper
- typed type-index block wrappers still preserve the right outer type when peeled
- branches targeting peeled parents are rebased to the surviving wrapper depth in the lowered WAT
- peeling is blocked when nested control still targets one of the intermediate scopes
- peeling is blocked when `try_table` catches still target an intermediate scope
- the shared label-use helper marks `Delegate` targets; this is helper-level coverage because the current public `@lib.Instruction` model has `TryTable` but not the legacy `try ... delegate` instruction surface
- non-label name-section metadata survives the pass, while label-name maps can be dropped after structural control rewrites because the old label map can become stale
- loops demote only when no continue target survives

That is a strong local floor for the subset Starshine actually implements.
It is narrower than upstream Binaryen's overall contract, but it is concrete and code-backed.

## O4z guard status

As of the 2026-06-03 O4z audit, direct `remove-unused-names` remains parity-clean, but actual O4z mode still guards the pass as a raw no-op. `src/passes/pass_manager.mbt` returns the original function for every `remove-unused-names` function pass when `optimize_level >= 4 && shrink_level >= 1`, with trace reason `o4z-remove-unused-names-noop`.

That guard is correctness-safe and performance-cheap, but it means O4z currently misses every same-type wrapper collapse and loop demotion this pass would otherwise perform. Treat re-enabling or narrowing that guard as a separate test-first precision-recovery task that must replay the self-opt / O4z artifact lane that originally motivated the guard.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree hot pass for direct execution,
- a deliberate HOT-IR subset of upstream Binaryen,
- a currently guarded no-op in O4z mode,
- and a pass whose direct behavior is best summarized as **same-typed block peeling plus dead-label loop demotion**.

Future work on this pass should answer one question explicitly:

- are we preserving the current local structural subset,
- are we changing the O4z raw no-op guard,
- or are we expanding toward Binaryen's fuller control-label cleanup contract?

For `remove-unused-names`, those are materially different amounts of work, and the wiki should keep that difference explicit.
