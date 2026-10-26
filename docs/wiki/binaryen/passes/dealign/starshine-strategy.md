---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../ir2/registry-map.md
  - ../optimize-added-constants/index.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../alignment-lowering/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../alignment-lowering/starshine-strategy.md
---

# Starshine Strategy For `dealign`

> **Superseded local plan:** Starshine now registers `dealign` as a module pass in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). [`src/passes/dealign.mbt`](../../../../../src/passes/dealign.mbt) implements it. The following text records the earlier port plan, not current status.

The current module pass is implemented in [`src/passes/dealign.mbt`](../../../../../src/passes/dealign.mbt) and dispatched by [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt). Its matrix and atomic regression tests are in `src/passes/binaryen133_dealign_matrix_wbtest.mbt` and `src/passes/binaryen133_dealign_red_wbtest.mbt`. The sections below preserve the earlier planning context.

## Historical port contract

If Starshine later chooses to implement or at least recognize `dealign`, the source-backed contract is small:

- add an explicit registry status for `dealign` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- keep request behavior honest until the transform exists
- implement only the reviewed Binaryen surface unless deliberately extending it:
  - `Load`
  - `Store`
  - `SIMDLoad`
- set the alignment metadata to `1`
- preserve offsets, widths, signedness, child expressions, result types, and control flow
- do not split accesses into chunks
- do not claim `SIMDStore`, atomics, or bulk-memory coverage without fresh source-backed justification

## Historical landing options

Because the pass is metadata-only, a future implementation could plausibly land in more than one place:

1. a tiny module/function traversal over Starshine's library IR memory instructions;
2. a HOT-side memory-access rewrite if HOT reliably carries all relevant memarg alignment fields; or
3. a late boundary/emit-side normalization if the main use case is testing or backend stress.

The implementation now uses a module traversal.

## Validation plan for a future port

A future local implementation should include reduced tests for:

- `i32.load` default alignment printing as `align=1`
- explicit `align=2` scalar load/store becoming `align=1`
- explicit `align=1` staying `align=1`
- offset preservation
- child-expression preservation
- source-confirmed broader `Load` / `Store` family coverage if represented locally
- `SIMDLoad` coverage only if Starshine's IR/parser surface can express and round-trip it
- negative tests documenting no `SIMDStore`, atomic, or bulk-memory rewrite unless intentionally added

Then compare the pass directly against Binaryen on focused WAT fixtures before adding any preset role.

## Current status

Starshine registers and dispatches `dealign` as a module pass. The owner rewrites non-atomic scalar, SIMD, and array memory access alignments. Atomic regression cases are covered separately.

## Sources

- [research note 0389](./index.md)
- [research note 0317](./index.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [research note 0063](../../../ir2/registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../alignment-lowering/index.md`](../alignment-lowering/index.md)
