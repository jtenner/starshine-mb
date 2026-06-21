# Heap Store Optimization Result `try_table` Table-Fill Boundary

## Summary

Binaryen `version_130` preserves a later same-field `struct.set` when a `table.size` constructor operand would need to cross a result-typed `try_table` body that performs `table.fill`. Starshine already matches after the `0985` wrapper fix: it keeps the result `try_table`, the `table.fill`, the original constructor local, and the later `struct.set`.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-table-fill.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-table-fill.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-table-fill.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the `struct.new`, `table.size`, result `try_table`, `table.fill`, and later `struct.set`.
- This is the table-side result-typed counterpart of the same-effect `try_table` / `memory.fill` boundary from `0986`, and of the ordinary `try_table` same-effect table boundary from `0912`.

Observed optimized shape:

```text
(local.set $r
  (struct.new $s
    (table.size $0)
    (i32.const 2)))
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (table.fill ...)
      (i32.const 4))))
(struct.set $s 1
  (local.get $r)
  (i32.const 9))
```

## Starshine coverage

Focused coverage:

- `heap-store-optimization keeps table.size constructors before result try_table table fills`

Starshine already matched the Binaryen no-fold boundary after the `0985` wrapper-preservation fix. No implementation behavior changed in this slice.

## Classification

This is HSO-G coverage with HSO-F wrapper/control relevance:

- The `try_table` body is result-typed and value-dropped, keeping the wrapper-sensitive lowering surface covered.
- The body performs `table.fill`, so Binaryen treats the same table-effect family as an ordering barrier for the `table.size` constructor operand and leaves the later `struct.set` in place.

This is not a Starshine win and not a non-goal: it is a covered Binaryen boundary that Starshine matches.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table table fills'
```

Result:

```text
Total tests: 355, passed: 355, failed: 0.
```

No native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if Binaryen starts folding `table.size` constructor operands across result-typed `try_table` bodies with same-table effects, or if Starshine changes wrapper movement around `try_table` roots in a way that can invalidate catch-label lowering.
