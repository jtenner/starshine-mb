---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0804-2026-06-20-heap-store-optimization-block-wrapped-swap.md
  - ./0805-2026-06-20-heap-store-optimization-block-wrapped-table-grow-swap.md
  - ./0806-2026-06-20-heap-store-optimization-block-wrapped-memory-grow-swap.md
  - ./0807-2026-06-20-heap-store-optimization-if-wrapped-memory-grow-swap.md
  - ./0808-2026-06-20-heap-store-optimization-if-wrapped-table-grow-swap.md
  - ./0809-2026-06-20-heap-store-optimization-if-wrapped-table-size-swap.md
  - ./0810-2026-06-20-heap-store-optimization-loop-wrapped-table-size-swap.md
  - ./0811-2026-06-20-heap-store-optimization-loop-wrapped-memory-grow-swap.md
  - ./0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ./0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ./0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ./0830-2026-06-20-heap-store-optimization-loop-wrapped-bulk-fill-boundaries.md
  - ./0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ./0832-2026-06-20-heap-store-optimization-wrapped-passive-boundaries.md
  - ./0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ./0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ./0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ./0836-2026-06-20-heap-store-optimization-deep-nested-growth-bulk-boundaries.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ./0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ./0839-2026-06-20-heap-store-optimization-branch-wrapper-constructor-pingpong.md
  - ./0840-2026-06-20-heap-store-optimization-branch-wrapper-bulk-fill-boundaries.md
  - ./0841-2026-06-20-heap-store-optimization-branch-wrapper-copy-boundaries.md
  - ./0842-2026-06-20-heap-store-optimization-branch-wrapper-passive-boundaries.md
  - ./0843-2026-06-20-heap-store-optimization-branch-wrapper-growth-boundaries.md
  - ./0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ./0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ./0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ./0888-2026-06-21-heap-store-optimization-cross-family-growth-swap.md
  - ./1083-2026-06-25-heap-store-optimization-br-table-micro-audit.md
  - ./1095-2026-06-25-heap-store-optimization-try-table-swap-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO non-`try_table` wrapper swap micro-audit

## Question

Can the HSO-G block/if/loop/br_table wrapper swap matrix be narrowed separately from the `try_table` wrapper audit in `1095`, so remaining HOT wrapper-peeling drift is not described as a broad unreviewed family?

## Scope audited

This note covers non-`try_table` wrappers around roots that may move before a fresh-constructor `local.set` while a later `struct.set(local.get)` folds into the constructor:

1. block-wrapped roots;
2. if-wrapped roots;
3. branchless loop-wrapped roots;
4. nested and deep nested block/if/loop wrappers;
5. branch-containing outer-block/inner-loop wrappers;
6. `br_table` wrappers already summarized by `1083`; and
7. same-resource and cross-resource table/memory/global effect distinctions.

This does **not** cover `try_table` wrappers (`1095`), call-valued roots (`1098`), result-wrapper later-field/set-value behavior (`1100`), exact descriptor `ref.cast`, or arbitrary new HOT wrapper forms outside block/if/loop/br_table.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Block wrappers around cross-family writes/growth | `0804`-`0806`, `0844`, `0888` | Parity covered: Binaryen folds safe constructor operands such as `memory.size`, `table.size`, `memory.grow`, and `table.grow` across block-wrapped unrelated global/table/memory roots when resource ordering permits; Starshine matches. |
| If wrappers around cross-family writes/growth | `0807`-`0809`, `0814` | Parity covered: if-wrapped unrelated roots and mixed nested block/if wrappers keep the same safe cross-family movement behavior as Binaryen. |
| Branchless loop wrappers | `0810`-`0812`, `0814` | Parity covered: branchless loop wrappers are safe for the probed unrelated-root positives and preserve Binaryen's fold shape. |
| Wrapped constructor ping-pong distinction | `0813`, `0839` | Parity covered: direct constructor-local-set roots remain barriers, but block/if/loop and branch-containing wrappers around unrelated constructor assignments fold like Binaryen. |
| Same-kind growth/store/resource barriers | `0815`, `0818`-`0821`, `0829`-`0833` | Parity covered boundaries: same-resource memory/table roots, bulk-memory/table roots, passive data/element roots, and table-set/table-size conflicts remain no-fold barriers even when wrapped. |
| Nested and deep nested wrappers | `0834`-`0836` | Parity covered: nested and deeper block/if/loop wrappers preserve the same side-effecting growth/passive/bulk no-fold boundaries as their shallow counterparts. |
| Branch-containing wrappers | `0837`-`0843` | Parity covered: branch-containing unrelated-global positives and same-effect/passive/bulk/growth boundaries are explicit; Starshine already matched the Binaryen probes. |
| `br_table` wrappers | `0845`, `0846`, `1083` | Narrow-closed by `1083`: cross-family ordinary-store positives and same-effect/growth wrapper negatives are mapped to focused tests and source probes. |

## Narrow closure

The non-`try_table` wrapper matrix above is narrow-closed for block, if, branchless loop, nested block/if/loop, branch-containing outer-block/inner-loop, and `br_table` wrappers over the listed memory/table/global effect families:

- cross-family ordinary-store and growth positives are separated from same-resource barriers;
- direct constructor ping-pong remains distinct from wrapper-contained unrelated constructor assignments;
- branch-containing wrappers are covered explicitly rather than inferred from branchless wrappers; and
- `br_table` stays linked to `1083` so its narrow Starshine win and escaping-local negative remain visible.

HSO-G remains open for `try_table` only through the separate `1095` reopening criteria, call-root barriers through `1098`, result-wrapper behavior through `1100`, exact descriptor `ref.cast`, arbitrary branch/catch/control call shapes, unlisted effect families, and future HOT wrapper forms not represented by block/if/loop/br_table.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited coverage notes contain the focused Binaryen `version_130` probes and Starshine focused-test evidence for each wrapper family.
