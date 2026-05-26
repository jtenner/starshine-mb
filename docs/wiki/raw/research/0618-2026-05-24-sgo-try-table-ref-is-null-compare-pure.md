# SGO try_table ref.is_null compare pure read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow follow-up to [`0616`](./0616-2026-05-24-sgo-try-table-ref-is-null-compare.md) and [`0617`](./0617-2026-05-24-sgo-try-table-ref-is-null-compare-if-return.md): a no-catch `try_table (result funcref)` followed by `ref.is_null` and a normal compare-with-const may feed a supported pure post-consumer before the self guard, including the exact `if return; set` tail. The implemented probe uses `i32.eqz` as the post-consumer. This is not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, `i32.eq` against a trailing constant, and `i32.eqz` before a same-global `ref.func` set: Binaryen made `$g` immutable and removed fake global traffic;
- the same normal compare + `i32.eqz` chain in an exact `if return; global.set` tail: Binaryen made `$g` immutable and removed fake global traffic.

Observed guardrail:

- the catch-bearing normal compare + `i32.eqz` form preserved mutable global traffic.

## Starshine implementation

Implemented a narrow no-catch post-compare pure scanner in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_try_table_ref_is_null_compare_pure_if_index` for `try_table; ref.is_null; const; compare; supported-pure*; if`;
- added direct self-guard and exact `if return; set` count helpers using the existing safe-body reader;
- preserved the no-catch requirement through the recognizer, so caught `try_table` wrappers remain conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null compare eqz guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table ref.is_null compare eqz if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null compare eqz guards conservative`

The first TDD run failed the two no-catch positives because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Validation

Focused pass tests:

```sh
moon test src/passes
```

Result: `1577/1577` passed; existing warnings only.

Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-compare-pure-10k
```

Result: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

Full quick gate:

```sh
moon info && moon fmt && moon test
```

Result: `3653/3653` tests passed; existing warnings only.

## Non-claims

This does not add caught `try_table` handling, reverse-compare post-pure handling, broader reference/GC/ref-cast handling, calls, trapping/effectful operands, broader branch/control-transfer matching, or `try_table` joins. It only broadens the probed no-catch direct `ref.is_null` normal compare-with-const family through supported pure post-consumers and exact pure-post-compare `if return; set` tails.
