# SGO try_table ref.is_null select reverse compare read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0611`](./0611-2026-05-24-sgo-try-table-ref-is-null-select-read-only-to-write.md) and [`0612`](./0612-2026-05-24-sgo-try-table-ref-is-null-select-pure-read-only-to-write.md): no-catch `try_table (result funcref)` through `ref.is_null` into a pure-constant-sibling `select` condition may also feed the leading-constant reverse compare-with-const self-guard shape. This remains a small source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, used as a pure-constant-sibling `select` condition, where the select result is the second operand of `i32.eq` against a leading constant before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the same reverse-compare guard in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed the traffic.

Observed guardrail:

- the catch-bearing `try_table` select reverse-compare condition preserved mutable global traffic.

## Starshine implementation

Implemented a narrow reverse-compare helper in `src/passes/simplify_globals_optimizing.mbt`:

- requires a no-catch `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`;
- recognizes the parser/lowering shape where a leading compare constant and two selected constants precede the `try_table`, followed by `ref.is_null`, `select`, and a supported compare opcode;
- reuses the existing safe-body reader and same-global constant-set recognition;
- supports both no-else same-global constant-set guards and exact `if return; set` / block-wrapped set tails;
- leaves catch-bearing wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null select reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null select reverse compare if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null select reverse compare guards conservative`

The first TDD run failed the two no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Non-claims

This does not add caught `try_table` handling, broader reference/GC/ref-cast handling, arbitrary select/reverse-compare value positions beyond the probed shape, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins.
