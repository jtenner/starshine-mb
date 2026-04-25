# `memory64-lowering` out-of-range recheck

_Date:_ 2026-04-25  
_Status:_ partially superseded for high-constant wording by `docs/wiki/raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`; still valid for declaration lowering, size/grow result repair, mixed widths, max-limit clamping, local registry absence, and table64 validation prerequisites  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`, `docs/wiki/raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`, `docs/wiki/binaryen/passes/memory64-lowering/`, `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/validate/validate.mbt`

## Question

The 2026-04-24 `memory64-lowering` dossier was complete enough for a first pass, but it still carried a broad uncertainty: what exactly does Binaryen do with memory64/table64 constants, active offsets, grow deltas, and limits that do not fit the lowered 32-bit output?

That uncertainty made the shape catalog easier to misread as “everything just wraps with `i32.wrap_i64`,” which is incorrect for known-constant out-of-range operands.

## Supersession note

A later same-day source correction narrowed the wording below. Read `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md` and `docs/wiki/raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md` for the corrected split between dynamic operand constants, static `MemArg.offset` immediates, active offset expressions, and grow deltas.

## Source-backed findings

- Rechecked Binaryen `version_129` and current `main` `Memory64Lowering.cpp`, plus the paired memory and table lit files.
- Dynamic address/index operands still lower by wrapping with `i32.wrap_i64(...)`.
- Superseded wording: this note originally over-broadened the high-offset rule to known constant address/index operands and active data/element offsets. The corrected rule is that dynamic operand constants wrap; high static memory-access `offset=` immediates become `unreachable`; active offset expressions lower to the new address type without a reviewed high-active-offset trap special case.
- `memory.size` and `table.size` are still the simple lowered-`i32` result plus unsigned extension back to the apparent `i64` result.
- `memory.grow` and `table.grow` are more subtle than the old docs implied:
  - superseded wording: this note originally claimed high constant deltas become the 64-bit failure sentinel directly;
  - corrected wording: grow deltas are lowered into the wasm32 grow and the lowered grow result needs failure-sentinel repair, not only blind zero-extension.
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

- If Starshine implements the pass, add separate tests for dynamic operand wrapping, static high-`offset=` replacement, grow failure-sentinel repair, max-limit clamp, min-limit rejection/assertion policy, and active segment offset lowering. See note `0374` for the corrected operand-vs-static-offset split.
- Reconcile table64 typechecking before exposing `table64-lowering` as a supported local pass.
