---
kind: comparison
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../0069-2026-03-26-pick-load-signs.md
related:
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
---

# `pick-load-signs` Binaryen Parity

## Durable Conclusions

- `pick-load-signs` is an early function-phase Binaryen pass on the no-DWARF path for optimize level `>= 2`.
- The pass rewrites narrow integer load signedness based on proven extension usage for the target local.
- Eligible producers are exact `local.set(load ...)` forms over narrow integer loads; `local.tee` producers stay out of scope.

Recognized usage evidence comes from:

- direct unary extend operations
- low-bit mask-to-zero patterns
- matching left-shift and right-shift extension pairs

- Rewrites only happen when every observed use is recognized, the winning signedness has one consistent width, and all producers for the local can move together.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt).
- The focused suite lives in [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt).
- CLI and debug-artifact coverage lives in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).
- The pass is active in the optimize and shrink pipelines after `optimize-instructions`.
- The pass manager includes a module-memory fast skip and raw candidate screening so functions without exact candidate surface can avoid hot lift.

## Signoff Status

- The `2026-03-29` debug-artifact signoff recorded canonical wasm parity and normalized WAT parity.
- The same signoff recorded Starshine wall time at about `2067.184 ms` versus Binaryen at `1408.509 ms`.
- The `2026-03-29` `gen-valid` pass-fuzz run recorded `10000 / 10000` compared cases, `10000` normalized matches, and `0` mismatches or failures.

## Sources

- Numbered research doc: [`../../../../0069-2026-03-26-pick-load-signs.md`](../../../../0069-2026-03-26-pick-load-signs.md)
- Implementation: [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt)
- Focused tests: [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt)
- CLI coverage: [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)
