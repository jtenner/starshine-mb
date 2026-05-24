# SGO try_table ref.is_null select read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` by extending no-catch `try_table (result funcref)` read-only-to-write handling through `ref.is_null` when that boolean feeds a pure-constant-sibling `select` condition. This is a narrow source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, then used as the condition of a pure-constant-sibling `select` guarding a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the same `ref.is_null` + select condition in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed the traffic.

Observed guardrail:

- the catch-bearing `try_table` variant preserved mutable global traffic.

## Starshine implementation

Implemented a narrow helper in `src/passes/simplify_globals_optimizing.mbt`:

- requires a no-catch `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`;
- recognizes the parser/lowering shape where the two selected constants precede the `try_table`, followed by `ref.is_null`, then `select`;
- reuses the existing safe-body reader and same-global constant-set recognition;
- supports both no-else same-global constant-set guards and exact `if return; set` / block-wrapped set tails;
- leaves catch-bearing wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null select guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null select if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null select guards conservative`

The first TDD run failed the two no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Non-claims

This does not add caught `try_table` handling, broader reference/GC/ref-cast handling, arbitrary select value positions, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins.
