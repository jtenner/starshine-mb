---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/ir/eh-utils.h
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/ir/eh-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten-eh-legacy.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
  - ../research/1555-2026-07-06-optimize-instructions-final-repair-blocker.md
---

# Binaryen `version_130` `flatten` legacy EH repair refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Pass owner: `src/passes/Flatten.cpp`
- Repair owner: `src/ir/eh-utils.h` and `src/ir/eh-utils.cpp`
- Direct fixture: `test/lit/passes/flatten-eh-legacy.wast`

## Exact Binaryen repair contract

`Flatten::visitFunction` always invokes `EHUtils::handleBlockNestedPops(...)` after attaching final preludes. The helper is specific, not a general EH cleanup:

- it finds the catch payload `pop` only along the catch body's first-descendant execution line;
- it does not descend into inner catch bodies, whose pops belong to those inner catches;
- it rejects loop nesting because the payload pop cannot execute more than once;
- a block makes the pop repair-sensitive when the block cannot disappear on writeback, including a branch targeting the implicit catch block;
- repair allocates a local of the pop's exact type, inserts `local.set(new, pop)` immediately after the catch, and replaces the old nested pop with `local.get(new)`.

The `try_catch_pop_fixup` lit case is the minimal proof: flatten-created block structure would leave the catch payload pop nested, so the final helper moves the pop to the catch entry before the nested blocks.

## Starshine representation boundary

Starshine currently has HOT `Try`, `Catch`, `CatchAll`, `Rethrow`, and `Delegate` operation kinds, but the executable lib/HOT lift-lower surface does not expose Binaryen's first-class typed catch-payload `Pop` expression. Legacy `Try` focused tests are manually constructed HOT shapes; current instruction lift supports `TryTable`, not Binaryen legacy `Try` plus payload-pop syntax.

Therefore a real `handleBlockNestedPops` port cannot yet identify the pop, prove its exact type, move it to catch entry, or replace its old position. Treating every catch-region value as the payload would be unsound.

## Local prerequisite slice

Internal `flatten` now classifies two missing prerequisites before mutation:

- `needs_catch_payload_tracking` for legacy `Catch` / `CatchAll` markers;
- `needs_exceptional_transfer_repair` for `Rethrow` / `Delegate` control.

The classifier is the authoritative fail-closed gate used by legacy-try admission. It does not claim repair is implemented. Reopen real repair only after HOT/lib can represent or soundly identify typed catch payload consumption and after a red fixture proves entry extraction, one evaluation, exact type, nested-catch exclusion, and validation.

Public `flatten` wiring remains removed.
