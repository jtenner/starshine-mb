# SGO try_table select reverse-compare pure read-only-to-write

Date: 2026-05-24

## Question

After centralizing part of the no-catch `try_table` matcher surface, can the existing no-catch `try_table` select leading-constant reverse-compare family safely flow through a supported pure post-consumer such as `i32.eqz`?

## Binaryen oracle probes

Focused Binaryen v129 probes used:

```sh
wasm-opt --enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `try_table (result i32)` as the select condition, then leading-constant `i32.eq`, then `i32.eqz`, before a same-global `i32.const` write;
- no-catch `try_table (result i32)` as the first selected value in the same leading-constant compare + `i32.eqz` shape;
- no-catch `try_table (result i32)` as the second selected value in the same leading-constant compare + `i32.eqz` shape;
- exact `if return; global.set` tail for the select-condition shape;
- no-catch `try_table (result funcref)` feeding `ref.is_null` in the select condition / first value / second value positions, then leading-constant compare + `i32.eqz`, before a same-global `ref.func` write;
- exact `if return; global.set` tail for the `ref.is_null` select-condition shape.

Observed negative:

- catch-bearing `try_table` in the select condition remained conservative under the same leading-constant compare + `i32.eqz` shape.

## Implementation

`src/passes/simplify_globals_optimizing.mbt` now routes the existing no-catch select and `ref.is_null` select leading-constant reverse-compare helpers through `sgo_scan_optional_external_pure_if_index`, so both immediate `if` and supported pure-post-consumer `if` tails use the same direct and exact `if return; set` tail appliers.

This intentionally does not broaden caught `try_table`, calls, trapping/effectful consumers, non-leading-constant select compare shapes beyond the already-covered families, or unrelated control-transfer.

## Tests

Added focused positives for:

- `try_table` select-condition reverse compare + `i32.eqz`;
- `try_table` first selected-value reverse compare + `i32.eqz`;
- `try_table` second selected-value reverse compare + `i32.eqz`;
- `try_table` select-condition reverse compare + `i32.eqz` with exact `if return; set` tail;
- `ref.is_null` select-condition reverse compare + `i32.eqz`;
- `ref.is_null` first selected-value reverse compare + `i32.eqz`;
- `ref.is_null` second selected-value reverse compare + `i32.eqz`;
- `ref.is_null` select-condition reverse compare + `i32.eqz` with exact `if return; set` tail.

Added catch-bearing negatives for the plain and `ref.is_null` select-condition reverse compare + `i32.eqz` shapes.

The initial `moon test src/passes` run failed the eight no-catch positives because the candidate globals stayed mutable; the catch-bearing negatives already passed.

## Validation

- `moon test src/passes`: 1590/1590 passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-select-reverse-compare-pure-10k`: 9975/10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, 25 Binaryen/tool command failures.
- `moon info && moon fmt && moon test`: 3666/3666 passed.

## Remaining work

`[SGO]003` remains active/partial. This slice does not claim full Binaryen `SimplifyGlobals.cpp` parity.
