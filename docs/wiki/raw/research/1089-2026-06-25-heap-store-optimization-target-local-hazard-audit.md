---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0854-2026-06-20-heap-store-optimization-target-local-write-negative.md
  - ./0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md
  - ./0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md
  - ./0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md
  - ./1074-2026-06-25-heap-store-optimization-de-hazard-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO target-local hazard micro-audit

## Question

Can the source-backed target-local hazard part of HSO-E be narrow-closed without claiming broader moved-value or descriptor/later-field hazard parity?

## Answer

Yes, for the direct and descriptor target-local hazard matrix covered by `0854`, `0855`, `0857`, and `0858`.

Binaryen `version_130` rejects folds when moving the later `struct.set` value would read or write the same local that holds the fresh struct before the constructor assignment is safely consumed. The focused probes and tests cover:

| Family | Source note | Binaryen behavior | Starshine coverage |
|---|---|---|---|
| Plain moved value writes target local | `0854` | Preserve the later `struct.set`; folding would change which object later local reads observe. | `heap-store-optimization keeps struct.set when the moved value writes the target local` |
| Plain moved value reads target local | pre-existing focused coverage cited by `0855`/tests | Preserve the later `struct.set`; folding would read the local too early. | `heap-store-optimization keeps struct.set when the moved value reads the target local` and nested-block variant |
| Chain: first moved value writes target local | `0855` | Preserve both chain stores. | `heap-store-optimization keeps chain stores when a moved value writes the target local` |
| Chain: earlier harmless store before later target-local read hazard | `0855` | Fold the earlier harmless store, preserve the later target-local-read store. | `heap-store-optimization folds earlier chain stores before a later target-local read hazard` |
| Descriptor constructor, moved value reads target local | `0857` | Preserve the later `struct.set`; descriptor operands do not relax the target-local read hazard. | `heap-store-optimization keeps descriptor store when moved value reads target local` |
| Descriptor constructor, moved value writes target local | `0858` | Preserve the later `struct.set`; descriptor operands do not relax the target-local write hazard. | `heap-store-optimization keeps descriptor store when moved value writes target local` |

This closes only the target-local submatrix above. HSO-E remains open for broader moved-value hazard combinations, arbitrary descriptor/later-field expression barriers, exact descriptor `ref.cast` interaction once Starshine can decode/represent it, result-wrapper splits, and the narrow default double-fold Starshine-win boundaries that must not be generalized.

## Validation

Focused HSO tests were rerun for this audit:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `416/416` passed.

No behavior changed; no direct compare was required for this status-only source/test mapping.

## Reopening criteria

Reopen this target-local submatrix if:

- a newer explicit Binaryen oracle folds one of the preserved target-local read/write hazards;
- Starshine loses any focused target-local positive/negative listed above;
- a future direct compare exposes a target-local mismatch not covered by this matrix; or
- exact descriptor `ref.cast` support lands and shows a target-local interaction not covered by the plain/descriptor constructor cases above.
