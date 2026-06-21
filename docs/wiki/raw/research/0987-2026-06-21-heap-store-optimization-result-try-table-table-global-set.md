# Heap Store Optimization Result `try_table` Table-Size Global-Set Fold

## Summary

Binaryen `version_130` folds the table-side counterpart of `0985`: a later same-field `struct.set` can fold into a `struct.new` whose constructor operand is `table.size` when the intervening result-typed, non-throwing `try_table` only writes an unrelated mutable global and returns a dropped value. Starshine already matches after the `0985` wrapper fix.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-table-global.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-table-global.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-table-global.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the result `try_table`, the unrelated mutable `global.set`, and the still-live `table.size` constructor operand.
- Binaryen folds `i32.const 9` into field `1` of `struct.new` and removes the later `struct.set`.

Observed optimized shape:

```text
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (global.set $g (i32.const 3))
      (i32.const 4))))
(local.set $r
  (struct.new $s
    (table.size $0)
    (i32.const 9)))
```

## Starshine coverage

Focused coverage:

- `heap-store-optimization folds table.size constructors across result try_table global stores`

Starshine already matched the Binaryen fold: it preserves the `drop(try_table(result ...))` catch-target wrapper, preserves `global.set`, folds the later field value into the constructor, and removes `struct.set`.

## Classification

This is HSO-G coverage with HSO-F wrapper/control relevance:

- HSO-G because it is the table-side `trySwap(...)` legality counterpart of the `0985` result-typed `try_table` / unrelated-global-set fold.
- HSO-F because preserving the `try_table` catch-target wrapper remains necessary for valid lowering.

This is not a Starshine win and not a non-goal: it is covered Binaryen behavior that Starshine matches.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table global stores'
```

Result:

```text
Total tests: 354, passed: 354, failed: 0.
```

No native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if Binaryen stops folding table-size constructor operands across result-typed non-throwing `try_table` bodies with unrelated global writes, or if Starshine wrapper movement around nested `try_table` roots changes enough to risk invalid catch-label lowering.
