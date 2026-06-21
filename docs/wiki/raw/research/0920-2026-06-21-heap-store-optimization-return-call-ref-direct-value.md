# Heap-store-optimization direct return_call_ref set-value boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a later fresh-struct `struct.set` whose value is a direct `return_call_ref`, rather than an `if` branch that sometimes returns a normal value?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-return-call-ref-later-value.wat`.

Shape:

- `$test` receives a nullable typed function reference and returns `i32`.
- A fresh `struct.new_default` is assigned to local `$s`.
- A later `struct.set` targets `$s`, but its value is a direct `return_call_ref` through `ref.as_non_null(local.get $f)`.
- A later `struct.get` reads `$s`, but that code is unreachable if the tail call exits normally.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-return-call-ref-later-value.wat -S \
  -o .tmp/hso-probe-return-call-ref-later-value.opt.wat
```

Inspection command:

```sh
grep -n "return_call_ref\|struct.set\|struct.new\|struct.get" \
  .tmp/hso-probe-return-call-ref-later-value.opt.wat
```

Observed relevant Binaryen output:

```text
11:   (struct.new_default $pair)
13:  (struct.set $pair 0
15:   (return_call_ref $callee
21:  (struct.get $pair 0
```

## Finding

Binaryen preserves the direct-root `struct.set` when the set value is a direct `return_call_ref`. This differs from the branch-valued `return_call_ref` positives in `0918` and `0919`, where Binaryen folds the reachable normal arm into the constructor while preserving the external tail-call branch.

Starshine currently removes the direct-root `struct.set` and emits validating wasm that preserves the `return_call_ref`. This is a narrow Starshine-win boundary: the direct `return_call_ref` exits the current function before the `struct.set` can execute, so removing the dead store cannot change the function's observable result, traps, or heap state. The residual later `struct.get` remains unreachable. This is not a general license to remove ordinary branch-valued, catchable, trapping, or target-local-reading stores; those remain governed by the HSO-F/H boundaries documented elsewhere.

Classification: narrow better-than-Binaryen dead-store cleanup for a direct `return_call_ref` set value.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization drops direct return_call_ref set values as dead stores`

The test already passed before implementation changes, so this was a coverage-and-classification slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'direct return_call_ref set-value'
```

Result: `280/280` passed.

## Reopening criteria

Reopen if Starshine output becomes invalid, if the direct `return_call_ref` value gains any path that can continue to the `struct.set`, if Binaryen starts removing or folding this direct-root shape in a way that changes the classification, or if a related direct-root tail-call/catch shape exposes a reachable store or in-function control hazard.
