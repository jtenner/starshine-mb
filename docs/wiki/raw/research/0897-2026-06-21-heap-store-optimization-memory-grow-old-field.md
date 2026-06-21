# 0897 - Heap-store-optimization memory-grow old-field coverage

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve the side effect of an overwritten constructor field whose original value is `memory.grow`, when an unrelated mutable `global.set` appears before the later `struct.set`?

This extends the HSO-D/G old-field matrix beyond pure preservation/no-fold trap cases (`0892` through `0896`) into a side-effectful old-field value that Binaryen can still fold by preserving the old-field effect explicitly.

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-memory-grow-old-field.wat`.

Shape:

- construct `$x` with field `0` initialized by `memory.grow (i32.const 1)`;
- write unrelated mutable global `$g`;
- overwrite field `0` with `i32.const 42`;
- read field `0` from the fresh local.

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-memory-grow-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-memory-grow-old-field.opt.wat && \
grep -E "memory.grow|global.set|struct.new|struct.set|local.set" \
  .tmp/hso-probe-memory-grow-old-field.opt.wat
```

Local oracle was checked in the same recursion with `wasm-opt --version`: `wasm-opt version 130 (version_130)`.

Result:

- Binaryen removed the later `struct.set`;
- Binaryen preserved the `memory.grow` side effect under a `drop` in a value-producing block for the overwritten constructor field;
- Binaryen initialized field `0` directly with the later value `42`;
- Binaryen moved the unrelated `global.set` before the preserved constructor/local-set block in the printed output.

Classification: this is a behavior-parity positive fold, not a generic license to drop old fields. A correct implementation must preserve the `memory.grow` side effect while eliminating the redundant later `struct.set` when ordering permits it.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- test `heap-store-optimization folds memory-grow old fields across unrelated global.set` builds the probed shape with an overwritten `memory.grow` old field;
- the test asserts optimized output still contains `memory.grow` and `global.set`, but no longer contains `struct.set`.

The test was coverage-only: it passed on the first focused run, so no implementation change was required. Existing HSO old-field preservation and effect-order logic already matched Binaryen for this side-effectful old-field fold.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

First focused run after adding the test: `255/255` passed.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice added coverage/docs only and did not change pass behavior.

## Durable conclusion

HSO now has focused coverage for a side-effectful old field that Binaryen folds while preserving the old side effect: `memory.grow` can be kept under `drop` in the constructor field replacement while the later `struct.set` disappears. This complements the no-fold trapping old-field coverage from `0892` through `0896`.

## Reopening criteria

Reopen this family if:

- a future HSO change drops the `memory.grow` side effect from an overwritten constructor field;
- a future HSO change preserves the later `struct.set` for this exact safe unrelated-global shape without documenting a reason;
- broader side-effectful old-field shapes such as `table.grow`, same-family memory blockers, or nested wrapper variants show different Binaryen behavior;
- Binaryen changes the old-field preservation strategy for side-effectful values in a newer release oracle.
