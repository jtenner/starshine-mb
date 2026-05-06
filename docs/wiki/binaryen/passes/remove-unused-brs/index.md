---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0247-2026-04-22-remove-unused-brs-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./pattern-catalog.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-brs`

## Role

- `remove-unused-brs` is an active implemented **hot pass** in Starshine.
- The folder now also has immutable raw primary-source capture plus 2026-05-05 and 2026-05-06 current-main bridges at [`../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md`](../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md), [`../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md), and [`../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md), so the Binaryen release/source/test provenance for this dossier no longer lives only in interpreted pages.
- In upstream Binaryen `version_129`, it is a function-parallel structured-control cleanup pass.
- The short public description in `pass.cpp` says it removes breaks that are not needed.
- That description is true, but incomplete.

A better beginner summary is:

- Binaryen repeatedly cleans up branches and returns that already flow to the surrounding continuation,
- reshapes loops and named blocks so more exits become obviously removable,
- simplifies `switch`, `if`, `local.set(if ...)`, and GC `br_on_*` forms,
- threads some trivial jumps afterward,
- and then runs a late optimizer block for `br_if`, `br_table`, `select`, and local-set arm cleanups.

So this is **not** just a trailing-branch stripper.

## Why this pass matters

- Binaryen runs `remove-unused-brs` **three times** in the canonical no-DWARF `-O` / `-Os` function pipeline.
- The `pass.cpp` comments make the rerun logic explicit:
  - early `remove-unused-names` and later `merge-blocks` help RUB
  - later `coalesce-locals` opens more RUB opportunities
  - late `remove-unused-names` and another `merge-blocks` clean up after RUB again
- The pass still has an active backlog slice in `agent-todo.md` under `RUB`.
- The saved generated-artifact work also touched RUB heavily, especially the retired slot-14 and slot-40 corruption witnesses that now live in the parity history.

This makes RUB relevant to:

- scheduler fidelity
- artifact parity
- runtime work
- and future HOT/IR2 cleanup planning

## Most important durable takeaways

- The pass is staged.
  - main flow cleanup fixpoint
  - loop cleanup
  - block sinking
  - GC-specific BrOn cleanup
  - jump-threading
  - late final optimizer
- The pass is shape-driven.
  - many important rewrites only fire on very specific block / `if` / `br_if` / `local.set` / `switch` families
- The pass uses effects and cost reasoning, not just structural matching.
- The pass also owns some EH and GC cleanup surface:
  - caught `throw` can become `br`
  - `br_on_null`, `br_on_non_null`, and `br_on_cast*` can simplify using fallthrough-type knowledge
- Branch hints are part of the contract.
- `never-unconditionalize` is part of the contract.
- `version_129` is still the release oracle, and the 2026-05-05 current-main recheck stayed aligned on the reviewed surfaces aside from the already-tracked JumpThreader type-equality relaxation.

## Biggest beginner correction

The easy wrong mental model is:

- “RUB removes dead branches.”

The safer mental model is:

- “RUB is Binaryen's structured branch-and-fallthrough cleanup pass, and some of its most important rewrites are profitable control reshapes, not just dead-exit deletion.”

Examples include:

- `if` to `br_if`
- adjacent `br_if` to `br_table`
- pure-arm `if` to `select`
- `local.set(if ...)` arm extraction
- caught `throw` to `br`
- BrOn simplification from type knowledge

## What the pass sounds like versus what it actually does

What it sounds like:

- delete useless `br`

What it actually is in `version_129`:

- a custom flow-tracking postwalk
- a loop/body reshaper
- a block-sinking helper
- a GC branch simplifier
- a jump-threader
- a late optimizer for `br_if`, `br_table`, `select`, and local-set arm cleanup
- plus branch-hint-aware conditional-vs-unconditional execution policy

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Direct `version_129` source-backed walkthrough of the real pass stages, helper dependencies, scheduler placement, and main bailout logic.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact upstream file map, helper dependency story, official lit-family roster, and the narrow current-main freshness note.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT and IR shape catalog covering positive rewrites, bailout families, EH/GC shapes, and nearby pass interactions.
- [`./pattern-catalog.md`](./pattern-catalog.md)
  - Exhaustive inventory of the current in-tree Starshine rewrite and skip surface.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current local strategy overview: the raw pre-lift gate, the HOT rewrite engine, the exact MoonBit registry / preset / dispatcher / test code map, and the current local-vs-upstream boundary.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current local HOT architecture plus an exact MoonBit registry / preset / raw-dispatch / helper-cluster / test map for the current implementation.
- [`./tail-and-return-cleanups.md`](./tail-and-return-cleanups.md)
  - Local detailed notes for tail exits, return-context cleanup, and exit-only value-`if` families.
- [`./select-and-condition-rewrites.md`](./select-and-condition-rewrites.md)
  - Local detailed notes for value-`if`, `select`, condition folding, and `br_table` ladders.
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)
  - Local detailed notes for block-local `br_if`, payload-branch rewrites, and local-set arm cleanup.
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md)
  - Local detailed notes for carried-guard and result-block families.
- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
  - HOT-lift guide for returned-ladder artifact shapes.
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)
  - Local raw/hot skip rules, mutation limits, and performance heuristics.
- [`./parity.md`](./parity.md)
  - Current artifact signoff state, retired blockers, remaining gaps, and traced hotspot history.

## Freshness note

This refreshed landing page is anchored on Binaryen `version_129`.
The reviewed official GitHub release page checked on 2026-04-22 showed publish date **2026-04-01**.

A 2026-05-06 current-main recheck on `RemoveUnusedBrs.cpp`, `pass.cpp`, and the representative `remove-unused-brs*` lit surfaces stayed aligned with the upstream story already taught here.
The living dossier's already-tracked JumpThreader type-equality relaxation remains the only documented `main`-vs-`version_129` drift on the reviewed surface.

That is still a narrow spot check, not a whole-file equivalence proof, so keep treating `version_129` as the explicit release oracle in this folder.

## Current maintenance rule

- Treat this folder as the canonical home for future RUB scheduler, shape, parity, and performance notes.
- Keep the central beginner correction explicit:
  - upstream `remove-unused-brs` is broader than dead-tail stripping but narrower than a generic CFG optimizer.
- Keep `version_129` and current-main facts separated explicitly when they differ.
- When new local work changes artifact parity or skip behavior, update:
  - [`./pattern-catalog.md`](./pattern-catalog.md)
  - the owning detailed family page
  - [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) for cost/ordering changes
  - [`./parity.md`](./parity.md) for signoff or blocker changes

## Sources

- [`../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md`](../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md)
- [`../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/research/0247-2026-04-22-remove-unused-brs-primary-sources-and-code-map-followup.md`](../../../raw/research/0247-2026-04-22-remove-unused-brs-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md`](../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md)
- [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- [`../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md`](../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md`](../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
