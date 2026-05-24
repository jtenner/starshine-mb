# SGO try_table ref.is_null select value-position read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0611`](./0611-2026-05-24-sgo-try-table-ref-is-null-select-read-only-to-write.md), [`0612`](./0612-2026-05-24-sgo-try-table-ref-is-null-select-pure-read-only-to-write.md), and [`0613`](./0613-2026-05-24-sgo-try-table-ref-is-null-select-reverse-compare.md): a no-catch `try_table (result funcref)` followed by `ref.is_null` may feed a pure-constant-sibling `select` not only as the condition, but also as either selected value. This is a small source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, used as the first selected value of a pure-constant-sibling `select` before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the same `ref.is_null` result as the second selected value of a pure-constant-sibling `select` before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the first-selected-value form with a post-select `i32.eqz` before the same-global set: Binaryen made `$g` immutable and removed fake global traffic;
- the second-selected-value form where the select result is the second operand of `i32.eq` against a leading constant before the same-global set: Binaryen made `$g` immutable and removed fake global traffic.

Observed guardrail:

- the catch-bearing first-selected-value form preserved mutable global traffic.

## Starshine implementation

Implemented by broadening the existing no-catch `try_table` + `ref.is_null` select helpers in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_try_table_ref_is_null_select_pos` now recognizes the `ref.is_null` result in the select condition, first selected value, or second selected value position, with all sibling select operands required to be constants;
- the existing direct, post-select pure, exact `if return; set`, and block-wrapped-set tails reuse that shared select-position helper;
- `sgo_try_table_ref_is_null_select_reverse_compare_if_index` now accepts the corresponding leading-constant reverse-compare stack layouts for all three select positions;
- all helpers still require `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0` and reuse the existing safe-body reader and same-global constant-set recognition;
- catch-bearing wrappers remain conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null select-value guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null select-second-value guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null select-value eqz guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null select-second-value reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null select-value guards conservative`

The first TDD run failed the four no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-select-value-10k
```

Result: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

This does not add caught `try_table` handling, broader reference/GC/ref-cast handling, arbitrary non-constant select siblings, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins. It only broadens the no-catch `try_table` + `ref.is_null` + pure-constant-sibling select position handling to the probed selected-value stack layouts.
