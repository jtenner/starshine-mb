# SGO try_table select reverse compare read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0608`](./0608-2026-05-24-sgo-try-table-select-read-only-to-write.md) and [`0609`](./0609-2026-05-24-sgo-try-table-select-pure-read-only-to-write.md): no-catch `try_table` results feeding a pure-constant-sibling `select` condition may also be used in the reverse compare-with-const self-guard shape. This is still a small source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result i32)` feeding a pure-constant-sibling `select` condition, where the select result is the second operand of `i32.eq` against a leading constant before the same-global constant set: Binaryen made `$g` immutable and removed fake global traffic;
- the same reverse-compare guard in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed the traffic.

Observed guardrail:

- the catch-bearing `try_table` select reverse-compare condition preserved mutable global traffic.

## Starshine implementation

Implemented a narrow reverse-compare helper in `src/passes/simplify_globals_optimizing.mbt`:

- requires a no-catch `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`;
- recognizes the probed stack shape where the candidate `try_table` result is the select condition with two constant selected values, and a leading compare constant precedes the select expression;
- requires the adjacent compare instruction to be an existing supported compare opcode;
- reuses the existing safe-body reader and same-global constant-set recognition;
- supports both no-else same-global constant-set guards and exact `if return; set` / block-wrapped set tails;
- leaves catch-bearing wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table select reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select reverse compare if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table select reverse compare guards conservative`

The first TDD run failed the two no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Non-claims

This does not add caught `try_table` handling, arbitrary reverse-compare/select value positions beyond the probed condition shape, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins.
