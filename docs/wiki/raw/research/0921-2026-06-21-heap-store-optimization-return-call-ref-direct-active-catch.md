# Heap-store-optimization direct return_call_ref active-catch dead set

Date: 2026-06-21

## Question

Does the direct `return_call_ref` set-value boundary from `0920` change when the fresh constructor assignment and later `struct.set` sit inside an active `try_table` catch region?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-return-call-ref-direct-active-catch.wat`.

Shape:

- `$test` receives a nullable typed function reference and returns `i32`.
- A `try_table (catch_all $done)` wraps the fresh `struct.new_default` assignment and later `struct.set`.
- The later `struct.set` value is a direct `return_call_ref` through `ref.as_non_null(local.get $f)`.
- A later `struct.get` reads `$s` after the catch block, but the tail-call path exits the current function before the store can execute.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-return-call-ref-direct-active-catch.wat -S \
  -o .tmp/hso-probe-return-call-ref-direct-active-catch.opt.wat
```

Inspection command:

```sh
grep -n "try_table\|return_call_ref\|struct.set\|struct.new\|struct.get" \
  .tmp/hso-probe-return-call-ref-direct-active-catch.opt.wat
```

Observed relevant Binaryen output:

```text
11:   (try_table (catch_all $done)
13:     (struct.new_default $pair)
15:    (struct.set $pair 0
17:     (return_call_ref $callee
25:  (struct.get $pair 0
```

## Finding

Binaryen preserves the `try_table` wrapper and the direct-root `struct.set` when the set value is a direct `return_call_ref`. This matches the direct-root behavior from `0920`, not the branch-valued active-catch positive from `0919`.

Starshine currently preserves the `try_table` wrapper and tail call but drops the dead `struct.set`, producing validating wasm. This is the active-catch counterpart of the narrow `0920` Starshine win: the direct `return_call_ref` exits the current function before the `struct.set` body can perform a store, and a tail call is not catchable by the local `try_table`. The classification does not apply to ordinary caught calls, `throw`, branch-valued stores with a reachable normal arm, descriptor branch results, or any shape where control can continue to the `struct.set`.

Classification: narrow better-than-Binaryen dead-store cleanup for a direct `return_call_ref` set value inside an active catch region.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization drops direct return_call_ref set values inside active catches`

The test already passed before implementation changes, so this was a coverage-and-classification slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'active-catch set-value'
```

Result: `281/281` passed.

## Reopening criteria

Reopen if Starshine output becomes invalid, if a future tail-call or exception semantic lets the local `try_table` catch this `return_call_ref`, if Binaryen starts deleting/folding this direct-root active-catch shape differently, or if a related active-catch typed-function-reference shape exposes a reachable store, catchable exit, or target-local read hazard.
