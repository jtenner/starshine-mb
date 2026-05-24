# SGO try_table ref.is_null compare read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0606`](./0606-2026-05-24-sgo-try-table-ref-is-null-read-only-to-write.md): a no-catch `try_table (result funcref)` followed by `ref.is_null` may feed an adjacent compare-with-const self guard, including the leading-constant reverse-compare form and exact `if return; set` tail. This is a small source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, then compare-with-const before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the same `ref.is_null` result used as the second operand of `i32.eq` against a leading constant before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the leading-constant reverse-compare form in the exact `if return; global.set` tail shape: Binaryen made `$g` immutable and removed fake global traffic.

Observed guardrail:

- the catch-bearing reverse-compare form preserved mutable global traffic.

## Starshine implementation

Implemented narrow no-catch `try_table` + `ref.is_null` compare helpers in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_try_table_ref_is_null_compare_if_index` recognizes `try_table; ref.is_null; const; compare; if`;
- `sgo_try_table_ref_is_null_reverse_compare_if_index` recognizes `const; try_table; ref.is_null; compare; if`;
- the count helpers reuse the existing safe-body reader and same-global constant-set recognition;
- the reverse-compare helper also supports exact `if return; set` and block-wrapped-set tails;
- all handling requires `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`; catch-bearing wrappers remain conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null reverse compare guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null reverse compare if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null reverse compare guards conservative`

The first TDD run failed the three no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-compare-10k
```

Result: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

This does not add caught `try_table` handling, broader reference/GC/ref-cast handling, calls, trapping/effectful operands, broader branch/control-transfer matching, or broader `try_table` joins. It only broadens the no-catch `try_table` + `ref.is_null` condition family to the probed adjacent compare-with-const layouts.
