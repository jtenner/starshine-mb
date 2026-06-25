---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ./0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ./0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ./0796-2026-06-20-heap-store-optimization-disappearing-bad-get.md
  - ./0797-2026-06-20-heap-store-optimization-external-exits.md
  - ./0798-2026-06-20-heap-store-optimization-active-catch-throw-negative.md
  - ./0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ./0918-2026-06-21-heap-store-optimization-return-call-ref-control.md
  - ./0919-2026-06-21-heap-store-optimization-active-catch-return-call-ref.md
  - ./0920-2026-06-21-heap-store-optimization-return-call-ref-direct-boundary.md
  - ./0921-2026-06-21-heap-store-optimization-return-call-ref-direct-active-catch.md
  - ./0981-2026-06-21-heap-store-optimization-catch-taken-try-table-throw-boundary.md
  - ./0982-2026-06-21-heap-store-optimization-catchable-try-table-call-boundary.md
  - ./0984-2026-06-21-heap-store-optimization-descriptor-catchable-try-table-call-boundary.md
  - ./1028-2026-06-24-heap-store-optimization-profile-catch-throw-skip-local-set.md
  - ./1029-2026-06-24-heap-store-optimization-profile-descriptor-catch-throw.md
  - ./1030-2026-06-24-heap-store-optimization-profile-descriptor-branch-skip.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1075-2026-06-25-heap-store-optimization-fgh-boundary-audit.md
  - ./1083-2026-06-25-heap-store-optimization-br-table-micro-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO skip-local-set control micro-audit

## Question

Can the direct `LazyLocalGraph` / skip-local-set part of HSO-F be narrowed without claiming all branch, catch, descriptor, or result-wrapper behavior is complete?

## Scope audited

This audit covers only already-probed shapes where the moved `struct.set` value may contain control flow that skips the fresh-constructor `local.set`, or where an intervening control wrapper can make the later store unsafe:

1. safe function-external exits (`return`, `throw`, `return_call*`) that cannot fall through to a stale local read;
2. locally caught calls or throws that can resume in the same function before the constructor local has been assigned;
3. nested block/drop control-sequence traversal needed to see those exits;
4. Binaryen's narrow one-disappearing-bad-get exception and Starshine's explicitly documented direct-root tail-call extension;
5. loop-backedge local-read hazards; and
6. catchable `try_table` skip-local-set boundaries for ordinary and descriptor constructors, including generated profile roots.

It does **not** close arbitrary descriptor control expressions, exact descriptor `ref.cast`, all result-typed wrapper/tail-call cases, all `trySwap(...)` wrapper/effect legality, or non-local output-shape differences.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Plain function-external `return` in moved value | `0793` | Parity covered: Binaryen folds, and Starshine now folds. |
| In-function caught call/throw-like value | `0794`, `0798` | Parity covered: Binaryen preserves the later `struct.set`; Starshine blocks the fold inside active catchable regions. |
| Nested `drop(block(result ...))` control sequence | `0795` | Parity covered: nested traversal finds safe external exits and escaping branch-valued-store negatives. |
| One disappearing bad get | `0796` | Parity covered for the exact source-backed exception: the branch-only root may move before the delayed constructor assignment only when no later outside target-local read remains. |
| Conditional external `throw` / `return_call` and active-catch `return_call` | `0797` | Parity covered: external exits fold; active-catch ordinary calls remain blocked while `return_call*` is treated as function-external. |
| `return_call_ref` external and active-catch variants | `0918`, `0919` | Parity covered for the function-external skip-local-set rule; Starshine already matched. |
| Direct-root `return_call_ref` dead-store shapes | `0920`, `0921` | Narrow documented Starshine win: the tail call exits before the later `struct.set` can execute, so Starshine drops the dead store while preserving validation. This is not generalized to locally catchable/result-wrapper tail calls. |
| Loop-backedge target-local read | `0863` | Parity covered negative: Binaryen and Starshine preserve `struct.set` when a branch can re-enter a loop header that reads the target local. |
| Catch-taken `try_table` / `throw` and catchable-call `try_table` | `0981`, `0982`, `0984` | Parity covered: catchable roots that can resume before the constructor assignment keep the later `struct.set`; descriptor constructors follow the same rule after `0984`. |
| Generated skip-local-set profile roots | `1028`, `1029`, `1030`, `1041` | Generated coverage backs ordinary catch/throw, descriptor catch/throw, descriptor branch-skip, and descriptor `br_on_non_null` branch-result roots with green focused/profile/direct smokes. |

## Narrow closure

The direct skip-local-set control matrix above is narrow-closed for HSO-F:

- every listed positive/negative is backed by Binaryen `version_130` probes or generated profile notes;
- Starshine has focused tests or generated profile coverage for the listed families;
- the only intentional transform difference here is the already documented direct-root `return_call_ref` dead-store cleanup from `0920`/`0921`, with reopening criteria; and
- the `1083` `br_table` audit remains a sibling closure, not a substitute for this catch/return/backedge matrix.

HSO-F remains open for broader branch/catch source review, arbitrary descriptor control expressions, exact descriptor `ref.cast`, result-wrapper/tail-call families outside the listed direct skip-local-set paths, and any future compare mismatch not covered by this map.

## Validation

Docs/status-only micro-audit. No new code changed and no tests were required for this note. Supporting focused tests and compare smokes are recorded in the cited source notes; the most recent focused HSO test run in this thread still passed `416/416` after the preceding code slice.
