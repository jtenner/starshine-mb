---
kind: research
status: supported
created: 2026-06-27
sources:
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# Optimize-instructions OI-M tuple-optimization one-hundred-effect boundary

## Scope

This boundary/status slice extends the public `optimize-instructions` + `tuple-optimization` multivalue block ladder from ninety-nine to one hundred later non-selected effect values.

The fixture emits a multivalue block with one selected `local.get` result followed by one hundred later `call $side_N` results. Public Starshine still keeps the block/drop/call/local.get spelling because local tuple-scratch reconstruction/localization is not implemented.

## Binaryen evidence

Probe: `.tmp/oi-m-tuple-optimization-one-hundred-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-one-hundred-effects-probe.wat -o .tmp/oi-m-tuple-optimization-one-hundred-effects-probe.out.wat
```

Result: passed. Binaryen localized the tuple scratch path, producing `tuple.make 101` once and `100` `local.set` occurrences.

## Starshine evidence

Added focused boundary/status coverage:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*one hundred later effects through tuple-optimization*'
```

The test intentionally asserts the current Starshine boundary:

- output still contains `block`;
- output still contains `drop`;
- every effect call from `Func 0` through `Func 99` remains present;
- output still contains `local.get`;
- output does not introduce `local.set` traffic.

## Boundary

This is not a parity implementation and does not close OI-M. The remaining mismatch is still the tuple-scratch reconstruction/localization gap: Binaryen scalarizes/localizes via tuple locals while Starshine keeps the public multivalue block/drop form.

The test is a coverage/status slice, not red-first behavior work, because it locks an intentionally retained boundary until the tuple-scratch implementation exists.

## Validation

- Binaryen oracle probe passed and produced `tuple.make 101` once plus `100` `local.set` occurrences.
- Focused Moon boundary test passed.

Full slice validation is recorded in the commit message.
