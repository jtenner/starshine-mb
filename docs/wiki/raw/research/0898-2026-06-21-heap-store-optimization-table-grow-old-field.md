# 0898 - Heap-store-optimization table-grow old-field coverage

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve the side effect of an overwritten constructor field whose original value is `table.grow`, when an unrelated mutable `global.set` appears before the later `struct.set`?

This follows `0897`, which covered the analogous `memory.grow` old-field family, and extends the HSO-D/G old-field matrix to table growth side effects.

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-table-grow-old-field.wat`.

Shape:

- construct `$tmp` with field `0` initialized by `ref.null func` and field `1` initialized by `table.grow (ref.null func) (i32.const 1)`;
- write unrelated mutable global `$g`;
- overwrite field `1` with `i32.const 42`;
- return the fresh local.

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-table-grow-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-table-grow-old-field.opt.wat && \
grep -E "table.grow|global.set|struct.new|struct.set|local.set|drop" \
  .tmp/hso-probe-table-grow-old-field.opt.wat
```

Local oracle was checked in this recursion with `wasm-opt --version`: `wasm-opt version 130 (version_130)`.

Result:

- Binaryen removed the later `struct.set`;
- Binaryen preserved the `table.grow` side effect under a `drop` in a value-producing block for the overwritten constructor field;
- Binaryen initialized field `1` directly with the later value `42`;
- Binaryen printed the unrelated `global.set` before the preserved constructor/local-set block.

Classification: this is a behavior-parity positive fold. Correct behavior preserves the old `table.grow` side effect while eliminating the redundant later `struct.set` when ordering permits it.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- test `heap-store-optimization folds table-grow old fields across unrelated global.set` builds the probed table-growth old-field shape;
- the test asserts optimized output still contains `table.grow` and `global.set`, but no longer contains `struct.set`.

The test was coverage-only: it passed on the first focused run, so no implementation change was required. Existing HSO old-field preservation and effect-order logic already matched Binaryen for this side-effectful table-growth old-field fold.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

First focused run after adding the test: `256/256` passed.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice added coverage/docs only and did not change pass behavior.

## Durable conclusion

HSO now has focused coverage for the table-growth counterpart to `0897`: `table.grow` old-field side effects can be preserved under `drop` in the constructor field replacement while the later `struct.set` disappears. This narrows the broader side-effectful old-field matrix without creating a Starshine-only boundary.

## Reopening criteria

Reopen this family if:

- a future HSO change drops the `table.grow` side effect from an overwritten constructor field;
- a future HSO change preserves the later `struct.set` for this exact safe unrelated-global shape without documenting a reason;
- same-family table blockers, descriptor/default variants, or nested wrapper variants show different Binaryen behavior;
- Binaryen changes the old-field preservation strategy for side-effectful table growth in a newer release oracle.
