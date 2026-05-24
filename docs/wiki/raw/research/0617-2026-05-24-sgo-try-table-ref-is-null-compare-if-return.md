# SGO try_table ref.is_null compare if-return read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` with a narrow completion of the no-catch `try_table (result funcref)` + `ref.is_null` adjacent compare family from [`0616`](./0616-2026-05-24-sgo-try-table-ref-is-null-compare.md): support the normal operand-order compare-with-const form in the exact `if return; global.set` tail. This is a tiny source-alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positive:

- no-catch `try_table (result funcref)` wrapping `global.get $g`, followed by `ref.is_null`, used as the first operand of `i32.eq` against a trailing constant in an exact `if return; global.set $g (ref.func $f)` tail: Binaryen made `$g` immutable and removed fake global traffic.

Observed guardrail:

- the same `if return; global.set` normal-compare form with a catch-bearing `try_table` preserved mutable global traffic.

## Starshine implementation

Implemented the narrow missing tail in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_count_try_table_ref_is_null_compare_if_return_read` on top of the existing `sgo_try_table_ref_is_null_compare_if_index` recognizer;
- routed no-catch `try_table; ref.is_null; const; compare; if-return` into the existing safe-body read counter for exact constant `global.set` and block-wrapped-set tails;
- preserved the existing `catches.length() == 0` requirement in the recognizer, so caught `try_table` wrappers remain conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table ref.is_null compare if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table ref.is_null compare if-return guards conservative`

The first TDD run failed the no-catch positive because `$g` remained mutable. After implementation `moon test src/passes` passed.

## Validation

Focused pass tests:

```sh
moon test src/passes
```

Result: `1574/1574` passed; existing warnings only.

Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-compare-if-return-10k
```

Result: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

Full quick gate:

```sh
moon info && moon fmt && moon test
```

Result: `3650/3650` tests passed; existing warnings only.

## Non-claims

This does not add caught `try_table` handling, broader reference/GC/ref-cast handling, calls, trapping/effectful operands, broader branch/control-transfer matching, or `try_table` joins. It only fills the probed no-catch direct `ref.is_null` normal compare-with-const exact `if return; set` tail.
