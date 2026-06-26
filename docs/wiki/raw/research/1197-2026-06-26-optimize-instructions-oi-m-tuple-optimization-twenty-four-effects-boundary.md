# OptimizeInstructions OI-M tuple-optimization twenty-four-effect boundary

Date: 2026-06-26

## Slice

Boundary/status-only OI-M coverage for a public multivalue block with twenty-four later non-selected effects under `optimize-instructions` plus the dedicated `tuple-optimization` neighbor pass.

## Binaryen oracle

Fresh local probe: `.tmp/oi-m-tuple-optimization-twenty-four-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-four-effects-probe.wat -o -
```

Observed Binaryen `version_130` behavior:

- The public multivalue block has one selected `i32` lane followed by twenty-four non-selected lanes.
- Binaryen succeeds and localizes through tuple scratch: `tuple.make 25` appears, followed by scalar `local.set` traffic for non-selected lanes.
- This is a successful Binaryen tuple-scratch localization, not a Binaryen/tool validation failure.

## Starshine coverage

Added public-pipeline boundary test `optimize-instructions intentionally keeps public multivalue block with twenty-four later effects through tuple-optimization boundary` in `src/passes/optimize_instructions_test.mbt`.

The test asserts Starshine keeps the current block/drop/call/local.get spelling and does not synthesize temp locals. This is boundary/status evidence only; it does not claim parity with Binaryen's tuple-scratch localization.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-four-effects-probe.wat -o -` passed; `tuple.make 25` and scalar `local.set` traffic were observed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-four later effects through tuple-optimization*'` passed `1/1`.

## Status

This extends the OI-M public `tuple-optimization` neighbor boundary from twenty-three to twenty-four later effects. Tuple-scratch reconstruction/localization remains open for Starshine; do not report this family as parity until Starshine can localize these multivalue public shapes or a narrower non-goal is explicitly accepted.
