# RemoveUnusedBrs RUB-Q payload tablify / switch boundary audit

Date: 2026-06-29

## Goal

Audit the remaining payload/value `tablify(...)` ladder and child-less stack-payload `visitSwitch(...)` / switch-collapse items from `[O4Z-AUDIT-RUB-Q]`, then either implement a safe source-backed subset or document a narrow boundary with focused coverage.

## Source evidence

Primary source: Binaryen `version_130` `src/passes/RemoveUnusedBrs.cpp`.

### `FinalOptimizer::tablify(...)`

Re-read the local release-oracle source around `FinalOptimizer::tablify(Block*)`.

Key findings:

- The proper-`br_if` matcher rejects a candidate if it has no condition **or** has a branch value.
- The matcher also rejects non-`none` branch types, side-effectful shared selector expressions, duplicate constants, ranges beyond `MAX_RANGE = 1024`, and ranges above `num * 3`.
- Therefore value-carrying equality ladders are not an implementation gap for Starshine's `tablify(...)` parity target. Binaryen `version_130` itself does not tablify those branches.

Reopening criteria: reopen only if a newer Binaryen source starts accepting `br_if` values in `tablify(...)`, or if another Binaryen RUB phase independently rewrites value-carrying equality ladders with source evidence for payload repair.

### `FinalOptimizer::visitSwitch(...)` and early `optimizeSwitch(...)`

Re-read the release-oracle source around early `optimizeSwitch(...)` and late `FinalOptimizer::visitSwitch(Switch*)`.

Key findings:

- Early `optimizeSwitch(...)` trims trailing and leading default targets before considering branch values, but returns once `curr->value` is present for the trivial no-payload default-only / two-option / large-mostly-default rewrites.
- Late `visitSwitch(...)` collapses a switch with exactly one unique target to `drop(condition); br value` when there is no value or when Binaryen's effect analyzer can reorder the condition before the value.
- Starshine already has the local HOT child-form one-target value-switch collapse from `[O4Z-AUDIT-RUB-P]` and an effectful selector/value negative.
- The remaining child-less stack-payload shape in Starshine is a local HOT representation boundary: public stack-style value-switch WAT currently lifts the branch payload and selector as `br_table` children, so it is covered by the child-form collapse rather than exposing the child-less local shape.

Reopening criteria: reopen child-less stack-payload switch surgery if a public decoder/lifter path produces value-carrying `BrTable` nodes with `child_count == 0`, or if a direct HOT producer needs that representation and can prove safe selector/payload root repair.

## Test coverage added/strengthened

Updated `src/passes/remove_unused_brs_test.mbt`:

- Strengthened `remove-unused-brs collapses one-target value br_table with local selector` to assert that the public stack-style value-switch WAT lifts to a child-form HOT `br_table` (`child_count == 2`) before the pass collapses it. This documents why the child-less stack-payload shape is not exposed by that public fixture.
- Added `remove-unused-brs boundary keeps value-carrying equality ladder out of tablify`, with a source-backed boundary comment. The test keeps value-carrying dense `br_if` ladders as `br_if`s, verifies no `br_table` appears, and preserves the distinct payload constants.

No implementation change was needed: this was a source-backed boundary/coverage slice, not a missed-transform fix.

## Docs and backlog updates

Updated:

- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/pattern-catalog.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`
- `agent-todo.md`
- `docs/wiki/log.md`

Status changes:

- Payload/value equality-ladder `tablify(...)` is now documented as a Binaryen `version_130` non-goal with focused boundary coverage, not an open Starshine implementation gap.
- Public stack-style one-target value switches remain covered by the existing child-form late switch collapse.
- The only switch residue from this audit is the narrow local child-less stack-payload HOT shape, with exact reopening criteria above.

## Validation

Commands run:

1. `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`
   - First run after adding the boundary test failed `191/192` because the local WAT parser expected dropped value-`br_if` fallthroughs in this fixture shape.
   - Fixed the fixture by wrapping each value-carrying `br_if` in `drop(...)`.
2. `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`
   - Passed: `192/192`.
3. `moon fmt && moon test src/passes && moon info`
   - `moon fmt` passed.
   - `moon test src/passes` passed: `3598/3598`.
   - `moon info` passed with 6 pre-existing warnings.
4. `moon build --target native --release src/cmd`
   - Passed / no work to do.
5. `git diff --check`
   - No output.

No direct compare-pass lane was refreshed because this slice made no pass behavior change. The prior behavior-changing adjacent-branch slice already refreshed a 1000-case normalized direct compare.

## Remaining RUB-Q work after this slice

Still open:

- old-`try` / HOT catch-region body exposure if a binary path can produce local HOT `Try`
- large mostly-default `br_table` JumpThreader beyond the `<= 8` guard
- broader GC `br_on_*` payload/prefix/descriptor/fallthrough/localize/unreachable forms
- multi-result `sinkBlocks`
- value-carrying adjacent branch cleanup/merge
- the local child-less stack-payload switch shape described above
- broader select/restructure/set-if value legality
- raw-gate/performance accountability
- final generator/signoff freshness
