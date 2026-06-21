# Heap-store-optimization call_ref old-field/table.set boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when the overwritten constructor field was produced by `call_ref` and an unrelated `table.set` occurs between the constructor assignment and the later overwrite?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-call-ref-old-field-table-set.wat`.

Shape:

- `$test` receives a nullable typed function reference.
- Field `0` in the fresh `struct.new` is produced by `call_ref` through `ref.as_non_null(local.get 0)`.
- The constructed struct is assigned to a local.
- An unrelated `table.set` writes a `funcref` table.
- A later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-old-field-table-set.wat -S \
  -o .tmp/hso-probe-call-ref-old-field-table-set.opt.wat
```

Inspection command:

```sh
grep -n "call_ref\|table.set\|struct.set\|struct.new" \
  .tmp/hso-probe-call-ref-old-field-table-set.opt.wat
```

Observed relevant output:

```text
12:   (struct.new $s
13:    (call_ref $callee_t
21:  (table.set $0
25:  (struct.set $s 0
```

## Finding

Binaryen preserved the `call_ref` old-field producer, the intervening `table.set`, and the later `struct.set`. It did not preserve the old call under `drop` and remove the store.

Classification: Binaryen behavior-parity negative/boundary, not a Starshine win and not an accepted non-goal. This complements `0916` by covering the overwritten-old-field variant of the typed-function-reference call root across an unrelated table write.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_ref old fields before unrelated table.set`

The test already passed before implementation changes, so this was a coverage-only slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_ref old fields before unrelated table.set'
```

Result: `277/277` passed.

## Reopening criteria

Reopen if Binaryen changes this family to preserve the old `call_ref` separately while removing the later store, if Starshine later drops or reorders the old `call_ref` in this shape, or if broader typed-function-reference old-field handling finds a narrower source-backed safe subcase.
