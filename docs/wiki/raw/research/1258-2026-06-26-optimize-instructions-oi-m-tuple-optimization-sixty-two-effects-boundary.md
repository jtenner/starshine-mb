# Optimize-instructions OI-M tuple-optimization sixty-two-effect boundary

## Summary

This boundary/status slice extends the public `optimize-instructions` plus `tuple-optimization` multivalue effect-count ladder to a block with sixty-two later non-selected effects.

Binaryen `version_130` localizes the probed public multivalue block through tuple scratch (`tuple.make 63`) plus scalar scratch locals. Starshine currently keeps the public block/drop/call/local.get spelling and introduces no `local.set` traffic. This remains an open tuple-scratch reconstruction/localization gap, not OI-M parity closure.

## Evidence

- Binaryen oracle probe: `.tmp/oi-m-tuple-optimization-sixty-two-effects-probe.wat`.
- Oracle command:
  - `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-sixty-two-effects-probe.wat -o .tmp/oi-m-tuple-optimization-sixty-two-effects-probe.out.wat`
- Oracle result: output contains `tuple.make 63` and tuple/scalar scratch-local traffic; the probed output had `62` `local.set` occurrences.
- Starshine focused boundary coverage: `optimize-instructions intentionally keeps public multivalue block with sixty-two later effects through tuple-optimization boundary` passed and asserts the retained public block/drop/call/local.get spelling without `local.set` traffic.

## Boundary

This is intentionally boundary/status coverage. It does not implement Binaryen's tuple-scratch localization, does not close the public `tuple-optimization` neighbor gap, and does not reduce the known full `simplify-locals` / tuple carrier verifier blocker. It only keeps the sixty-two-effect public shape visible while broader OI-M tuple reconstruction remains active.
