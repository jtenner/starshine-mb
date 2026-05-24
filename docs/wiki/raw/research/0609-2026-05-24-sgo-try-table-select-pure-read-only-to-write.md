# SGO try_table select pure read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` by extending the no-catch `try_table` + `select` read-only-to-write slice from [`0608`](./0608-2026-05-24-sgo-try-table-select-read-only-to-write.md) through one or more already-supported pure condition consumers after the `select`. This is a narrow source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result i32)` feeding a pure-constant-sibling `select`, then `i32.eqz`, then the same-global constant `global.set`: Binaryen made `$g` immutable and removed fake global traffic;
- the same select result feeding compare-with-const before the same-global set: Binaryen made `$g` immutable and removed the traffic;
- the same select + `i32.eqz` guard in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed the traffic.

Observed guardrail:

- the catch-bearing `try_table` select + `i32.eqz` condition preserved mutable global traffic.

## Starshine implementation

Implemented a narrow pure-post-select helper in `src/passes/simplify_globals_optimizing.mbt`:

- requires a no-catch `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`;
- recognizes the same pure-constant-sibling select stack positions as 0608;
- scans only through the existing supported external pure-condition stack transition family after the `select`;
- reuses the existing safe-body reader and same-global constant-set recognition;
- supports both no-else same-global constant-set guards and exact `if return; set` / block-wrapped set tails;
- leaves catch-bearing wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table select eqz guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select eqz if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table select eqz guards conservative`

The first TDD run failed the three no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Non-claims

This does not add caught `try_table` handling, arbitrary select/control-transfer broadening, calls, trapping/effectful sibling operands, relaxed SIMD, descriptor/GC/ref-cast operations, or broader `try_table` join reasoning.
