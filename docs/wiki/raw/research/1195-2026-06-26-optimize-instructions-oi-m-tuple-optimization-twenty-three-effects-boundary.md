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

# OptimizeInstructions OI-M tuple-optimization twenty-three-effect boundary

## Question

Can the public `optimize-instructions` plus `tuple-optimization` pipeline parse and preserve a multivalue block with twenty-three later non-selected effects, and how does that compare with Binaryen `version_130`?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-twenty-three-effects-probe.wat`

The probe returns the first `i32` value from a multivalue block and drops twenty-three later values from calls returning alternating scalar types. All non-selected block results are explicitly dropped so the WAT remains valid.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-three-effects-probe.wat -o -
```

Observed Binaryen output succeeds and localizes through tuple scratch plus scalar locals. The output includes a `tuple.make 24` scratch and scalar `local.set` traffic for the later non-selected values.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with twenty-three later effects through tuple-optimization boundary`

The test asserts that Starshine's public pipeline succeeds but keeps the multivalue `block`, `drop`s, calls, and `local.get`, and does not introduce temp `local.set` traffic. This is not parity with Binaryen's tuple-scratch localization; it is a public representation boundary while tuple reconstruction/localization remains unimplemented.

## Classification

Boundary/status slice. This extends the OI-M tuple-optimization neighbor evidence from twenty-two to twenty-three later effects. It documents continued Starshine-vs-Binaryen output-shape drift as an open tuple-scratch localization gap, not a safe parity match.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-three-effects-probe.wat -o -` passed and showed tuple-scratch plus scalar-local reconstruction.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-three later effects through tuple-optimization*'` passed `1/1`.
