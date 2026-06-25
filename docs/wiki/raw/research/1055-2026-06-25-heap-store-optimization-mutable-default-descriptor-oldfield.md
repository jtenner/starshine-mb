---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1022-2026-06-21-heap-store-optimization-default-desc-catchable-later-field-result-try-table-store-boundary.md
  - ./1054-2026-06-25-heap-store-optimization-profile-direct-call-result-oldfield.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO mutable default-descriptor result-wrapper old-field boundary

Question: does the default-descriptor catchable result-wrapper old-field boundary from `1022` also hold when the descriptor global is mutable?

## Answer

Yes. A local Binaryen `version_130` probe with `(global $desc (mut (ref (exact $descT))))` preserved the `struct.new_default_desc`, mutable descriptor `global.get`, the call-valued first `struct.set` to field `0`, the catchable result-typed `try_table` / direct-call `struct.set` to field `1`, and the later pure same-field `struct.set` to field `0`.

Starshine already matches this conservative boundary. This is useful because the immutable `1022` boundary was about a catchable result-wrapper store value blocking a later pure same-field fold; mutability adds the descriptor-read ordering hazard from the mutable descriptor families. The focused test keeps this default-descriptor + mutable descriptor + old-field side-effect combination explicit rather than relying on the separate non-default mutable descriptor coverage.

## Binaryen probe

Probe file:

- `.tmp/hso-default-desc-mutable-result-try-oldfield-call-moved-const-catchall.wat`

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-default-desc-mutable-result-try-oldfield-call-moved-const-catchall.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-default-desc-mutable-result-try-oldfield-call-moved-const-catchall.binaryen.wat

grep -nE "struct.new_default_desc|struct.new_desc|struct.set|try_table|call|global.get|drop" \
  .tmp/hso-default-desc-mutable-result-try-oldfield-call-moved-const-catchall.binaryen.wat
```

Observed markers: `struct.new_default_desc`, mutable descriptor `global.get`, three `struct.set` roots, `try_table`, and both helper calls remain. Binaryen does not fold the later pure store through the catchable result-wrapper/default-descriptor sequence.

## Starshine coverage

Added:

- `heap-store-optimization keeps mutable default descriptor stores before catchable result try_table old fields`

The test uses the same shape with a mutable descriptor import. It asserts that Starshine preserves `struct.new_default_desc`, `global.get`, `try_table`, helper calls, and `struct.set` roots.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'mutable default descriptor'
```

Result: passed (`415/415` package-file count).

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `415/415` passed.

```sh
moon fmt
```

Result: passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed/no work to do.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-default-desc-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and reopening criteria

Classification: source-backed Binaryen boundary, Starshine match. Mutable default-descriptor result-wrapper old-field chains keep their stores; this is not an output-shape exception.

Reopen if Binaryen starts folding this mutable default-descriptor shape, if Starshine moves the mutable descriptor read or old-field call across the catchable wrapper, or when adding generated coverage for the default/mutable descriptor call-result siblings.
