# SGO try_table select value-position reverse compare read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0608`](./0608-2026-05-24-sgo-try-table-select-read-only-to-write.md), [`0609`](./0609-2026-05-24-sgo-try-table-select-pure-read-only-to-write.md), and [`0610`](./0610-2026-05-24-sgo-try-table-select-reverse-compare-read-only-to-write.md): a no-catch `try_table (result i32)` may feed a pure-constant-sibling `select` as either selected value when that select result is the second operand of a leading-constant compare. This is a small source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result i32)` wrapping `global.get $g`, used as the first selected value of a pure-constant-sibling `select`, where the select result is the second operand of `i32.eq` against a leading constant before a same-global constant set: Binaryen made `$g` immutable and removed fake global traffic;
- the same no-catch `try_table` result used as the second selected value of a pure-constant-sibling `select` before the leading-constant compare guard: Binaryen made `$g` immutable and removed fake global traffic;
- the first-selected-value reverse-compare form in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed fake global traffic.

Observed guardrail:

- the catch-bearing first-selected-value reverse-compare form preserved mutable global traffic.

## Starshine implementation

Implemented by broadening the existing no-catch `try_table` select reverse-compare helper in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_try_table_select_reverse_compare_if_index` now recognizes the no-catch `try_table` result in the select condition, first selected value, or second selected value position;
- all sibling select operands and the leading compare operand must remain constants;
- the existing no-else same-global constant-set guard and exact `if return; set` / block-wrapped-set tails reuse this helper;
- all handling still requires `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`, reuses the safe-body reader, and leaves catch-bearing wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table select-value reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select-second-value reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select-value reverse compare if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table select-value reverse compare guards conservative`

The first TDD run failed the three no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-select-value-reverse-compare-10k
```

Result: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

This does not add caught `try_table` handling, arbitrary non-constant select siblings, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins. It only broadens the no-catch `try_table` + pure-constant-sibling select leading-constant reverse-compare stack layouts to the probed selected-value positions.
