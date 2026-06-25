---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ./0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ./0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ./0797-2026-06-20-heap-store-optimization-external-exits.md
  - ./0798-2026-06-20-heap-store-optimization-active-catch-throw-negative.md
  - ./0862-2026-06-20-heap-store-optimization-br-table-local-escape.md
  - ./0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ./0918-2026-06-21-heap-store-optimization-return-call-ref-external-branch.md
  - ./0919-2026-06-21-heap-store-optimization-return-call-ref-active-catch.md
  - ./0981-2026-06-21-heap-store-optimization-catch-taken-try-table-throw-boundary.md
  - ./0982-2026-06-21-heap-store-optimization-catchable-try-table-call-boundary.md
  - ./0984-2026-06-21-heap-store-optimization-descriptor-catchable-try-table-call-boundary.md
  - ./0996-2026-06-21-heap-store-optimization-result-try-table-return-call-ref-boundary.md
  - ./0999-2026-06-21-heap-store-optimization-result-try-table-return-call-boundary.md
  - ./1000-2026-06-21-heap-store-optimization-result-try-table-return-call-indirect-boundary.md
  - ./1018-2026-06-21-heap-store-optimization-later-field-result-try-table-tail-call-boundary.md
  - ./1028-2026-06-24-heap-store-optimization-profile-catch-throw-skip-local-set.md
  - ./1029-2026-06-24-heap-store-optimization-profile-descriptor-catch-throw.md
  - ./1030-2026-06-24-heap-store-optimization-profile-descriptor-branch-skip.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1094-2026-06-25-heap-store-optimization-skip-local-control-audit.md
  - ./1095-2026-06-25-heap-store-optimization-try-table-swap-audit.md
  - ./1100-2026-06-25-heap-store-optimization-result-wrapper-later-field-audit.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO catch/control skip-local-set micro-audit

## Question

Can the remaining HSO-F arbitrary branch/catch wording be narrowed after the direct skip-local-set audit in `1094`, the `try_table` wrapper audit in `1095`, and the result-wrapper audit in `1100`?

## Scope audited

This note covers control-flow roots whose execution can skip the fresh-struct local assignment before a later `struct.set(local.get)`:

1. locally caught calls and throws;
2. function-external exits (`return`, `throw` outside a local catch, and `return_call*`);
3. nested control sequences and branch-valued moved stores;
4. direct `br_table` / loop-backedge local-read hazards;
5. catchable `try_table` throw/call boundaries; and
6. generated catch/branch descriptor roots in the dedicated HSO profile.

This does **not** close exact descriptor `ref.cast`, unlisted control instructions, future exception proposal spellings not represented in Starshine's local surface, or arbitrary combinations of catchable control with unlisted descriptor/later-field expressions.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Locally caught calls/throws | `0794`, `0798`, `0981`, `0982`, `0984` | Parity covered: calls, throws, and descriptor constructors inside an active/catchable `try_table` remain conservative when local catch control can skip the fresh assignment; Starshine matches after the `0794` and `0984` fixes. |
| Function-external exits | `0793`, `0795`, `0797`, `0918`, `0919`, `1094` | Parity covered for listed shapes: direct `return`, external `throw`, and `return_call*` exits can fold when no in-function catch observes the skipped local assignment. Active-catch `return_call*` remains fold-positive because the tail call exits rather than transferring to the local catch. |
| Nested control sequences and branch-valued stores | `0795`, `0862`, `0863`, `1094` | Narrow-covered: Starshine traverses Binaryen-lit-style `drop(block(result ...))` roots, preserves escaping branch-valued store negatives, preserves loop-backedge target-local-read negatives, and records the no-later-local-read `br_table` fold as a narrow Starshine win with reopening criteria. |
| Catchable `try_table` wrapper boundaries | `0981`, `0982`, `0984`, `1095` | Narrow-covered: catch-taken throw, catchable call, and descriptor catchable-call wrappers preserve the constructor/local assignment and later `struct.set`, while non-throwing unrelated-root `try_table` positives stay under `1095`. |
| Result-wrapper tail/call boundaries | `0996`, `0999`, `1000`, `1018`, `1100` | Narrow-covered outside this note: result-typed wrappers with tail calls stay no-fold even when direct-root tail-call exits may be Starshine wins. This prevents broadening direct skip-local-set logic into locally catchable result wrappers. |
| Generated control roots | `1028`, `1029`, `1030`, `1041` | Profile covered: generated ordinary catch/throw, descriptor catch/throw, descriptor branch skip-local-set, and exact descriptor `br_on_non_null` roots now run through HSO, validate, and compare-smoke green. |

## Narrow closure

The catch/control skip-local-set matrix above is narrow-closed for the listed source-backed roots. HSO-F no longer needs broad wording for:

- direct caught-call and active-catch throw negatives;
- external-return/throw/tail-call positives;
- nested control-sequence traversal;
- `br_table` escaping-local and loop-backedge local-read hazards;
- catchable `try_table` call/throw boundaries, including descriptor constructors; or
- generated descriptor catch/branch roots already represented in the HSO profile.

HSO-F remains open for exact descriptor `ref.cast`, control instructions not represented by the cited probes, arbitrary descriptor/later-field expressions combined with catch/control roots, future exception-control surface changes, and any source-backed Binaryen behavior not yet mapped to a focused test/profile root.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited research notes contain the red/green fixes, focused Binaryen `version_130` probes, profile smokes, and direct compare evidence for the covered families.
