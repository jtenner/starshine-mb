---
kind: research
status: supported
last_reviewed: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M tuple-optimization fifty-effect boundary

## Question

How does Binaryen `version_130` handle a public multivalue block whose selected lane is followed by fifty non-selected effectful siblings when `--optimize-instructions --tuple-optimization` run together, and what does Starshine currently preserve?

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-effects-probe.out.wat
```

Result: Binaryen accepts the fixture and localizes the public multivalue block through `tuple.make 51` plus tuple/scalar scratch locals. The output contains `tuple.make 51`, calls for `$side_0` through `$side_49`, and a ladder of `local.set $scratch_*` traffic that reconstructs the selected value while preserving the later effectful siblings.

## Starshine status

Added boundary/status coverage:

- `optimize-instructions intentionally keeps public multivalue block with fifty later effects through tuple-optimization boundary`

This is boundary-only coverage, not an implementation slice. Starshine's public pipeline currently keeps the source-level `block` / `drop` / `call` / `local.get` spelling and does not introduce tuple/scalar scratch locals for this shape. That remains an open OI-M tuple-scratch reconstruction/localization parity gap.

The test reuses `optimize_instructions_tuple_optimization_effect_boundary_fixture(50)` and asserts:

- Starshine accepts and prints the public pipeline fixture.
- The selected function still contains `block`, `drop`, calls for every later effectful sibling, and `local.get`.
- The selected function does not contain `local.set`, making the retained mismatch explicit.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 51` plus tuple/scalar scratch locals.
- Focused Starshine boundary test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty later effects through tuple-optimization*'` passed `1/1`.

## Remaining work

This extends the OI-M public tuple-optimization boundary ladder to fifty later effects. It does not close tuple/multivalue parity. The remaining implementation gap is tuple-scratch reconstruction/localization for public and lowered shapes, especially multi-result selected/sibling cases and dedicated `tuple-optimization` / `simplify-locals` neighbor behavior.
