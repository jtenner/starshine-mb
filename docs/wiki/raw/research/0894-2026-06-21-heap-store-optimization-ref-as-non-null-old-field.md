# 0894 - Heap-store-optimization ref.as_non_null old-field coverage

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve an overwritten constructor field whose original value is a trapping `ref.as_non_null`, when an unrelated mutable `global.set` appears before the later `struct.set`?

This is an HSO-D/G old-field preservation variant beyond the numeric trap families covered by `0892` and `0893`.

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-ref-as-non-null-old-field.wat`.

Shape:

- construct `$pair` with field `0` initialized by `ref.as_non_null(global.get $r)`;
- write unrelated mutable global `$g`;
- overwrite field `0` with `ref.i31(7)`;
- return the fresh local.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features .tmp/hso-probe-ref-as-non-null-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-ref-as-non-null-old-field.opt.wat && \
grep -E "ref.as_non_null|global.set|struct.new|struct.set|local.set|ref.i31|global.get" \
  .tmp/hso-probe-ref-as-non-null-old-field.opt.wat
```

Result:

- local oracle: `wasm-opt version 130 (version_130)`;
- Binaryen preserved the constructor `local.set` with `ref.as_non_null(global.get $r)`;
- Binaryen kept the unrelated `global.set` before the later `struct.set`;
- Binaryen left the later `struct.set` instead of folding and dropping the potentially trapping old field.

Classification: this is a behavior-parity boundary. A fold that deletes `ref.as_non_null` would remove a possible null trap and would be wrong. This is not a Starshine-win candidate.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- helper `hso_i31ref_memory_global_test_module(...)` builds a small struct with a mutable `(ref null i31)` field plus mutable `i32` and nullable-i31 globals;
- test `heap-store-optimization keeps ref.as_non_null constructor operands before unrelated global.set` asserts that optimized output still contains `ref.as_non_null`, `global.set`, and `struct.set`, with `global.set` before `struct.set`.

The test was coverage-only: it passed on the first focused run, so no implementation change was required. Existing HSO trap/effect handling already treated `ref.as_non_null` as trapping strongly enough for this old-field/global-set shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `252/252` passed.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice added coverage/docs only and did not change pass behavior.

## Durable conclusion

HSO now has focused reference-trap old-field coverage in addition to integer div/rem (`0892`) and non-saturating trunc (`0893`) old-field coverage. Binaryen and Starshine both preserve the trapping `ref.as_non_null` old field and keep the later `struct.set` in the probed unrelated-global-set shape.

## Reopening criteria

Reopen this family if:

- a future HSO change drops `ref.as_non_null` from an overwritten constructor field;
- broader reference-trapping old-field shapes such as `ref.cast` become locally representable and show different Binaryen behavior;
- Binaryen moves `ref.as_non_null` old-field treatment into a broader fold that preserves traps by a different explicit mechanism.
