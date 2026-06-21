# Heap Store Optimization Result `try_table` Cross-Store Fold

## Summary

Binaryen `version_130` folds later same-field `struct.set` values into fresh constructors across result-typed `try_table` wrappers when the wrapper body performs a cross-family ordinary store root: `memory.size` across `table.set`, and `table.size` across `i32.store`. Starshine already matches after the `0985` wrapper fix: it preserves the result `try_table` wrapper and store root, folds the later value into `struct.new`, and removes the later `struct.set`.

This narrows the older ordinary `try_table` store boundary from `0910`/`0911`: the void `try_table` forms in those notes remain no-fold boundaries, while these result-typed, value-dropped cross-family ordinary-store roots fold like the direct cross-family store positives from `0844`.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-cross-store.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-cross-store.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-cross-store.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- In `$memory_size_table_set`, Binaryen preserves the result `try_table`, preserves `table.set`, keeps the still-live `memory.size` constructor operand, folds `i32.const 9` into field `1`, and removes the later `struct.set`.
- In `$table_size_i32_store`, Binaryen preserves the result `try_table`, preserves `i32.store`, keeps the still-live `table.size` constructor operand, folds `i32.const 9` into field `1`, and removes the later `struct.set`.

Observed optimized shape for the memory-size/table-store half:

```text
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (table.set ...)
      (i32.const 4))))
(local.set $r
  (struct.new $s
    (memory.size)
    (i32.const 9)))
```

The table-size/memory-store half has the same shape with `i32.store` in the wrapper and `table.size` in the constructor.

## Starshine coverage

Focused coverage:

- `heap-store-optimization folds memory.size constructors across result try_table table stores`
- `heap-store-optimization folds table.size constructors across result try_table memory stores`

Starshine already matched the Binaryen fold behavior after the `0985` wrapper-preservation fix. No implementation behavior changed in this slice.

## Classification

This is HSO-G coverage with HSO-F wrapper/control relevance:

- The `try_table` body is result-typed and value-dropped, keeping the wrapper-sensitive lowering surface covered.
- The ordinary store roots are cross-family with the still-live constructor size operands, so Binaryen allows the fold in this result-typed wrapper shape.
- This is not a Starshine win and not a non-goal: it is a covered Binaryen positive that Starshine matches.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table.*stores'
```

Result:

```text
Total tests: 359, passed: 359, failed: 0.
```

No native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if Binaryen changes result-typed `try_table` cross-store handling to preserve the later `struct.set`, if Binaryen extends the fold to the older void `try_table` store forms from `0910`/`0911`, or if Starshine changes wrapper movement around `try_table` roots in a way that can invalidate catch-label lowering.
