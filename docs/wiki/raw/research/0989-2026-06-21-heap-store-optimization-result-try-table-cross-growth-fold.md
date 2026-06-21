# Heap Store Optimization Result `try_table` Cross-Growth Fold

## Summary

Binaryen `version_130` folds later same-field `struct.set` values into fresh constructors across result-typed `try_table` wrappers when the wrapper body performs a cross-family growth root: `memory.size` across `table.grow`, and `table.size` across `memory.grow`. Starshine already matches after the `0985` wrapper fix: it preserves the result `try_table` wrapper and growth root, folds the later value into `struct.new`, and removes the later `struct.set`.

This narrows the older ordinary `try_table` cross-growth boundary from `0913`: the void `try_table` forms in that note remain no-fold boundaries, while these result-typed, value-dropped growth roots fold like the direct cross-family growth positives from `0888`.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-cross-growth-field1.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-cross-growth-field1.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-cross-growth-field1.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- In `$memory_size_table_grow`, Binaryen preserves the result `try_table`, preserves `table.grow`, keeps the still-live `memory.size` constructor operand, folds `i32.const 9` into field `1`, and removes the later `struct.set`.
- In `$table_size_memory_grow`, Binaryen preserves the result `try_table`, preserves `memory.grow`, keeps the still-live `table.size` constructor operand, folds `i32.const 9` into field `1`, and removes the later `struct.set`.

Observed optimized shape for the memory-size/table-growth half:

```text
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (table.grow ...))))
(local.set $r
  (struct.new $s
    (memory.size)
    (i32.const 9)))
```

The table-size/memory-growth half has the same shape with `memory.grow` in the wrapper and `table.size` in the constructor.

## Starshine coverage

Focused coverage:

- `heap-store-optimization folds memory.size constructors across result try_table table.grow`
- `heap-store-optimization folds table.size constructors across result try_table memory.grow`

Starshine already matched the Binaryen fold behavior after the `0985` wrapper-preservation fix. No implementation behavior changed in this slice.

## Classification

This is HSO-G coverage with HSO-F wrapper/control relevance:

- The `try_table` body is result-typed and value-dropped, keeping the wrapper-sensitive lowering surface covered.
- The growth roots are cross-family with the still-live constructor size operands, so Binaryen allows the fold in this result-typed wrapper shape.
- This is not a Starshine win and not a non-goal: it is a covered Binaryen positive that Starshine matches.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table.*grow'
```

Result:

```text
Total tests: 357, passed: 357, failed: 0.
```

No native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if Binaryen changes result-typed `try_table` cross-growth handling to preserve the later `struct.set`, if Binaryen extends the fold to the older void `try_table` growth forms from `0913`, or if Starshine changes wrapper movement around `try_table` roots in a way that can invalidate catch-label lowering.
