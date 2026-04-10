---
kind: entity
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
  - ../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./pattern-catalog.md
  - ./binaryen-strategy.md
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

- `remove-unused-brs` is an active HOT pass in Starshine's Binaryen namespace.
- It is the main branch-structure cleanup pass for:
  - removing terminal `br` / `return` traffic that already flows to the surrounding continuation
  - rewriting branch-shaped `if` structures into `br_if`, `select`, `br_table`, or simpler payload forms
  - collapsing carried-wrapper shapes that only exist to shuttle branch payload values through result blocks
  - preserving Binaryen-compatible shapes where an earlier-looking cleanup would actually move Starshine away from the oracle

## Current Summary

- The pass runs in three modeled top-level slots inside both `optimize` and `shrink`.
- It has two execution layers:
  - a raw pre-lift fast path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - the HOT fixpoint in [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- The implementation is already much broader than "trailing branch stripping", and the old early `br_table` continuation-wrapper artifact gap is now fixed in-source.
- It is still an in-progress parity pass because the explicit debug-artifact compare remains noisy after that fix:
  - the saved compare still diverges in normalized WAT
  - the first remaining hunk now includes module type-order noise before later body-level diffs
  - self-opt runtime is back near the earlier Starshine baseline, but still well over Binaryen

## Page Map

- [`./pattern-catalog.md`](./pattern-catalog.md)
  Exhaustive inventory of every rewrite family, cleanup helper, and skip surface currently modeled by the pass.
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Upstream `RemoveUnusedBrs` phase structure, why Binaryen defers late shape work, and which parts of that strategy still matter for Starshine.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  The current in-tree Starshine architecture: raw pre-lift shortcutting, HOT traversal, fixpoint cycles, caches, and structural guards.
- [`./tail-and-return-cleanups.md`](./tail-and-return-cleanups.md)
  Detailed notes for terminal `br` / `return` stripping, return-context cleanup, tail-exit stripping, tail-return voidification, and trailing `nop` trimming.
- [`./select-and-condition-rewrites.md`](./select-and-condition-rewrites.md)
  Detailed notes for value-`if` to `select`, nested condition folding, `br_table` ladder formation, and one-sided stack-tail selection.
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)
  Detailed notes for block-local `br_if` formation, local-set arm rewrites, branch-exit `if` cleanup, payload-branch rewrites, and block-if flattening.
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md)
  Detailed notes for the carried-guard/result-block families that dominate the current artifact parity work.
- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
  HOT-lift shape guide for returned ladders, holder blocks, explicit `Return` nodes, and the reason printed WAT is not enough here.
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)
  The pass's execution model, seen-mask logic, raw/hot skip rules, mutation bounds, and performance-control heuristics.
- [`./parity.md`](./parity.md)
  Current signoff status, coverage surface, known remaining artifact gaps, and the next reductions that actually matter.

## Current Maintenance Rule

- Treat this folder as the canonical home for all future `remove-unused-brs` work.
- New RUB research should land here instead of being left only in `agent-todo.md`, one-off parity notes, or commit messages.
- Any new rewrite should update:
  - [`./pattern-catalog.md`](./pattern-catalog.md)
  - the detailed family page that owns the pattern
  - [`./parity.md`](./parity.md) if the current artifact state or active blocker changes
- Any new performance guard should also update [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) if it changes where the pass now fails fast.
