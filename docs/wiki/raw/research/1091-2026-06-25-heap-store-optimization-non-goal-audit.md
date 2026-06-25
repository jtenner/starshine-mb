---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-swap.md
  - ./0792-2026-06-20-heap-store-optimization-unreachable-boundaries.md
  - ./0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md
  - ./0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md
  - ./0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ./0920-2026-06-21-heap-store-optimization-return-call-ref-direct-boundary.md
  - ./0921-2026-06-21-heap-store-optimization-return-call-ref-direct-active-catch.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1048-2026-06-25-heap-store-optimization-exact-ref-cast-recheck.md
  - ./1053-2026-06-25-heap-store-optimization-bottom-tail-oldfield-boundary.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# HSO explicit non-goal audit

## Question

Can HSO-H be narrowed by separating explicit source-backed non-goals from local Starshine surface blockers and previously resolved boundaries?

## Audit result

The explicit non-goal/boundary matrix is narrow and source-backed:

| Family | Current disposition | Evidence / guard |
|---|---|---|
| Array stores | Explicit HSO non-goal. Binaryen HSO is struct-allocation/store focused, not an array-store DSE pass. | Focused test `heap-store-optimization leaves array stores as an explicit non-goal` from `0790`. |
| Generic non-fresh-reference struct DSE | Explicit HSO non-goal. Repeated `struct.set` on a non-fresh reference is not removed by direct HSO. | `0867`; focused test `heap-store-optimization does not do generic struct dead-store elimination`. |
| Generic struct load forwarding | Explicit HSO non-goal. HSO does not turn a later `struct.get` into the just-written value. | `0867`; focused test `heap-store-optimization does not do generic struct load forwarding`. |
| Direct unreachable constructor / set-value roots | Explicit no-fold boundary for HSO, left to later DCE/unreachable cleanup. | `0792` and `0868`; focused tests `heap-store-optimization leaves unreachable constructors to later DCE` and `heap-store-optimization leaves unreachable set values to later DCE`. |
| Ordinary memory/table roots between fresh constructor and later store | Not a non-goal. Earlier `0790` wording was superseded by Binaryen `version_130` probes: Binaryen folds through unrelated ordinary memory/table roots when resource ordering permits. | `0791`; focused tests `heap-store-optimization folds through ordinary memory stores` and `heap-store-optimization folds through ordinary table stores`. |
| Descriptor `br_on_non_null` branch-result surface | No longer an HSO-H blocker. The old local CFG/verifier surface issue was fixed, and generated exact descriptor branch-result roots now validate and compare-smoke green. | `1041`; focused test `heap-store-optimization folds descriptor br_on_non_null result operands without aborting`; generated profile coverage remains in `fuzzing.md`. |
| Direct-root `return_call_ref` dead-store shape | Narrow documented Starshine win, not a broad non-goal. Binaryen preserves a dead `struct.set`; Starshine removes the unreachable store while preserving validation and observable behavior. | `0920`; active-catch counterpart `0921`. Reopen if Binaryen starts removing the store too, Starshine output stops validating, or a locally catchable/result-wrapper tail-call case is generalized from this direct-root shape. |
| Bottom-typed `return_call_indirect` old-field shape | Narrow unreachable-constructor cleanup boundary, not ordinary old-field preservation. | `1053`; reopen if Binaryen starts preserving the constructor/store, or Starshine regresses validation. |
| Exact descriptor `ref.cast` | Still open as a local decode/instruction-surface blocker, not an approved HSO semantic non-goal. Binaryen preserves the later `struct.set`; Starshine still fails the exact input before HSO can run. | `0869` and refreshed `1048` (`DecodeAt(InvalidS33Range, 71, 34)`). |

## Status impact

This narrows HSO-H to one active local-surface blocker plus final review:

- Closed by evidence: array-store non-goal, generic heap DSE/load-forwarding non-goals, direct unreachable no-fold boundaries, resolved descriptor `br_on_non_null` surface blocker, direct-root `return_call_ref` Starshine-win boundaries, and bottom-typed tail-call cleanup classification.
- Not closed/approved: exact descriptor `ref.cast`, because it is a Starshine decode/local instruction-surface blocker and Binaryen's observed behavior is to preserve `struct.set`.

HSO-H should remain open until the exact descriptor `ref.cast` surface is representable or explicitly approved by the user as a narrow tool/local-surface deferral with reopening criteria. This audit does not close HSO-D/E/F/G source-family work or HSO-I performance.

## Validation

Docs/status-only. No tests were required; the audit maps existing focused tests and research notes to the HSO-H backlog item.
