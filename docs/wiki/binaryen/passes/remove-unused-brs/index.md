---
kind: entity
status: supported
last_reviewed: 2026-08-10
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

## 2026-08-01 performance follow-up

`[RUB-PERF]001` is complete with a maintainer-approved bounded performance re-sign layered on the 2026-07-31 full correctness closeout. The raw boundary now recognizes giant `br_table` convergence no-ops before HOT lift while preserving the existing decision-ladder rewrite, and an early-facts scan avoids recursively rebuilding functions that cannot contain that rewrite. HOT hazard scans memoize shared DAG nodes, nested dead-suffix traversal visits each node once, and CFG construction is lazy until an exact eligible suffix reaches the reachability proof.

Current native SHA-256 `8ac6819cfd7deaa3786a4996e47c13bc76e8f2a796f5d4876d4559efeea5b6ee` preserves the reviewed debug artifact byte-for-byte. Five native-release runs measure a `227.250ms` Starshine pass median versus `289.650ms` Binaryen v131 (`0.785x` by independent medians; `0.780x` paired-run median), improving Starshine by `61.8%` from the prior `595.227ms` median and delivering about `1.27x` Binaryen throughput. Whole-command median improves from about `11.565s` to `3.328s` (`71.2%`), while the retained 3,000-block native pipeline median is `377390us`, `4.5%` below the prior `395298us` measurement. Moon passes `247/247` focused RUB, `4/4` RUB white-box, `6643/6643` pass tests, and full `10177/10177`.

The 2026-08-01 performance re-sign uses an explicit maintainer-approved bounded exception to the ordinary full-matrix rule. Near-final `100`-case smokes are regular `13` direct plus `87` cleanup-normalized, wasm-smith `99/99` comparable exact with one Binaryen-only failure, dedicated `72` direct plus `3` cleanup-normalized plus `25` residuals, and random-all `65` direct plus `20` cleanup-normalized plus `15` residuals. There are zero Starshine command, generator, validation, or property failures; the corrected final binary repeats the dedicated `100/100` result exactly (`72` direct, `3` cleanup-normalized, `25` residuals), and a prior-slice dedicated `1000/1000` smoke also had zero failures. Full explicit-v131 dedicated attempts timed out after `1713/10000` and `2274/10000` completed cases, so those partial runs are recorded only as operational evidence. The 2026-07-31 full matrix remains the behavioral provenance; reopen RUB if a future change alters artifact bytes, runtime repros, validation, or residual families.

## 2026-07-31 correctness reclose

A post-closeout review found that the same-target two-arm `if` rewrite discarded condition evaluation. That is a correctness defect for calls, local writes, mutable-state reads, and trapping conditions. Starshine now emits `drop(condition)` before the unconditional branch. Focused Node runtime replays prove the repair against the original module, pre-review Starshine, current Starshine, and Binaryen v131: call/global mutation returns `7` instead of the old Starshine `0`; `local.tee` returns `9` instead of `0`; and the load/division condition fixtures trap instead of the old Starshine returning `1`. Current Starshine matches the original and Binaryen on all four RUB outcomes.

Direct behavior is **reclosed** on native SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` against official Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. Focused RUB passes `247/247`, `src/passes` passes `6640/6640`, and full Moon passes `10174/10174`. The required matrix is regular `14604` direct plus `85396` cleanup-normalized, wasm-smith `9954` direct plus `2` cleanup-normalized across `9956` comparable cases, dedicated `7251` direct plus `404` cleanup-normalized and `2345` strictly smaller Starshine outputs totaling `-51852` bytes, and random-all `7669` direct plus `1595` cleanup-normalized and `736` strictly smaller outputs totaling `-3638` bytes. There are zero Starshine validation, generator, property, or command failures. Scheduler placement remains unchanged.

## Historical Binaryen v131 closeout evidence

The 2026-07-30 audit previously closed direct behavior, size, performance, generator breadth, and public scheduler placement against official `wasm-opt version 131 (version_131)`. `remove-unused-brs-all` now contains 21 focused leaves spanning the main flow, one-arm `if`, loop, block-sinking, EH, jump-threading, tablification, set/tee, restructure-if, adjacent-branch, GC, switch, multivalue, wrapper, and boundary families. The required regular `100000`, wasm-smith `10000`, dedicated `10000`, and random-all `10000` lanes have zero Starshine failures or unclassified size losses. A separate direct O4z-option replay is `6853` canonical byte matches plus `3147` strictly smaller Starshine outputs, totaling `-54270` bytes.

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
- The 2026-07-31 condition-evaluation review is reclosed by focused runtime and the refreshed four-lane matrix. Placement remains closed.
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

## 2026-08-09 production O4z guards

Two validating-but-wrong generated families now fail closed before HOT rewriting. A loaded comparison branch could lose its load/local producer while retaining a condition over an uninitialized local; a 255+-local parser could store an undivided `i64` carrier while moving the division into only one later use. The named raw reasons are `loaded-comparison-branch-remove-unused-brs-noop` and `large-arithmetic-local-carrier-remove-unused-brs-noop`, with red-first coverage in `src/passes/remove_unused_brs_test.mbt`. The focused suite is `251/251`, and all three locked top-level RUB slots remain present.

## 2026-08-10 self-opt effect-order hardening

Exact self-optimized spec execution exposed additional validating call/ownership reorderings in the first and later RUB slots. Red structural fixtures now preserve structured same-local distinct calls, condition-child call-tee lifetimes, loads before same-local releases, consumers before two or one argument releases, and call results before local reloads. The named guards are intentionally ordered behind older performance/shape owners where needed, so large `br_table` return ladders still reach their HOT skip and typed encoder ladders retain their established raw reason. Function isolation covered defined functions `7902`, `8264`, `8905`, `10449`, and `10819`; the focused suite is now `257/257`, full Moon is `10,306/10,306`, and exact direct self-opt full spec is `284/284` without failures (`64` passed, `220` intentionally skipped).

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
