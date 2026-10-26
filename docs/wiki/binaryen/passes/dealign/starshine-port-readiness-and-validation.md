---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/show.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../alignment-lowering/starshine-port-readiness-and-validation.md
---

# `dealign`: Starshine port readiness and validation

> **Superseded local plan:** Starshine now registers `dealign` as a module pass in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). [`src/passes/dealign.mbt`](../../../../../src/passes/dealign.mbt) implements it. The following text records the earlier port plan, not current status.

The pass is implemented and dispatched. See [`./starshine-strategy.md`](./starshine-strategy.md) for current status. The following plan records earlier implementation and validation guidance.

## Faithful target

A faithful Starshine port should match Binaryen's small source-backed contract:

1. recognize `dealign` only after choosing an honest registry status;
2. visit memory-access nodes equivalent to Binaryen `Load`, `Store`, and eventually `SIMDLoad`;
3. set the access memarg alignment to `1`;
4. preserve offset, memory index, width, sign, address child, stored-value child, result type, control flow, and traps;
5. avoid chunk splitting, helper locals, and address rewriting; and
6. keep `SIMDStore`, atomics, and bulk-memory outside the pass unless a fresh upstream source review or explicit local divergence says otherwise.

## Historical local substrate

Starshine already carries most of the representation needed for a small scalar first slice:

| Surface | Code location | Why it matters |
| --- | --- | --- |
| Pass registry status | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `dealign` is now registered as a module pass. |
| Dispatch | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | The pass manager now dispatches `dealign` to its module implementation. |
| Text memarg parsing | [`src/wast/parser.mbt:1323-1342`](../../../../../src/wast/parser.mbt#L1323-L1342) | Parses `offset=` and `align=` fields before lowering. |
| Text-to-library lowering | [`src/wast/lower_to_lib.mbt:207-229`](../../../../../src/wast/lower_to_lib.mbt#L207-L229) | Converts text alignment bytes to exponent-form `@lib.MemArg`; `align=1` is exponent `0`. |
| Library IR memarg | [`src/lib/types.mbt:8191-8193`](../../../../../src/lib/types.mbt#L8191-L8193) | Stores alignment, optional memory index, and offset in the shared representation a simple module traversal could update. |
| WAT printing | [`src/lib/show.mbt:788-790`](../../../../../src/lib/show.mbt#L788-L790) | Printed output exposes the memarg alignment, so focused WAT comparisons can prove the pass. |
| Validation | [`src/validate/typecheck.mbt:1543-1568`](../../../../../src/validate/typecheck.mbt#L1543-L1568) | Validates alignment exponent bounds; setting exponent `0` is within bounds for ordinary nonzero-width memory accesses. |

## Suggested first slice

Start with the smallest observable change:

1. Add `dealign` as boundary-only or removed if the project only wants honest tracking. Stop there if no implementation is planned.
2. If implementing, add reduced scalar tests first:
   - `i32.load align=4` prints or compares as `align=1` after `--pass dealign`.
   - `i32.store align=4` prints or compares as `align=1`.
   - `offset=` is preserved.
   - already-`align=1` cases remain `align=1`.
   - child expressions are not duplicated or reordered.
3. Implement a library-IR traversal that rewrites ordinary load/store memargs to exponent `0`.
4. Compare focused fixtures against Binaryen `wasm-opt --dealign`.
5. Only then widen to all scalar `Load` / `Store` opcodes represented locally.

This order avoids pretending the HOT pipeline already preserves every alignment-bearing family.

## SIMDLoad slice

Binaryen source covers `SIMDLoad`, but the dedicated lit file does not isolate it. For Starshine, treat SIMD as a separate slice:

- audit parser, library IR, binary codec, validator, and HOT round-trip support for SIMD memory loads;
- add explicit reduced fixtures before changing implementation;
- compare against Binaryen on `v128.load align=16` to `align=1` if the local surface supports it; and
- keep `SIMDStore` negative unless upstream adds a visitor or Starshine intentionally diverges.

## Validation ladder

A future local port should sign off in layers:

1. **Registry behavior:** the pass is now active; registry and dispatch behavior require coverage.
2. **Reduced WAT fixtures:** scalar load/store, offset preservation, idempotent `align=1`, and child-expression preservation.
3. **Binaryen oracle:** focused `wasm-opt --dealign` comparisons on the same fixtures.
4. **Negative fixtures:** `memory.copy`, `memory.fill`, atomics, and `SIMDStore` should not be rewritten by the faithful first port.
5. **Neighborhood checks:** rerun nearby memory-pass fixtures for [`alignment-lowering`](../alignment-lowering/index.md), [`memory64-lowering`](../memory64-lowering/index.md), and [`llvm-memory-copy-fill-lowering`](../llvm-memory-copy-fill-lowering/index.md) if the implementation touches shared memarg traversal code.
6. **Fuzzing:** only after focused fixtures pass, compare `--pass dealign` against Binaryen with a memory-heavy corpus.

## Pitfalls

- Do not reuse `alignment-lowering` tests as if they prove `dealign`. That sibling splits weak accesses; `dealign` only weakens metadata.
- Do not interpret text `align=1` as the stored library value `1`; in Starshine lowering, `align=1` becomes exponent `0`.
- Do not overclaim SIMD test evidence. It is source-confirmed in Binaryen, not separately shown by the reviewed dedicated lit file.
- Do not add broad memory-op visitors just because the pass name sounds generic.

## Bottom line

`dealign` is a good tiny future pass only if kept tiny: registry honesty first, scalar memarg exponent-to-`0` rewrite second, source-confirmed `SIMDLoad` only after a local round-trip audit, and no chunk-splitting or bulk-memory behavior.
