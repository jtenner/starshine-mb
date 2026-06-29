# 1380 - remove-unused-brs remaining GC boundary closure

Date: 2026-06-29

## Scope

This slice re-audits the remaining `[O4Z-AUDIT-RUB-Q]` GC `optimizeGC(...)` entries after notes `1366`, `1370`, `1372`, `1373`, `1374`, and `1379`:

- descriptor `br_on_cast_desc_eq*` forms;
- broader fallthrough-type / local.tee cast insertion;
- fallthrough-producing payload splits that require child localization;
- public stack-form unreachable-input BrOn cleanup;
- nullable disjoint `SuccessOnlyIfNull`.

No pass implementation changed in this slice. The result is a source-backed closure of the remaining GC entries as narrow blockers / non-goals with reopening criteria.

## Source evidence

Local Binaryen oracle source: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`wasm-opt version_130`).

`optimizeGC(...)` does more than simple null/cast folding:

- it computes `Properties::getFallthroughType(curr->ref, ...)` and may refine `curr->castType` before evaluating the cast check;
- it may wrap the current BrOn in a cast with `maybeCast(...)` if the refined BrOn type is no longer a subtype of the old type;
- descriptor BrOn forms use `curr->desc` and call `ChildLocalizer(curr, ...)` in `getRefValue()` to preserve descriptor evaluation, null-descriptor traps, and ref movement across the descriptor operand;
- `SuccessOnlyIfNonNull` rewrites ordinary casts to `br_on_non_null` plus appended `ref.null`;
- `SuccessOnlyIfNull` is explicitly left as a Binaryen `version_130` TODO;
- `Unreachable` uses `getDroppedChildrenAndAppend(...)` to preserve dropped child effects before appending `unreachable`.

## Local representation and proof status

Starshine already implements the safe local GC subset:

- definite `br_on_null` / `br_on_non_null` taken and not-taken cases;
- definitely successful ordinary `br_on_cast` and definitely not-taken ordinary `br_on_cast_fail`;
- no-payload nullable-source / non-null-target `SuccessOnlyIfNonNull` split to `br_on_non_null` plus appended `ref.null`;
- no-payload non-null disjoint definite-failure cases for ordinary `br_on_cast` / `br_on_cast_fail`;
- selected branch-taking prefix-payload cases where the branch consumes the prefix payload safely;
- child-form ordinary unreachable-input `br_on_cast*` cleanup with payload drops;
- public stack-form unreachable-input preservation as an explicit boundary test.

The remaining GC entries are intentionally not implemented yet:

1. **Descriptor BrOn forms are representation-blocked.** Local `Instruction`, HOT, binary, WAT/WAST, and validator surfaces expose ordinary `BrOnCast` / `BrOnCastFail` but no descriptor-bearing BrOn op. The repo has descriptor leaf casts (`RefCastDescEq`) but not `br_on_cast_desc_eq*` branch forms. Implementing RUB descriptor cleanup before that representation exists would be a fake pass-only behavior.
2. **Broader fallthrough-type/local.tee cast insertion needs a localizer proof.** Binaryen can refine using `Properties::getFallthroughType(...)` and repair type validity with `maybeCast(...)`. Starshine's current safe subset uses direct local HOT type facts. Widening to fallthrough-derived `local.tee` refinements needs proof that inserted `ref.cast` / `ref.as_non_null` nodes preserve stack order, branch payload order, trap order, and refinalization.
3. **Fallthrough-producing payload splits still need ChildLocalizer-style scratch-local repair.** Note `1373` already reduced the failure: stack payloads must feed the inner `br_on_non_null` branch while still being dropped on the fallthrough path. A naive rewrite cannot legally consume the same stack payload in both places.
4. **Public stack-form unreachable-input cleanup remains a raw/lift exposure boundary.** Note `1379` added coverage proving public `unreachable; br_on_cast` remains conservative. Reopen only with raw stack rewrite proof or HOT lift exposing the ref operand as an explicit child-form unreachable input.
5. **Nullable disjoint `SuccessOnlyIfNull` is a Binaryen `version_130` non-goal.** The upstream source itself leaves that case under a TODO that would require a fresh label and a `br_on_non_null` inversion shape. Starshine should not claim a parity gap for a transform the local release oracle does not implement.

## Tests

No new test was needed for this documentation-only closure. Existing RUB-Q tests cover the local implemented and boundary-protected GC cases:

- `remove-unused-brs splits nullable br_on_cast success-only-if-non-null`
- `remove-unused-brs boundary keeps fallthrough-producing payload br_on_cast split`
- `remove-unused-brs removes definitely failing non-null br_on_cast`
- `remove-unused-brs rewrites definitely failing non-null br_on_cast_fail to branch`
- `remove-unused-brs rewrites definitely failing non-null br_on_cast_fail with payload`
- `remove-unused-brs boundary keeps nullable disjoint br_on_cast checks`
- `remove-unused-brs replaces child-form unreachable-input br_on_cast with unreachable`
- `remove-unused-brs drops payload children for child-form unreachable-input br_on_cast`
- `remove-unused-brs boundary keeps public stack-form unreachable-input br_on_cast`

## Commands

No command was run for this slice before the later validation slice. This slice changed only docs/research classification and did not change pass behavior.

## Status update

The GC entry is now narrowed to exact accepted blockers rather than broad unknown missing behavior:

- descriptor BrOn: representation blocker;
- fallthrough/local.tee cast insertion: localizer/refinalization proof blocker;
- fallthrough-producing payload splits: ChildLocalizer/scratch-local blocker;
- public stack-form unreachable input: raw-proof or HOT-exposure blocker;
- nullable disjoint `SuccessOnlyIfNull`: Binaryen `version_130` TODO/non-goal.

Reopen only when the named local representation or proof exists, or when a fresh Binaryen source version implements the upstream TODO / descriptor behavior differently.
