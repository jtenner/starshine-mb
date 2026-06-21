# 0896 - Heap-store-optimization table-get old-field coverage

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve an overwritten constructor field whose original value is a potentially trapping `table.get`, when an unrelated mutable `global.set` appears before the later `struct.set`?

This extends the HSO-D/G old-field preservation trap matrix beyond integer div/rem (`0892`), non-saturating float-to-int truncation (`0893`), `ref.as_non_null` (`0894`), and `i32.load` (`0895`).

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-table-get-old-field.wat`.

Shape:

- construct `$x` with field `0` initialized by `table.get $t (i32.const 0)`;
- write unrelated mutable global `$g`;
- overwrite field `0` with `ref.null func`;
- return the fresh local.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features .tmp/hso-probe-table-get-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-table-get-old-field.opt.wat && \
grep -E "table.get|global.set|struct.new|struct.set|local.set" \
  .tmp/hso-probe-table-get-old-field.opt.wat
```

Result:

- local oracle: `wasm-opt version 130 (version_130)`;
- Binaryen preserved the constructor `local.set` with the `table.get` old field;
- Binaryen kept the unrelated `global.set` before the later `struct.set`;
- Binaryen left the later `struct.set` instead of folding and dropping the potentially trapping old field.

Classification: this is a behavior-parity boundary. A fold that deletes the old `table.get` would remove a possible table bounds trap and would be wrong. This is not a Starshine-win candidate.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- helper `hso_funcref_table_global_test_module(...)` builds a funcref-field struct fixture with one funcref table and an unrelated mutable i32 global;
- test `heap-store-optimization keeps trapping table-get old fields before unrelated global.set` builds the probed shape with an overwritten field-0 `table.get` old field;
- the test asserts optimized output still contains `table.get`, `global.set`, and `struct.set`, with `global.set` before `struct.set`.

The test was coverage-only: it passed on the first focused run, so no implementation change was required. Existing HSO trap/effect handling already treats table reads as trapping strongly enough for this overwritten-old-field/global-set shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

First focused run after adding the test: `254/254` passed.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice added coverage/docs only and did not change pass behavior.

## Durable conclusion

HSO now has focused table-trap old-field coverage in addition to integer div/rem (`0892`), non-saturating trunc (`0893`), `ref.as_non_null` (`0894`), and memory load (`0895`) old-field coverage. Binaryen and Starshine both preserve the trapping `table.get` old field and keep the later `struct.set` in the probed unrelated-global-set shape.

## Reopening criteria

Reopen this family if:

- a future HSO change drops a potentially trapping table read from an overwritten constructor field;
- broader table old-field shapes such as nonzero/out-of-range indices, multiple tables, or non-funcref table element types show different Binaryen behavior;
- Binaryen moves table-trap old-field treatment into a broader fold that preserves traps by a different explicit mechanism.
