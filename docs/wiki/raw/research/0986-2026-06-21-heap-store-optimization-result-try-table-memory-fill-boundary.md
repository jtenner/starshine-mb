# Heap Store Optimization Result `try_table` Memory-Fill Boundary

## Summary

Binaryen `version_130` preserves a later same-field `struct.set` when a `memory.size` constructor operand would need to cross a result-typed `try_table` body that performs `memory.fill`. Starshine matches after the `0985` wrapper fix: it keeps the result `try_table`, the `memory.fill`, the original constructor local, and the later `struct.set`.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-memory-fill.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-memory-fill.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-memory-fill.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the `struct.new`, `memory.size`, result `try_table`, `memory.fill`, and later `struct.set`.
- This is the result-typed counterpart of the same-effect `try_table` / bulk-memory boundary from `0912`.

Observed optimized shape:

```text
(local.set $r
  (struct.new $s
    (i32.const 2)
    (memory.size)))
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (memory.fill ...)
      (i32.const 4))))
(struct.set $s 0
  (local.get $r)
  (i32.const 9))
```

## Starshine coverage

Focused coverage:

- `heap-store-optimization keeps memory.size constructors before result try_table memory fills`

Starshine already matched the Binaryen no-fold boundary after the `0985` wrapper-preservation fix. No implementation behavior changed in this slice.

## Classification

This is HSO-G coverage with HSO-F wrapper/control relevance:

- The `try_table` body is result-typed and value-dropped, which previously exposed wrapper-peeling risk.
- The body performs `memory.fill`, so Binaryen treats the same memory-effect family as an ordering barrier for the `memory.size` constructor operand and leaves the later `struct.set` in place.

This is not a Starshine win and not a non-goal: it is a covered Binaryen boundary that Starshine now matches.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table memory fills'
```

Result:

```text
Total tests: 353, passed: 353, failed: 0.
```

No native rebuild or direct compare was required for this coverage-only slice.

## Reopening criteria

Reopen if Binaryen starts folding `memory.size` constructor operands across result-typed `try_table` bodies with same-memory effects, or if Starshine changes wrapper movement around `try_table` roots in a way that can invalidate catch-label lowering.
