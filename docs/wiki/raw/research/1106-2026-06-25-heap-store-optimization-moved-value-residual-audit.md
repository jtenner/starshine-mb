---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0854-2026-06-20-heap-store-optimization-target-local-write-negative.md
  - ./0855-2026-06-20-heap-store-optimization-target-local-chain-variants.md
  - ./0857-2026-06-20-heap-store-optimization-descriptor-target-local-hazard.md
  - ./0858-2026-06-20-heap-store-optimization-descriptor-target-local-write-hazard.md
  - ./0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md
  - ./0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md
  - ./0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md
  - ./0871-2026-06-20-heap-store-optimization-mutable-descriptor-global.md
  - ./0872-2026-06-20-heap-store-optimization-descriptor-select-call-condition.md
  - ./0873-2026-06-20-heap-store-optimization-later-field-select-call-condition.md
  - ./0874-2026-06-20-heap-store-optimization-later-field-if-call-condition.md
  - ./0875-2026-06-20-heap-store-optimization-later-field-block-br-if-call-condition.md
  - ./0876-2026-06-20-heap-store-optimization-descriptor-block-br-if-call-condition.md
  - ./0877-2026-06-20-heap-store-optimization-descriptor-block-br-if-pure-condition.md
  - ./0878-2026-06-20-heap-store-optimization-later-field-block-br-if-pure-condition.md
  - ./0879-2026-06-21-heap-store-optimization-later-field-select-trap-condition.md
  - ./0880-2026-06-21-heap-store-optimization-descriptor-select-trap-condition.md
  - ./0881-2026-06-21-heap-store-optimization-descriptor-if-trap-condition.md
  - ./0882-2026-06-21-heap-store-optimization-later-field-if-trap-condition.md
  - ./0883-2026-06-21-heap-store-optimization-later-field-block-br-if-trap-condition.md
  - ./0884-2026-06-21-heap-store-optimization-descriptor-block-br-if-trap-condition.md
  - ./0886-2026-06-21-heap-store-optimization-descriptor-old-field-call-barrier.md
  - ./0887-2026-06-21-heap-store-optimization-plain-old-field-call-barrier.md
  - ./0889-2026-06-21-heap-store-optimization-default-desc-starshine-win.md
  - ./0890-2026-06-21-heap-store-optimization-default-starshine-win.md
  - ./1011-2026-06-23-heap-store-optimization-mutable-descriptor-result-wrapper.md
  - ./1012-2026-06-23-heap-store-optimization-mutable-descriptor-call-ref.md
  - ./1015-2026-06-21-heap-store-optimization-later-field-result-try-table-call-split.md
  - ./1016-2026-06-21-heap-store-optimization-later-field-result-try-table-call-ref-split.md
  - ./1017-2026-06-21-heap-store-optimization-later-field-result-try-table-call-indirect-split.md
  - ./1018-2026-06-21-heap-store-optimization-later-field-result-try-table-tail-call-boundary.md
  - ./1022-2026-06-21-heap-store-optimization-default-desc-catchable-later-field-result-try-table-store-boundary.md
  - ./1055-2026-06-25-heap-store-optimization-mutable-default-descriptor-oldfield.md
  - ./1089-2026-06-25-heap-store-optimization-target-local-hazard-audit.md
  - ./1096-2026-06-25-heap-store-optimization-descriptor-later-field-barrier-audit.md
  - ./1100-2026-06-25-heap-store-optimization-result-wrapper-later-field-audit.md
  - ./1102-2026-06-25-heap-store-optimization-exact-ref-cast-blocker-audit.md
  - ./1104-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO moved-value hazard residual audit

## Question

After the target-local (`1089`), descriptor/later-field (`1096`), result-wrapper (`1100`), exact-`ref.cast` (`1102`), and mutable-descriptor old-field (`1104`) audits, is HSO-E still hiding a broad moved-value hazard gap?

## Scope audited

This note consolidates source-backed moved-value hazards where a same-field `struct.set` could be folded into a fresh constructor only if doing so preserves Binaryen-observable ordering:

1. moved values that read or write the target local;
2. descriptor and later-constructor-field operands that read locals/globals or have pure/effectful/trapping `select` / `if` / block-`br_if` conditions;
3. mutable descriptor `global.get` splits;
4. old-field plus later-field call ordering;
5. result-typed wrapper later-field and set-value splits; and
6. default/default-descriptor double-call Starshine wins.

This is a residual audit, not a new oracle probe. It does **not** close exact descriptor `ref.cast`, unlisted descriptor/later-field expressions, future GC descriptor operators, or arbitrary combinations not represented by the cited source-backed matrices.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Direct target-local hazards | `0854`, `0855`, `0857`, `0858`, `1089` | Narrow-covered: moved-value target-local reads/writes, chain variants, and descriptor-constructor target-local read/write hazards are mapped to focused Binaryen `version_130` probes and Starshine tests. |
| Descriptor/later-field local/global hazards | `0859`, `0860`, `0861`, `1096` | Narrow-covered: Starshine matches Binaryen's target-local-read positive, unrelated-global positives, and same-global conflict blockers for later fields and descriptor operands. |
| Pure/effectful/trapping condition splits | `0872`-`0884`, `1096` | Narrow-covered: pure `select` / `if` / block-`br_if` operands can fold where Binaryen folds; call-valued and trapping conditions preserve `struct.set` where Binaryen preserves ordering. |
| Mutable descriptor reads | `0871`, `1011`, `1012`, `1104` | Narrow-covered for mutable descriptor `global.get`: pure moved values can fold where Binaryen folds, while call-valued or locally catchable wrapper contexts preserve the descriptor read and later `struct.set`. |
| Old-field plus later-field call ordering | `0886`, `0887`, `1096` | Narrow-covered: old-field call preservation does not license moving a later same-field call before another later constructor-field call; plain and descriptor constructors match Binaryen. |
| Result-wrapper later fields and set values | `1015`-`1018`, `1022`, `1100`, `1055` | Narrow-covered: non-tail pure set values fold, non-tail call-valued moved values preserve `struct.set`, tail-call wrappers stay no-fold, and default/mutable-default descriptor catchable wrappers preserve ordering. |
| Default double-call Starshine wins | `0889`, `0890` | Narrow documented wins: Starshine folds both call-valued stores into materialized default constructors while preserving call order; this is not generalized to mutable/effectful/trapping descriptors or target-local hazards. |
| Exact descriptor `ref.cast` | `1102` | Still blocked by local decode/instruction surface. Binaryen preserves `struct.set`; Starshine must run the exact probe and preserve it before this residual can close. |

## Narrow closure

HSO-E no longer has broad uncovered wording for source-backed moved-value hazards in the listed matrices. The current covered contract is:

- target-local reads and writes are rejected unless the exact source-backed chain variant is safe;
- local/global descriptor and later-field hazards follow Binaryen's directional effect/resource split;
- pure/effectful/trapping condition families are separated rather than folded under a generic wrapper rule;
- mutable descriptor `global.get` result-wrapper contexts remain conservative;
- old-field side-effect preservation never overrides later-field call ordering; and
- documented default-constructor Starshine wins remain narrow and call-order-preserving.

HSO-E remains open for exact descriptor `ref.cast`, arbitrary descriptor/later-field expressions outside the audited local/global/select/if/block-`br_if`/result-wrapper/default matrices, future descriptor operators, and source-backed moved-value hazards not yet represented in focused tests or the dedicated profile.

## Validation

Docs/status-only audit. No code changed and no tests were required for this note. The cited notes contain the focused Binaryen `version_130` probes, red/green Starshine fixes where needed, and compare/profile evidence for the covered families.
