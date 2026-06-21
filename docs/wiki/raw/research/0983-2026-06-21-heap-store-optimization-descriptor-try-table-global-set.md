# Heap Store Optimization Descriptor `try_table` Global-Set Fold

## Summary

Binaryen `version_130` folds a later same-field `struct.set` into a fresh `struct.new_desc` when the only intervening root is a non-throwing `try_table` body that performs an unrelated mutable `global.set`. Starshine already matched this descriptor-constructor extension of the `0927` / `0979` / `0980` non-throwing `try_table` global-set family, so this slice adds focused coverage and documentation only.

## Binaryen oracle

Probe file: `.tmp/hso-desc-try-global.wat`.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-desc-try-global.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-desc-try-global.opt.wat && \
grep -E "struct.set|struct.new_desc|try_table|global.set|global.get|i32.const" \
  .tmp/hso-desc-try-global.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the `try_table`, the unrelated mutable `global.set`, and the descriptor `global.get` operand.
- Binaryen removes the later `struct.set` and places the replacement field value directly in `struct.new_desc`.

Observed grep excerpt:

```text
(global $g (mut i32) (i32.const 0))
  (try_table (catch_all $block)
    (global.set $g
      (i32.const 7)
  (struct.new_desc $pair
    (i32.const 9)
    (i32.const 2)
    (global.get $desc)
```

## Starshine coverage

Added focused encoded-wasm coverage:

- `heap-store-optimization folds descriptor constructors across non-throwing try_table global stores`

The test constructs a descriptor-typed fresh struct, runs a non-throwing `try_table` whose body writes an unrelated mutable i32 global, then writes the same field. Starshine preserves `struct.new_desc`, `try_table`, and `global.set`, and removes the later `struct.set`, matching Binaryen behavior.

## Classification

This is coverage-only HSO-D/G evidence:

- HSO-D because the constructor is `struct.new_desc` with a descriptor operand.
- HSO-G because the fold depends on `trySwap(...)` legality across a `try_table`-wrapped root.

It does not generalize to throwing/catchable `try_table` bodies, same-effect roots, or arbitrary descriptor operands beyond this exact non-throwing unrelated-global-set shape.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'descriptor constructors across non-throwing try_table global stores'
```

Result:

```text
Total tests: 350, passed: 350, failed: 0.
```

No implementation behavior changed, so no native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if a later Binaryen release changes descriptor-constructor movement across `try_table`, if Starshine changes descriptor operand effect summaries, or if broader descriptor / `try_table` families reveal a same-shape mismatch not covered by this narrow probe.
