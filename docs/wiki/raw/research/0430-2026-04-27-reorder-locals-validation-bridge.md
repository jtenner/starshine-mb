---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/binaryen-strategy.md
  - ../../binaryen/passes/reorder-locals/wat-shapes.md
  - ../../binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/multivalue-call-scope.md
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Reorder locals validation bridge

## Question

The `reorder-locals` dossier already had source-correct overview, Binaryen strategy, shape, Starshine module-strategy, names/roundtrip, parity, and multivalue-scope pages. What still made it harder than necessary for beginner-through-advanced readers to validate Starshine behavior against Binaryen?

## Answer

The gap was not the sorter description. The gap was the validation bridge between three facts spread across several pages:

1. Binaryen schedules `reorder-locals` three times in the no-DWARF optimizer as cleanup glue around neighboring local passes.
2. Starshine implements the standalone explicit module pass, including local-name repair and raw-name-payload invalidation.
3. Starshine intentionally does not schedule it in public `optimize` / `shrink` presets until the neighboring locals passes and ordered no-DWARF replay are ready.

A new living page should keep those facts together and turn them into testable validation rules.

## Sources checked

- Official Binaryen current-main owner, scheduler, and dedicated pass/roundtrip tests.
- Existing `reorder-locals` living wiki folder.
- Local Starshine registry, dispatcher, implementation, focused tests, preset-exclusion test, category test, and CLI adapter test.

## Durable findings

- Upstream parity is not only “sort local declarations by use count.” It also includes the repeated scheduler role after cleanup waves.
- Current Starshine parity for the explicit pass is already anchored in local tests for multiple defined functions, parameter arity lookup, access-count and first-use ordering, write-only and tee-only locals, nested structured rewrites, local-name repair, raw-name-payload clearing, and a Binaryen-materialized carrier fixture.
- Preset-readiness should be judged separately from explicit-pass correctness. The next preset gate is ordered no-DWARF replay evidence once the missing neighboring locals passes (`simplify-locals-*`, `coalesce-locals`, and related cleanup) are available locally.
- The older multivalue-call caveat remains a writer/lowering boundary issue, not a reason to blur the `ReorderLocals.cpp` algorithm.

## Wiki changes made

- Added `docs/wiki/binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md`.
- Added the 2026-04-27 raw primary-source manifest for the validation/preset-readiness recheck.
- Refreshed the `reorder-locals` overview, Starshine strategy, WAT-shape, pass index, pass tracker, global wiki index, changelog, and wiki log so the validation bridge is discoverable.

## Uncertainties

- This note does not decide when Starshine should schedule `reorder-locals` in `optimize` or `shrink`. It records the validation evidence needed before that decision is safe.
- This note does not reopen the multivalue-call writeback investigation. It keeps the existing out-of-scope decision linked so future readers do not confuse that boundary with the local sorter.
