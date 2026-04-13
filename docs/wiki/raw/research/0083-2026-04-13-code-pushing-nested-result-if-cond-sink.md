# 0083 — Code-pushing nested result-`if` condition sink frontier

- Date: 2026-04-13
- Area: `code-pushing`
- Status: landed

## Goal

- Reduce the sharper standalone `Func 1975` mismatch from [`0082`](./0082-2026-04-13-code-pushing-standalone-func1975-frontier.md) into an in-repo regression.
- Explain why current Starshine still kept a movable alias `local.set(local.get ...)`
  before a result-producing `if` even though Binaryen sank it into the `then`
  arm.

## Reduced Repro

```wat
(module
  (memory 1)
  (func $decref (param i32))
  (func (param i32 i32) (result i32)
    (local i64 i32 i32 i32 i64 i32 i32)
    (block $block1
      (block $block
        (return
          (if (result i32)
            (local.get 0)
            (then
              (local.get 1)
              (local.set 4)
              (br $block))
            (else
              (local.get 1)
              (local.set 5)
              (if
                (local.get 5)
                (then))
              (local.get 1)
              (i64.load offset=8)
              (local.set 6)
              (local.get 1)
              (i32.load offset=16)
              (local.set 7)
              (local.get 5)
              (call $decref)
              (local.get 7)
              (local.set 8)
              (if (result i32)
                (if (result i32)
                  (i64.ge_s (local.get 6) (i64.const 0))
                  (then (i64.le_s (local.get 6) (i64.const 4294967295)))
                  (else (i32.const 0)))
                (then
                  (local.set 2
                    (block (result i64)
                      (local.get 6)
                      (local.set 2)
                      (local.get 8)
                      (local.set 3)
                      (local.get 2)))
                  (br $block1))
                (else
                  (i32.const 9)))))))
        (i32.const 7)
        return)
      (local.get 2)
      i32.wrap_i64
      (local.set 3)
      (local.get 4)
      drop
      (local.get 3)))
```

Binaryen `wasm-opt --code-pushing -S` sinks `local.set 8` into the `then` arm of
that inner result-producing `if`.

Before the fix, Starshine kept the same region as:

- `LocalSet(5)`
- `If`
- `LocalSet(6)`
- `LocalSet(7)`
- `Call`
- `LocalSet(8)`
- `If`

After the fix, Starshine now matches Binaryen's structural move there:

- the pre-`if` root becomes `Nop`
- the target `then` arm begins with `LocalSet(8)`, then `LocalSet(2)`, then `Br`

## Diagnosis

- The old standalone `Func 1975` frontier was not another alias fence or SFA
  classification miss.
- The candidate local was still SFA, and the target `if` still read that local
  only in the `then` arm.
- The blocker was `cp_try_sink_into_if`'s condition barrier.
- That barrier merged the target `if` condition summary and then treated any
  `EFFECT_MASK_CONTROL` bit in that condition as a hard conflict.
- In this family the target condition is itself a nested result-producing `if`,
  so the condition summary carries control even though it does not touch the
  moved alias local.
- That made Starshine fail-closed on a Binaryen-matched sink surface.

## Kept Repository Change

- `src/passes/code_pushing.mbt` now clears the pure `EFFECT_MASK_CONTROL` bit
  from the temporary sink-condition barrier inside `cp_try_sink_into_if` after
  merging the target condition summary.
- The sink path still keeps the stronger barrier checks for:
  - local/global read-write conflicts
  - calls
  - throws
  - traps
  - memory/table writes
- So this change only readmits the pure nested-control condition family that the
  old barrier was over-blocking.

## Kept Regression Coverage

- `src/passes/code_pushing_test.mbt` now pins the reduced nested result-`if`
  condition sink directly.
- The regression proves two facts together:
  - the pre-target root becomes `Nop`
  - the target `then` arm begins with the moved alias set
- The test also validates lowering through `pass_test_run_pipeline(source, ["code-pushing"])`.

## Validation

- `moon fmt`
- `moon test src/passes`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260413a`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260413b`

## Practical Conclusion

- The sharper standalone `Func 1975` frontier from `0082` is now reduced and
  closed.
- The remaining work returns to the broader current-artifact/runtime picture,
  not this nested result-`if` condition sink family.
