---
kind: comparison
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
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
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
---

# `remove-unused-brs` Binaryen Parity

## Durable Conclusions

- Binaryen's `RemoveUnusedBrs` is phase-driven and Starshine now mirrors a meaningful subset of that structure.
- The current tree already covers much more than dead tail stripping:
  - tail `br` / `return` elimination
  - one-armed `if` to `br_if`
  - two-armed branch-exit cleanup
  - block-local chain flattening
  - value-`if` to `select`
  - local-set arm cleanup
  - branch-payload `if` cleanup
  - carried-guard/result-block cleanup
  - repeated-constant `br_if` ladders to `br_table`
- The remaining artifact work is not a generic "RUB still weak on branches" statement.
- The remaining work is now concentrated in later shape families where:
  - Binaryen preserves nested carried-wrapper result-block structure longer than Starshine does in `Func 50`
  - a later loop/block-order mismatch remains around `Func 381`
  - some remaining normalized-WAT differences may not be RUB logic at all if the trace still reports `changed=false`

## Current Coverage Surface

- Focused correctness coverage:
  [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
- Perf and bailout coverage:
  [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- Raw pre-lift behavior:
  [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Preset replay coverage for the three modeled RUB slots:
  [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- CLI and artifact replay coverage:
  [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)

## What Is Already In Good Shape

- Scheduler parity:
  `optimize` and `shrink` both replay RUB in three top-level slots, and that is covered by focused preset tests.
- Gen-valid compare-pass evidence:
  the current backlog records clean `100`, `1000`, and `10000` case `gen-valid` lanes with zero mismatches.
- Mixed-generator compare evidence:
  the current saved runs are still clean on compared cases and stop mainly on Binaryen-side command failures rather than Starshine semantic mismatches.
- Artifact validation:
  the native `cmd` replay for `--remove-unused-brs` now validates the checked-in debug artifact in-memory.
- Specific fixed families called out by the backlog:
  - explicit `nop` body preservation in trivial `if` arms
  - lone explicit root `nop` preservation
  - dropped then-arm carried-result wrapper cleanup
  - prefixed one-arm payload branch suffix cleanup
  - carried-suffix wrapper recognition through Binaryen's parser path
  - self-target if-arm block-branch sinking
  - raw structured-return-ladder false-positive skipping

## Current Open Gap

The active backlog now says the next work should be reduced in this order:

- The remaining parity families are not just tail-branch-removal gaps.
- The real missing area includes Binaryen's later final-shape cleanup, especially the `restructureIf` family that only becomes cheap after earlier simplification.
- Earlier MoonBit attempts tried to find those shapes by scanning more nested regions during the main walk, which hit real oracle cases but reopened the performance cliff.
- A health rerun on `2026-04-11` shows broader unresolved mismatches for `remove-unused-brs`:
  - mixed (`--generator both`): `199 / 199` compared, `175` normalized matches, `24` mismatches, `1` command failure (`binaryen-rec-group-zero` at `case-000029-wasm-smith`)
  - `--generator gen-valid` with `--max-failures 30`: `114 / 114` compared, `84` normalized matches, `30` mismatches, `maxFailuresHit: true`
- These mismatch cases are currently only labeled as `normalized outputs differed`; they are unresolved pending reduced repro classification.

## Current Risks

- Some artifact differences may still be lift/lower round-trip noise rather than real RUB logic differences.
- The new self-target arm rewrite already proved that broad block-root rewrites can regress older block-local flattening families.
- Self-opt performance is still materially over Binaryen's pass time budget, so future carrier-family work has to stay narrow and measured.

## Practical Rule

- Treat the pass as partially signed off on broad correctness, but not on final artifact parity.
- Prefer reductions that prove:
  - the pass actually mutates the function
  - the mutated shape is a genuine Binaryen delta
  - the narrowed rewrite does not reopen already-green block-local or returned-ladder families

## Suggested Reading Order

- Start with [`./pattern-catalog.md`](./pattern-catalog.md) for the full surface.
- Read [`./binaryen-strategy.md`](./binaryen-strategy.md) to keep the upstream phase model in mind.
- Read [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) and [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) before touching performance-sensitive matcher discovery.
- Read [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md) before working on any root-return or carried-wrapper mismatch that still looks "simple" in printed WAT.

- Archived research doc: [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- Follow-up health rerun: [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- HOT shape note: [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
- Implementation: [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
