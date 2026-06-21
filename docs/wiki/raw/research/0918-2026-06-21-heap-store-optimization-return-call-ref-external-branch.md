# Heap-store-optimization return_call_ref external-branch fold

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new_default` when the replacement value contains a branch that exits the function through `return_call_ref`?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-return-call-ref-branch.wat`.

Shape:

- `$run` receives a nullable typed function reference.
- A fresh `struct.new_default` is assigned to local `$s`.
- The later `struct.set` value is an `if (result i32)`.
- The then arm does `ref.as_non_null(local.get 0)` and exits the function with `return_call_ref`.
- The else arm produces a normal `i32.const 42` value.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-return-call-ref-branch.wat -S \
  -o .tmp/hso-probe-return-call-ref-branch.opt.wat
```

Inspection command:

```sh
grep -n "return_call_ref\|struct.set\|struct.new\|ref.as_non_null" \
  .tmp/hso-probe-return-call-ref-branch.opt.wat
```

Observed relevant output:

```text
11:   (struct.new $pair
15:      (return_call_ref $callee
16:       (ref.as_non_null
```

## Finding

Binaryen folded the later `struct.set` into the fresh constructor while preserving the `return_call_ref` branch in the moved value. This matches the existing ordinary `return_call` external-exit positive: an exit that leaves the current function does not create an in-function path that can skip the local assignment and continue to read the target local.

Classification: Binaryen behavior-parity positive for the typed-function-reference tail-call variant, not a Starshine win or non-goal.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds external return_call_ref branches into struct.new`

The test already passed before implementation changes, so this was a coverage-only slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'external return_call_ref branches'
```

Result: `278/278` passed.

## Reopening criteria

Reopen if Binaryen stops folding this function-external `return_call_ref` family, if Starshine later preserves the `struct.set` or drops/reorders the `return_call_ref` branch, or if a narrower typed-function-reference tail-call rule is needed to distinguish external exits from in-function branch/catch hazards.
