---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0781-2026-06-20-heap-store-optimization-swap-constructor-global.md
  - ./0782-2026-06-20-heap-store-optimization-immutable-descriptor-swap.md
  - ./0783-2026-06-20-heap-store-optimization-swap-memory-and-pingpong.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-swap.md
  - ./0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ./0800-2026-06-20-heap-store-optimization-table-size-swap.md
  - ./0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ./0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ./0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ./0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ./0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ./0817-2026-06-20-heap-store-optimization-global-set-value-read-swap.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0822-2026-06-20-heap-store-optimization-table-grow-elem-boundaries.md
  - ./0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ./0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ./0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ./0826-2026-06-20-heap-store-optimization-multi-index-bulk-boundaries.md
  - ./0827-2026-06-20-heap-store-optimization-multi-index-copy-boundaries.md
  - ./0828-2026-06-20-heap-store-optimization-mixed-index-copy-boundaries.md
  - ./0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ./0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ./0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ./0888-2026-06-21-heap-store-optimization-cross-family-growth-swap.md
  - ./0891-2026-06-21-heap-store-optimization-call-indirect-swap-boundary.md
  - ./0927-2026-06-21-heap-store-optimization-try-table-global-set-fold.md
  - ./0979-2026-06-21-heap-store-optimization-nested-try-table-global-set.md
  - ./0980-2026-06-21-heap-store-optimization-branch-contained-try-table-global-set.md
  - ./0981-2026-06-21-heap-store-optimization-catch-taken-try-table-throw-boundary.md
  - ./0982-2026-06-21-heap-store-optimization-catchable-try-table-call-boundary.md
  - ./0984-2026-06-21-heap-store-optimization-descriptor-catchable-try-table-call-boundary.md
  - ./0985-2026-06-21-heap-store-optimization-try-table-global-set.md
  - ./0986-2026-06-21-heap-store-optimization-result-try-table-memory-fill-boundary.md
  - ./0987-2026-06-21-heap-store-optimization-result-try-table-table-global-set.md
  - ./0988-2026-06-21-heap-store-optimization-result-try-table-table-fill-boundary.md
  - ./0989-2026-06-21-heap-store-optimization-result-try-table-cross-growth-fold.md
  - ./0990-2026-06-21-heap-store-optimization-result-try-table-cross-store-fold.md
  - ./0991-2026-06-21-heap-store-optimization-result-try-table-same-effect-call-boundary.md
  - ./0992-2026-06-21-heap-store-optimization-result-try-table-same-effect-throw-boundary.md
  - ./0993-2026-06-21-heap-store-optimization-result-try-table-same-effect-call-indirect-boundary.md
  - ./0994-2026-06-21-heap-store-optimization-result-try-table-same-effect-call-ref-boundary.md
  - ./0995-2026-06-21-heap-store-optimization-result-try-table-call-ref-cross-store-boundary.md
  - ./1095-2026-06-25-heap-store-optimization-try-table-swap-audit.md
  - ./1098-2026-06-25-heap-store-optimization-call-root-barrier-audit.md
  - ./1099-2026-06-25-heap-store-optimization-trap-oldfield-audit.md
  - ./1100-2026-06-25-heap-store-optimization-result-wrapper-later-field-audit.md
  - ./1101-2026-06-25-heap-store-optimization-nontry-wrapper-swap-audit.md
  - ./1102-2026-06-25-heap-store-optimization-exact-ref-cast-blocker-audit.md
  - ./1104-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO trySwap residual audit

## Question

After the explicit `try_table` audit (`1095`), call-root audit (`1098`), trap/side-effectful old-field audit (`1099`), result-wrapper audit (`1100`), non-`try_table` wrapper audit (`1101`), exact-`ref.cast` blocker audit (`1102`), and mutable descriptor result-wrapper audit (`1104`), is HSO-G still hiding a broad `trySwap(...)` legality gap?

## Scope audited

This note consolidates source-backed `trySwap(...)` behavior where HSO moves a constructor operand, later same-field value, or replacement root across intervening roots before folding into `struct.new` / `struct.new_desc`.

Covered axes:

1. final-root and constructor-local ping-pong no-swap boundaries;
2. local/global/resource-sensitive positive swaps;
3. same-effect memory/table/bulk/passive barriers;
4. block/if/loop/br_table wrapper positives and barriers;
5. direct, indirect, and typed-function-reference call-root barriers;
6. void/result `try_table` wrapper positives and catchable boundaries; and
7. old-field side-effect preservation interactions that affect swap legality.

This does not claim every future HOT wrapper or every descriptor expression is represented. Exact descriptor `ref.cast` remains blocked by local decode/instruction surface and is not accepted as an HSO non-goal.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Final roots and constructor ping-pong | `0783`, `0799`, `0813`, `1101` | Narrow-covered: final roots do not swap, direct constructor-local ping-pong remains a no-fold boundary, and block/if/loop-wrapped unrelated constructor assignments fold where Binaryen folds. |
| Global/resource-sensitive positives | `0781`, `0782`, `0791`, `0800`-`0802`, `0816`, `0817`, `0844`, `0888`, `1101` | Narrow-covered: unrelated globals and cross-family memory/table roots can swap when Binaryen allows them; same-global and same-resource blockers remain conservative. |
| Same-effect and passive barriers | `0815`, `0818`-`0828`, `1099`, `1101` | Narrow-covered: memory/table store, fill, copy, init/drop, growth, and multi-index barriers keep `struct.set` where Binaryen keeps it; fold-positive side-effectful old fields preserve their effects under `drop`. |
| Non-`try_table` wrappers | `0814`, `0829`-`0846`, `1101` | Narrow-covered: block/if/branchless-loop/deep-wrapper/branch-containing/br_table wrappers follow the mapped cross-family-positive versus same-effect-negative split. |
| Call-root barriers | `0891`, `1098` | Narrow-covered: direct, indirect, and typed-function-reference constructor operands and overwritten old fields remain before unrelated global/table/memory store or growth roots across direct and wrapped forms when Binaryen preserves them. |
| Void/result `try_table` wrappers | `0927`, `0979`, `0980`, `0985`-`0990`, `1095` | Narrow-covered: non-throwing unrelated-root `try_table` wrappers fold while preserving valid wrapper/catch-label shape; same-effect and catchable boundaries preserve `struct.set`. |
| Catchable `try_table` calls/throws | `0981`, `0982`, `0984`, `0991`-`0995`, `1095`, `1103` | Narrow-covered: catch-taken throw/call and descriptor catchable-call wrappers remain no-fold boundaries; result-typed catchable direct/indirect/ref wrappers are covered by focused/profile evidence. |
| Result wrappers and mutable descriptors | `1100`, `1104` | Narrow-covered by sibling audits: non-tail result-wrapper splits, tail-call boundaries, and mutable descriptor `global.get` result-wrapper old-field cases are mapped outside the raw wrapper-swap notes. |
| Exact descriptor `ref.cast` | `1102` | Still blocked by local surface. Binaryen preserves `struct.set`; closure requires Starshine to run that exact probe and preserve it. |

## Narrow closure

HSO-G no longer has broad uncovered wording for the source-backed `trySwap(...)` families listed above. The remaining open scope is deliberately narrow:

- exact descriptor `ref.cast`;
- future HOT wrapper forms outside the audited block/if/loop/br_table/try_table/result-wrapper roots;
- arbitrary branch/catch/control call combinations not represented by `1095`, `1098`, `1100`, `1103`, or `1104`;
- unlisted effectful operations without Binaryen probes; and
- future Binaryen changes to swap legality or wrapper peeling.

Any future output-shape difference in these families should still be fixed unless it is inspected and documented as a semantic-safe Starshine win with benefit; this note only narrows already source-backed behavior, not all possible drift.

## Validation

Docs/status-only audit. No code changed and no tests were required for this note. The cited notes contain the focused Binaryen `version_130` probes, red/green Starshine fixes, generated profile smokes, direct compare smokes, and the narrow Starshine-win classifications used here.
