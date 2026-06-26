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

# OptimizeInstructions OI-M tuple-optimization twenty-six-effect boundary

## Question

Does the public `optimize-instructions` plus `tuple-optimization` neighbor still expose the same tuple-scratch localization gap for a selected first lane followed by twenty-six non-selected effectful lanes?

## Evidence

Probe: `.tmp/oi-m-tuple-optimization-twenty-six-effects-probe.wat`

The probe defines a public multivalue block returning one selected `i32` lane plus twenty-six later lanes from `$side_a` through `$side_z`, then drops all non-selected results.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-six-effects-probe.wat -o -
```

Binaryen `version_130` succeeds and localizes the public multivalue block through `tuple.make 27`, a tuple scratch local, and scalar locals for the non-selected lanes. This is the same tuple-scratch reconstruction/localization family as the smaller public neighbor probes.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block with twenty-six later effects through tuple-optimization boundary`

The test asserts that Starshine's public pipeline succeeds but keeps the block/drop/call/local.get spelling and does not introduce `local.set` scratch traffic. This is intentionally not claimed as Binaryen parity; it documents the retained tuple-scratch localization gap while keeping the public fixture representable.

## Classification

Boundary/status slice. This extends the OI-M public `tuple-optimization` neighbor ladder to twenty-six later effects. It does not implement tuple-scratch reconstruction, multi-result selected/sibling localization, or the full `simplify-locals` neighbor blocker.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-six-effects-probe.wat -o -` passed and showed Binaryen's `tuple.make 27` plus scalar-local localization.
- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-six later effects through tuple-optimization*'` passed `1/1`.
