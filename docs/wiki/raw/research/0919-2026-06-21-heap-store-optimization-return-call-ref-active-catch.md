# Heap-store-optimization return_call_ref active-catch fold

Date: 2026-06-21

## Question

Does Binaryen `version_130` still fold a later `struct.set` into a fresh `struct.new_default` when the replacement value contains a `return_call_ref` branch inside an active `try_table` catch region?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-return-call-ref-active-catch.wat`.

Shape:

- `$run` receives a nullable typed function reference.
- A `try_table` with `catch_all` wraps the fresh constructor assignment and later store.
- The later `struct.set` value is an `if (result i32)`.
- The then arm does `ref.as_non_null(local.get 0)` and exits the function with `return_call_ref`.
- The else arm produces a normal `i32.const 42` value.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-return-call-ref-active-catch.wat -S \
  -o .tmp/hso-probe-return-call-ref-active-catch.opt.wat
```

Inspection command:

```sh
grep -n "try_table\|return_call_ref\|struct.set\|struct.new\|ref.as_non_null" \
  .tmp/hso-probe-return-call-ref-active-catch.opt.wat
```

Observed relevant output:

```text
13:   (try_table (catch_all $exit)
15:     (struct.new $pair
19:        (return_call_ref $callee
20:         (ref.as_non_null
```

## Finding

Binaryen folded the later `struct.set` into the fresh constructor even inside an active catch region, while preserving the `try_table` wrapper and the `return_call_ref` branch. This matches the previously covered ordinary `return_call` active-catch positive: a tail call that exits the current function does not behave like a catchable in-function throw/call for HSO's skip-local-set hazard.

Classification: Binaryen behavior-parity positive for the typed-function-reference active-catch tail-call variant, not a Starshine win or non-goal.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds return_call_ref branches inside active catches`

The test already passed before implementation changes, so this was a coverage-only slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'return_call_ref branches inside active catches'
```

Result: `279/279` passed.

## Reopening criteria

Reopen if Binaryen stops folding this active-catch `return_call_ref` family, if Starshine later preserves the `struct.set` or treats `return_call_ref` as an in-function catch hazard, or if additional typed-function-reference tail-call/catch variants reveal a narrower safety rule.
