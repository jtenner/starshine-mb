---
kind: entity
status: supported
last_reviewed: 2026-07-30
sources:
  - ../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md
  - ../../release-horizon-and-oracles.md
  - ../late-pipeline-dispatch.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast
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

## Binaryen v131 closeout status

The 2026-07-30 audit closes direct behavior, size, performance, generator breadth, and public scheduler placement against official `wasm-opt version 131 (version_131)`. `remove-unused-brs-all` now contains 21 focused leaves spanning the main flow, one-arm `if`, loop, block-sinking, EH, jump-threading, tablification, set/tee, restructure-if, adjacent-branch, GC, switch, multivalue, wrapper, and boundary families. The required regular `100000`, wasm-smith `10000`, dedicated `10000`, and random-all `10000` lanes have zero Starshine failures or unclassified size losses. A separate direct O4z-option replay is `6853` canonical byte matches plus `3147` strictly smaller Starshine outputs, totaling `-54270` bytes.

Scheduler placement is also closed. Starshine's public optimize/shrink roster now matches Binaryen v131's unchanged 56-slot / 38-owner top-level order, with RUB at zero-based indices `13`, `24`, and `39`; Starshine's documented `strip-debug` extension is the sole 57th slot.

## Role

- `remove-unused-brs` is an active implemented **hot pass** in Starshine.
- Current large-artifact correctness/runtime evidence is note [`1647`](../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md): rollback-capable changed-function batch validation plus three source-backed fail-closed guards replace a `580.178s` invalid direct output with valid byte-identical `3.239s` / `3.068s` repeats. The current artifact reaches a byte-identical fixed point after three productive applications; regular `10000` compare is fully normalized, and the dedicated `115`-mismatch accepted family is runtime-all-equal with zero validation failures.
- The folder retains historical research plus direct `version_131` source and lit URLs below, so the release/source/test provenance does not depend on an intermediate capture.
- In the current upstream oracle, Binaryen `version_131`, it is a function-parallel structured-control cleanup pass.
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
- Historical direct mismatch slices are closed. Remaining O4z work belongs to neighboring post-`code-folding` cleanup and broader ordered-pipeline signoff, not to RUB behavior or placement.
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
- Branch hints are part of the upstream Binaryen contract.
- `never-unconditionalize` is part of the upstream Binaryen contract.
- Starshine documents those two surfaces as RUB-N/RUB-X metadata/pass-option blockers until expression-level code metadata and pass-arg plumbing exist locally.
- `version_131` is the release oracle. `RemoveUnusedBrs.cpp` is byte-identical to the retained v130 owner, so the JumpThreader relaxation, branch-to-trap behavior, helper contracts, and official transform families carry forward unchanged.

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

What it actually is in `version_131`:

- a custom flow-tracking postwalk
- a loop/body reshaper
- a block-sinking helper
- a GC branch simplifier
- a jump-threader
- a late optimizer for `br_if`, `br_table`, `select`, and local-set arm cleanup
- plus branch-hint-aware conditional-vs-unconditional execution policy

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Direct `version_131` source-backed walkthrough of the real pass stages, helper dependencies, scheduler placement, and main bailout logic.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact upstream file map, helper dependency story, official lit-family roster, and the source-backed `version_131` behavior matrix.
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
- [`../../pass-manager-threshold-guards.md`](../../pass-manager-threshold-guards.md)
  - Cross-pass threshold policy, complete RUB gate classification, stable trace reasons, and focused boundary-test rules.
- [`./parity.md`](./parity.md)
  - Current artifact signoff state, retired blockers, remaining gaps, and traced hotspot history.

## Freshness note

This landing page is anchored on the verified official Binaryen `version_131` binary (`wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`). The 2026-07-30 source audit confirms `RemoveUnusedBrs.cpp` is unchanged from v130; `pass.cpp` still schedules exactly three RUB applications in the 56-slot top-level optimizer roster.

For `[O4Z-AUDIT-RUB-A]`, WebAssembly 3.0 baseline features are assumed enabled by default. Do not treat GC as optional gated behavior in the Starshine RUB matrix unless a local parser/tool limitation is recorded as a blocker.

## Current maintenance rule

- Treat this folder as the canonical home for future RUB scheduler, shape, parity, and performance notes.
- Keep the central beginner correction explicit:
  - upstream `remove-unused-brs` is broader than dead-tail stripping but narrower than a generic CFG optimizer.
- Keep `version_131` release-oracle facts and current-main facts separated explicitly when they differ.
- When new local work changes artifact parity or skip behavior, update:
  - [`./pattern-catalog.md`](./pattern-catalog.md)
  - the owning detailed family page
  - [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) for cost/ordering changes
  - [`./parity.md`](./parity.md) for signoff or blocker changes

## Sources

- research note 0548
- research note 0461
- research note 0247
- research note 0146
- research note 0070
- research note 0071
- [research note 0093](../late-pipeline-dispatch.md)
- [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt`](../../../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- research note 0505
- research note 0461
- Binaryen `version_131` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedBrs.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
