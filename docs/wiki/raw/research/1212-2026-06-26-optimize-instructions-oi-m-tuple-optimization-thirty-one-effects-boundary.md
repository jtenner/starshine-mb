---
kind: research
status: supported
date: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-M tuple-optimization thirty-one-effect public multivalue boundary

## Question

How does Binaryen `version_130` handle a public multivalue block where `optimize-instructions` selects the first value and drops thirty-one later effectful lanes when `tuple-optimization` also runs, and should Starshine already match that local tuple-scratch reconstruction?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-thirty-one-effects-probe.wat`

Shape summary:

- thirty-one `$side_N` functions each return one `i32`
- the tested function returns the first value from a 32-result block
- the selected lane is `local.get $x`
- the thirty-one later non-selected lanes are `call $side_0` through `call $side_30`
- thirty-one trailing `drop` instructions consume the non-selected values

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-thirty-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-thirty-one-effects-probe.out.wat
```

Observed Binaryen output succeeds and localizes the public multivalue block through `tuple.make 32`, a tuple scratch local, and scalar scratch locals for the dropped lanes. The selected value is returned through localized scalar traffic after the tuple reconstruction.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with thirty-one later effects through tuple-optimization boundary`

The test asserts that Starshine keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce `local.set` traffic for this tuple-neighbor shape.

## Classification

Boundary/status slice, not parity implementation. This extends the OI-M `tuple-optimization` neighbor ladder beyond the thirty-effect boundary. The retained mismatch is a tuple-scratch reconstruction/localization gap, not evidence that the public multivalue shape is already parity-complete.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-thirty-one-effects-probe.wat -o .tmp/oi-m-tuple-optimization-thirty-one-effects-probe.out.wat` passed and produced `tuple.make 32` plus tuple/scalar scratch locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*thirty-one later effects through tuple-optimization*'` passed `1/1`.
