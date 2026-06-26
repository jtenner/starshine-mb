# Optimize-instructions OI-M tuple-optimization fifty-eight-effect boundary

## Slice

Boundary/status slice for the public `optimize-instructions` plus `tuple-optimization` neighbor. This extends the existing multivalue effect-count ladder to fifty-eight later non-selected effects.

This is not a parity implementation. It records a retained tuple-scratch reconstruction/localization gap.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-eight-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-eight-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-eight-effects-probe.out.wat
```

Result: passed. Binaryen `version_130` localizes the selected block result through `tuple.make 59` plus tuple/scalar scratch locals and emits `local.set` / `local.get` scratch traffic.

## Starshine status

Files:

- `src/passes/optimize_instructions_test.mbt`

The focused public-pipeline test uses `optimize_instructions_tuple_optimization_effect_boundary_fixture(58)` and runs:

```text
["optimize-instructions", "tuple-optimization"]
```

Starshine keeps the original public spelling:

- `block`
- `drop`
- all fifty-eight side-effecting `call` instructions
- final `local.get`
- no introduced `local.set` traffic

This is intentionally recorded as an open mismatch against Binaryen's tuple-scratch localization shape.

## Evidence

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-eight later effects through tuple-optimization*'
```

Result: passed `1/1`.

## Boundaries

This slice does not solve:

- tuple-scratch reconstruction/localization
- selected-lane local insertion for public tuple/multivalue text
- the full `simplify-locals` neighbor blocker
- direct-HOT replay blocker `InvalidChildRef(3, 0, 0)` seen in earlier full-simplify tuple work
- broad tuple/multivalue parity for `optimize-instructions`

Use this note as coverage/status evidence only, not as OI-M closure.
