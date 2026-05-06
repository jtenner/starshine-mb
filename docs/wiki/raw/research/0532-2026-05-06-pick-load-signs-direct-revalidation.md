---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/starshine-strategy.md
  - ../../binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md
  - ../../../../src/passes/pick_load_signs.mbt
  - ../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/starshine-strategy.md
  - ../../binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `pick-load-signs` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `pick-load-signs` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`pick-load-signs` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass, but it does not change the documented local-vs-upstream i64 scope note: Starshine currently recognizes broader i64 extension / mask / shift-pair families than upstream Binaryen's effectively i32-only `version_129` pass.
