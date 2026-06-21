# 0895 - Heap-store-optimization memory-load old-field coverage

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve an overwritten constructor field whose original value is a trapping `i32.load`, when an unrelated mutable `global.set` appears before the later `struct.set`?

This is an HSO-D/G old-field preservation variant beyond the numeric arithmetic/conversion traps covered by `0892` and `0893` and the reference trap covered by `0894`.

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-load-old-field.wat`.

Shape:

- construct `$s` with field `0` initialized by `i32.load(i32.const 0)`;
- write unrelated mutable global `$g`;
- overwrite field `0` with `i32.const 42`;
- read the fresh local's field `0`.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features .tmp/hso-probe-load-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-load-old-field.opt.wat && \
grep -E "i32.load|global.set|struct.new|struct.set|local.set|struct.get" \
  .tmp/hso-probe-load-old-field.opt.wat
```

Result:

- local oracle: `wasm-opt version 130 (version_130)`;
- Binaryen preserved the constructor `local.set` with the `i32.load` old field;
- Binaryen kept the unrelated `global.set` before the later `struct.set`;
- Binaryen left the later `struct.set` instead of folding and dropping the potentially trapping old field.

Classification: this is a behavior-parity boundary. A fold that deletes the old `i32.load` would remove a possible memory trap and would be wrong. This is not a Starshine-win candidate.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- test `heap-store-optimization keeps trapping memory-load old fields before unrelated global.set` builds the probed shape with an overwritten field-0 `i32.load` old field;
- the test asserts that optimized output still contains `i32.load`, `global.set`, and `struct.set`, with `global.set` before `struct.set`.

The test was coverage-only: it passed on the first focused run, so no implementation change was required. Existing HSO trap/effect handling already treats memory loads as trapping strongly enough for this overwritten-old-field/global-set shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

First focused run after adding the test: `253/253` passed.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice added coverage/docs only and did not change pass behavior.

## Durable conclusion

HSO now has focused memory-trap old-field coverage in addition to integer div/rem (`0892`), non-saturating trunc (`0893`), and `ref.as_non_null` (`0894`) old-field coverage. Binaryen and Starshine both preserve the trapping `i32.load` old field and keep the later `struct.set` in the probed unrelated-global-set shape.

## Reopening criteria

Reopen this family if:

- a future HSO change drops a potentially trapping memory load from an overwritten constructor field;
- broader memory-load old-field shapes such as different memory widths or memory64 show different Binaryen behavior;
- Binaryen moves memory-trap old-field treatment into a broader fold that preserves traps by a different explicit mechanism.
