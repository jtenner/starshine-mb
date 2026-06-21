# Heap-store-optimization call_ref constructor/table.set boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when the constructor has an effectful `call_ref` operand and an unrelated `table.set` occurs between the constructor assignment and the later store?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture: `.tmp/hso-probe-call-ref-table-set.wat`.

Shape:

- `$test` receives a nullable typed function reference.
- The fresh `struct.new` first field is produced by `call_ref` through `ref.as_non_null(local.get 0)`.
- The constructed struct is assigned to a local.
- An unrelated `table.set` writes a `funcref` table.
- A later `struct.set` writes field `1`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-table-set.wat -S \
  -o .tmp/hso-probe-call-ref-table-set.opt.wat
```

Inspection command:

```sh
grep -n "call_ref\|table.set\|struct.set\|struct.new" \
  .tmp/hso-probe-call-ref-table-set.opt.wat
```

Observed relevant output:

```text
12:   (struct.new $s
13:    (call_ref $callee_t
21:  (table.set $0
25:  (struct.set $s 1
```

## Finding

Binaryen preserved the `call_ref` constructor operand, the intervening `table.set`, and the later `struct.set`. It did not fold the later store into the constructor across the unrelated table write.

Classification: Binaryen behavior-parity negative/boundary, not a Starshine win and not an accepted non-goal. This extends the direct `call`, `call_indirect`, and prior `call_ref`/`global.set` constructor-operand no-swap family to an unrelated `table.set` blocker.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_ref constructor operands before unrelated table.set`

The test already passed before implementation changes, so this was a coverage-only slice. No native rebuild or direct compare was required because pass behavior did not change.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_ref constructor operands before unrelated table.set'
```

Result: `276/276` passed.

## Reopening criteria

Reopen if Binaryen changes this family to fold across unrelated table writes, if Starshine later moves `call_ref` before table side effects in this shape, or if a broader typed-function-reference control-flow implementation proves a narrower safe subcase with source-backed evidence.
