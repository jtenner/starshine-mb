# Optimize-instructions OI-M tuple-optimization twenty-eight-effect boundary

Date: 2026-06-26

## Scope

Boundary/status-only OI-M slice for a public multivalue block with one selected `i32` lane and twenty-eight later non-selected `i32` call-result lanes under `optimize-instructions` plus `tuple-optimization`.

This extends the public `tuple-optimization` neighbor effect-count ladder beyond the twenty-seven-effect probe. It is not parity: Starshine still lacks the local tuple-scratch reconstruction/localization that Binaryen applies.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-twenty-eight-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-eight-effects-probe.wat -o -
```

Observed Binaryen `version_130` behavior:

- accepts the public 29-result block shape;
- localizes the selected result and twenty-eight non-selected result lanes through `tuple.make 29`;
- emits tuple/scalar scratch locals, including nested `local.set` traffic for the non-selected lanes.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions intentionally keeps public multivalue block with twenty-eight later effects through tuple-optimization boundary`

The test runs the public pipeline with `optimize-instructions` and `tuple-optimization`, then asserts Starshine keeps the block/drop/call/local.get spelling and does not introduce `local.set` traffic.

This is a deliberately narrow boundary assertion. The retained mismatch remains an open tuple-scratch localization gap, not a claimed Starshine parity win.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-eight-effects-probe.wat -o -` — passed and localized through `tuple.make 29` plus scratch locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-eight later effects through tuple-optimization*'` — passed `1/1`.

Full slice validation is recorded in the commit body.

## Status

OI-M public tuple-optimization boundary coverage now reaches twenty-eight later non-selected effects in this ladder. Tuple-scratch reconstruction/localization remains open before claiming Binaryen neighbor parity.
