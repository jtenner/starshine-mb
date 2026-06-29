# Remove-unused-brs GC fallthrough payload split boundary

Date: 2026-06-29

## Question

Can Starshine safely implement the remaining Binaryen `RemoveUnusedBrs.cpp::optimizeGC(...)` payload-bearing `SuccessOnlyIfNonNull` split for `br_on_cast` forms whose fallthrough path still needs to drop the branch payload?

## Source evidence

Binaryen `version_130` handles this case inside `optimizeGC(...)` under `GCTypeUtils::SuccessOnlyIfNonNull`:

- it rewrites `br_on_cast` to `br_on_non_null` plus an appended `ref.null`;
- it uses `maybeCast(getRefValue(), curr->getSentType().with(Nullable))` to preserve result validity;
- `getRefValue()` may use `ChildLocalizer(curr, ...)` when child movement is needed;
- after the rewrite, `ReFinalize` repairs expression types.

A local Binaryen probe in `.tmp/rub-gc-success-nonnull-payload.wat` shows why payload-bearing fallthrough cases are not the same as the earlier branch-taking prefix-payload cases. Binaryen prints a scratch-local-heavy repair: it stores the payload and ref, places a `br_on_non_null` in an inner result block, drops the payload on the not-taken path, and reconstructs the outer branch payload on the taken path.

A simpler candidate that tried to leave the payload on the outer stack while placing the `br_on_non_null` in an inner block was invalid: `wasm-tools validate --features all .tmp/rub-gc-split-stack-payload-candidate.wat` failed with `type mismatch: expected i32 but nothing on stack`. This confirms that an inner `br_on_non_null` cannot safely consume an outer-stack payload for the outer branch label without localization.

## Starshine representation finding

The public stack-source fixture lifts as a fallthrough-producing stack-payload shape, not as the child-payload branch-taking shape implemented in note `1372`:

```wat
(block $exit (type $r)
  (i32.const 7)
  (local.get $x)
  (br_on_cast $exit (ref null i31) (ref i31))
  (drop)
  (drop)
  (i32.const 9)
  (ref.null i31))
```

The first `drop` removes the fallthrough ref; the second removes the payload that remains on the not-taken path. Moving the branch test into a result block requires the payload to be localized into a scratch local and reloaded for the branch, while preserving the fallthrough drop and evaluation order.

Starshine's current `remove_unused_brs_try_rewrite_gc_br_on_root(...)` intentionally only implements the no-payload `SuccessOnlyIfNonNull` split and the safe branch-taking prefix-payload cases. It does not have a RUB-local child localizer for this fallthrough-payload split.

## Test coverage

Added focused boundary coverage:

- `remove-unused-brs boundary keeps fallthrough-producing payload br_on_cast split`

The test keeps the exact stack-payload `SuccessOnlyIfNonNull` shape unchanged and documents the reopening requirement: implement only with a localizer-backed rewrite that proves branch arity, fallthrough result typing, evaluation order, and payload drop repair.

## Validation

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `199/199` after converting the red positive probe into an explicit boundary.

## Reopening criteria

Reopen this boundary when RUB has a source-backed child-localization mechanism for BrOn payloads, or when a HOT/binary representation exposes the payload and fallthrough drops in a way that can prove all of:

1. branch arity including payload plus casted ref,
2. fallthrough result type after the appended `ref.null`,
3. single evaluation of payload and ref operands in source order,
4. correct payload dropping on the not-taken path,
5. valid lowering without relying on values below an inner block's stack height.
