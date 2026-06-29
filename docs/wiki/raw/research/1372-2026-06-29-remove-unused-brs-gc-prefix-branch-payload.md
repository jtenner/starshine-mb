# Remove-unused-brs GC prefix branch-payload slice

Date: 2026-06-29

## Question

Can `[O4Z-AUDIT-RUB-Q]` shrink the remaining GC `br_on_*` payload/prefix backlog without implementing Binaryen's full `ChildLocalizer` machinery?

## Source evidence

Binaryen `version_130` `RemoveUnusedBrs.cpp::optimizeGC(...)` handles `BrOnNull`, `BrOnNonNull`, `BrOnCast`, and `BrOnCastFail` in a postwalk. For definitely taken or definitely successful branches it rewrites the `BrOn` to a plain `br` while preserving the values already associated with the branch target; broader descriptor and child-reordering cases use `ChildLocalizer`, `maybeCast(...)`, `getDroppedChildrenAndAppend(...)`, and final refinalization.

Local source re-read: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` lines around `visitBrOn(...)`, especially the `BrOnNull`, `BrOnNonNull`, `Success`, `Failure`, `SuccessOnlyIfNonNull`, and `Unreachable` cases. A local Binaryen probe `.tmp/rub-gc-payload.wat` confirmed that a stack-prefix `br_on_null` with an `i32` label payload is optimized by Binaryen, although Binaryen repairs the printed stack form with scratch locals.

## Local slice

Implemented the locally safe branch-taking prefix subset in `remove_unused_brs_try_rewrite_gc_br_on_root(...)`:

- HOT `BrOn` children are now split into `payloads` plus the final ref child.
- Definitely taken `br_on_null` on a literal `ref.null` now rewrites prefix payload children to a direct `br` carrying those payloads. The pure `ref.null` guard can be omitted in the payload form.
- Definitely taken `br_on_non_null` now rewrites to a direct `br` carrying existing prefix payloads plus the non-null ref.
- Definitely successful `br_on_cast` now rewrites to a direct `br` carrying existing prefix payloads plus the ref when the local type match already proves the cast succeeds.
- Definitely failing non-null disjoint `br_on_cast_fail` now rewrites to a direct `br` carrying existing prefix payloads plus the ref.

The slice intentionally does not claim the full payload/fallthrough surface. It keeps fallthrough-producing payload cases, nullable-source `SuccessOnlyIfNonNull` splits with payloads, descriptor BrOn forms, unreachable-input dropped-child construction, and cast-insertion/localization cases closed until local HOT has source-backed child-localization/cast-insertion proof.

## Tests

Red-first representative positive:

- `remove-unused-brs rewrites definitely taken br_on_null with payload`

The focused test failed before implementation because Starshine still printed `br_on_null` in the payload fixture:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
failed 194/195; the payload br_on_null remained in the output
```

Additional coverage added after the helper generalized the branch-value builder:

- `remove-unused-brs rewrites definitely taken br_on_non_null with payload`
- `remove-unused-brs rewrites definitely successful br_on_cast with payload`
- `remove-unused-brs rewrites definitely failing non-null br_on_cast_fail with payload`

Existing boundaries remain active:

- `remove-unused-brs boundary keeps nullable disjoint br_on_cast checks`
- `remove-unused-brs keeps unknown br_on_cast checks`

## Validation so far

Focused tests after implementation:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
passed 198/198
```

Full slice validation and direct compare are recorded in the thread summary and should be refreshed after the three-slice iteration completes.

## Remaining GC boundaries

Still open under `[O4Z-AUDIT-RUB-Q]`:

- fallthrough-producing payload BrOn rewrites that require multi-value result repair and/or exact stack-shape proof;
- payload-bearing `SuccessOnlyIfNonNull` splits, because the split needs a fresh result block plus payload/ref preservation and may require cast insertion;
- descriptor `br_on_cast_desc_eq*` forms, absent from local `Instruction` / `HotOp`;
- broader fallthrough-type / local.tee cast insertion;
- unreachable-input dropped-child construction;
- nullable disjoint `SuccessOnlyIfNull`, which is a Binaryen `version_130` TODO rather than a Starshine implementation gap for this release oracle.

Reopen this branch for additional payload/prefix cases only with a source-backed child-localization design that proves evaluation order, branch arity, fallthrough result typing, and cast insertion are preserved.
