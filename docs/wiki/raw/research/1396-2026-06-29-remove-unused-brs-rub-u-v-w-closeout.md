# 1396 - remove-unused-brs RUB-U/V/W closeout

Date: 2026-06-29

## Scope

This slice closes three strict as-good-or-better follow-ups after RUB-R/S/T:

- `[O4Z-AUDIT-RUB-U]` descriptor `br_on_cast_desc_eq*` cleanup when representation support exists;
- `[O4Z-AUDIT-RUB-V]` large `br_table` JumpThreader beyond the nine-target guard;
- `[O4Z-AUDIT-RUB-W]` public stack-form ordinary `br_on_cast*` unreachable-input cleanup.

## RUB-U: descriptor BrOn representation status

Notes `1374` and `1380` classified descriptor branch-cast cleanup as representation-blocked, not a semantic non-goal. A current source check keeps that classification:

- leaf descriptor casts are represented (`RefCastDescEq` in `src/lib/types.mbt`, `HotOp::RefCastDescEq` in `src/ir/hot_core.mbt`, plus binary/WAT/WAST/validator/typechecker paths);
- ordinary branch casts are represented (`BrOnCast` / `BrOnCastFail`);
- repo search still finds no `BrOnCastDesc*`, `br_on_cast_desc_eq*` branch instruction, descriptor-bearing branch HOT op, or branch-descriptor binary/WAT/HOT lowering path.

Conclusion: no RUB transform should be implemented for descriptor BrOn in pass-only code yet. Reopen when `Instruction`, binary decode/encode, WAT/WAST lowering, validator/typechecker, HOT lift/lower, and focused round-trip tests can carry descriptor BrOn forms with both ref and descriptor operands. Then add red-first descriptor cleanup and negative tests against `remove-unused-brs-desc.wast`-style cases.

## RUB-V: large br_table JumpThreader safe subset

Prior notes `1375` and `1381` showed two facts:

- Binaryen's JumpThreader has no small-table cutoff for no-payload `Type::none` scope uses;
- a broad local cap raise to `32` regressed existing mostly-default switch-lowering fixtures, so Starshine kept a defensive `<= 9` guard.

This slice split that boundary instead of leaving all larger tables closed. The safe predicate is: allow larger no-payload selector-only table retargeting unless the table has the mostly-default switch shape that `optimizeSwitch(...)` owns. The helper trims trailing defaults and leading defaults like `optimizeSwitch(...)`, then treats a table as switch-shaped when the remaining target list has at least three entries and all middle targets are the default target.

Implementation:

- `remove_unused_brs_branch_table_has_mostly_default_switch_shape(...)` identifies the switch-owned shape;
- `remove_unused_brs_branch_table_can_retarget_without_payload(...)` keeps the existing child-count and branch-arity gates, but only blocks tables beyond nine targets when that mostly-default shape is present;
- pure ten-target shell tables now retarget through one-child named block shells;
- ten-target mostly-default tables stay conservative.

Tests:

- Red-first positive: `remove-unused-brs retargets pure ten-target br_table shell` failed under the old `<= 9` cap (`1 != 0` on the first target label), then passed after implementation.
- Boundary: `remove-unused-brs boundary keeps ten-target mostly-default br_table conservative` locks the switch-owned family that must not be retargeted by JumpThreader.

Reopen for broader large-table work only with tests/evidence proving mostly-default switch expectations, below-threshold mostly-default boundaries, and artifact raw gates stay green.

## RUB-W: public stack-form unreachable-input br_on_cast

Notes `1374`, `1379`, and `1380` remain current. Starshine's implemented safe subset is child-form HOT ordinary `br_on_cast*` whose ref child is explicit `unreachable`; it drops payload children before appending the replacement `unreachable`.

The public stack-form case remains blocked because `unreachable; br_on_cast` does not currently expose a child-form BrOn root to the pass. A raw rewrite would need to prove:

- stack effects and branch arity;
- dropped payload order and side effects before the replacement `unreachable`;
- validation after replacement;
- refinalization/HOT lowering safety.

Existing boundary test `remove-unused-brs boundary keeps public stack-form unreachable-input br_on_cast` remains the correct fail-closed owner. Reopen only when HOT lift exposes this public stack form as an explicit child-form unreachable ref child or a raw pre-lift rewrite proof lands with validation evidence.

## Commands

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after adding the RUB-V positive before implementation: failed `219/220`; `remove-unused-brs retargets pure ten-target br_table shell` saw the old inner label (`1 != 0`).
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after implementation: passed `220/220`.
- `moon fmt` after docs/backlog synchronization: passed.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after formatting: passed `220/220`.
- `moon test src/passes`: passed `3626/3626`.
- `git diff --check`: passed with no output.
