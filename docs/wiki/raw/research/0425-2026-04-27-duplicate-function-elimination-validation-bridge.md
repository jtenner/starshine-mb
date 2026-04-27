---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/binaryen-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/wat-shapes.md
  - ../../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Duplicate function elimination validation bridge

## Question

The `duplicate-function-elimination` dossier already has source-correct overview, strategy, shape, local-strategy, and parity pages. What still makes the folder harder than necessary for beginner-through-advanced readers to use when validating Starshine behavior against Binaryen?

## Answer

The gap is not the core algorithm description. The gap is the validation bridge between three facts that were spread across several pages:

1. Binaryen DFE can run more than one round depending on optimization settings.
2. Binaryen schedules DFE twice in the no-DWARF optimizer.
3. Starshine currently exposes DFE as an explicit module pass, performs one duplicate-elimination iteration, adds local type/name/metadata cleanup, and does not schedule it in public `optimize` / `shrink` presets.

A new living page should connect those facts in one place and turn them into actionable validation rules.

## Sources checked

- Official Binaryen current-main DFE owner and scheduler surfaces.
- Representative Binaryen optimize-level lit fixture.
- Existing DFE living wiki folder.
- Local Starshine registry, dispatcher, implementation, and focused tests.

## Durable findings

- Upstream parity is not just “two equal functions collapse.” It also includes the iteration budget and two scheduler slots.
- Current Starshine is intentionally neither a full Binaryen scheduling port nor a minimal upstream clone: it is one explicit pass run with extra cleanup after the duplicate-function rewrite.
- The best next validation target before preset scheduling is therefore a two-axis check:
  - explicit pass behavior must preserve the current local extra-cleanup contract, and
  - no-DWARF preset scheduling work must separately decide whether to model Binaryen's two DFE slots and multi-round budget.

## Wiki changes made

- Added `docs/wiki/binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md`.
- Added the 2026-04-27 raw primary-source manifest for the scheduler/validation recheck.
- Refreshed the DFE overview, Starshine strategy, parity, global wiki index, pass index, tracker, and log so the validation bridge is discoverable.

## Uncertainties

- This note does not decide whether Starshine should implement Binaryen's multi-round loop inside one explicit pass, represent repeated DFE through preset scheduling, or keep the explicit pass one-round and model extra rounds only through presets. It only makes the choice visible.
- Local type-compaction and metadata cleanup are documented as current behavior, not as an upstream requirement.
