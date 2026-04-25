# `memory64-lowering` out-of-range recheck

_Date:_ 2026-04-25  
_Status:_ filed back into living wiki pages  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`, `docs/wiki/raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`, `docs/wiki/binaryen/passes/memory64-lowering/`, `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/validate/validate.mbt`

## Question

The 2026-04-24 `memory64-lowering` dossier was complete enough for a first pass, but it still carried a broad uncertainty: what exactly does Binaryen do with memory64/table64 constants, active offsets, grow deltas, and limits that do not fit the lowered 32-bit output?

That uncertainty made the shape catalog easier to misread as “everything just wraps with `i32.wrap_i64`,” which is incorrect for known-constant out-of-range operands.

## Source-backed findings

- Rechecked Binaryen `version_129` and current `main` `Memory64Lowering.cpp`, plus the paired memory and table lit files.
- Dynamic address/index operands still lower by wrapping with `i32.wrap_i64(...)`.
- Known constant address/index operands and active data/element offsets at or above `2^32` lower to `unreachable` rather than wrapping.
- In-range constant address/index operands and active offsets become `i32.const` forms.
- `memory.size` and `table.size` are still the simple lowered-`i32` result plus unsigned extension back to the apparent `i64` result.
- `memory.grow` and `table.grow` are more subtle than the old docs implied:
  - constant deltas that cannot fit in 32 bits become the 64-bit failure sentinel directly;
  - dynamic deltas are wrapped into the lowered operation;
  - lowered grow results need failure-sentinel repair, not only blind zero-extension.
- Max limits above the 32-bit maximum are clamped to the 32-bit maximum.
- Min limits are asserted to fit after max clamping; this is a source-level observation, not a polished user-facing diagnostic contract.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Starshine local findings

- `src/passes/optimize.mbt` still has no active, boundary-only, or removed entry for `memory64-lowering` or `table64-lowering`; request behavior remains unknown-pass.
- `src/lib/types.mbt` already has `Limits::I64Limits`, `Limits::addr_valtype(...)`, `min_addr(...)`, and `min_addr_valtype(...)`, which are prerequisite representation helpers for a future port.
- `src/validate/typecheck.mbt` already threads memory address width through `mem_at_of(...)`, load/store helpers, `memory.size`, `memory.grow`, `memory.copy`, `memory.init`, and `memory.fill`.
- `src/validate/typecheck.mbt` still hard-codes `i32` for `table.get`, `table.set`, `table.size`, and `table.grow`, while `table.copy`, `table.init`, and `table.fill` partly consult table limits. A future table64-lowering port must audit that split first.
- `src/validate/validate.mbt` validates memory64 limits with a much larger page cap than memory32. That local validator capability is not itself a lowering pass.

## Filed-back pages

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-ups

- If Starshine implements the pass, add separate tests for dynamic wrap, in-range constant narrowing, out-of-range constant-to-unreachable, grow failure-sentinel repair, max-limit clamp, min-limit rejection/assertion policy, and active segment offset lowering.
- Reconcile table64 typechecking before exposing `table64-lowering` as a supported local pass.
