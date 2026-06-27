# OptimizeInstructions OI-M tuple-optimization ninety-seven-effect boundary

## Summary

This is a boundary/status slice for the public `optimize-instructions -> tuple-optimization` neighborhood. Binaryen `version_130` localizes a public multivalue block with ninety-seven later non-selected effect calls through tuple scratch traffic, while Starshine keeps the block/drop/call/local.get spelling.

This documents the retained OI-M tuple-scratch reconstruction/localization gap. It is not an implementation slice and does not close OI-M.

## Oracle evidence

Probe: `.tmp/oi-m-tuple-optimization-ninety-seven-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-ninety-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-ninety-seven-effects-probe.out.wat
```

Result: passed. Binaryen output contained one `tuple.make 98` and `97` `local.set` occurrences, proving successful tuple-scratch localization for this effect-count boundary.

## Starshine coverage

- Reused `optimize_instructions_tuple_optimization_effect_boundary_fixture(97)` in `src/passes/optimize_instructions_test.mbt`.
- Added boundary/status test: `optimize-instructions intentionally keeps public multivalue block with ninety-seven later effects through tuple-optimization boundary`.
- The test asserts Starshine keeps the public multivalue `block`, `drop`s, all effect calls, and `local.get`, and does not introduce `local.set` traffic.

## Validation

- Binaryen oracle command above passed and produced the expected `tuple.make 98` / `97` `local.set` shape.
- Focused boundary test before formatting: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ninety-seven later effects through tuple-optimization*'` passed `1/1`.
- Pre-commit validation: `moon fmt` passed; focused `*ninety-seven later effects through tuple-optimization*` passed again; `moon test src/passes` passed `3533/3533`; `git diff --check` passed.

## Boundaries

This is boundary/status evidence only. It does not implement tuple-scratch reconstruction, multi-result selected/sibling localization, `simplify-locals` neighbor repair, or full `tuple-optimization` parity. The mismatch remains a parity gap unless a future slice implements the Binaryen-shaped localization or proves and documents a measured Starshine win.
