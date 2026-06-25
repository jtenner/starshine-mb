---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md
  - ./0859-2026-06-20-heap-store-optimization-descriptor-later-field-local-read.md
  - ./0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md
  - ./0861-2026-06-20-heap-store-optimization-descriptor-later-field-global-write.md
  - ./0864-2026-06-20-heap-store-optimization-descriptor-select.md
  - ./0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md
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
  - ./1074-2026-06-25-heap-store-optimization-de-hazard-audit.md
  - ./1089-2026-06-25-heap-store-optimization-target-local-hazard-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO descriptor/later-field barrier micro-audit

## Question

Can the descriptor and later-field expression barrier part of HSO-D/E be narrowed using the focused Binaryen `version_130` probes already landed, without claiming arbitrary descriptor-expression parity?

## Scope audited

This note covers the enumerated descriptor and later-constructor-field expression families that determine whether a moved same-field store value may be evaluated before descriptor operands or later fields:

1. target-local-free later fields that read the constructor local;
2. same-global versus unrelated-global read/write splits;
3. mutable descriptor-global pure/effectful moved-value splits;
4. descriptor/later-field `select`, `if`, and value-carrying block `br_if` condition splits for pure, call-effectful, and trapping conditions;
5. descriptor `ref.as_non_null` trap ordering; and
6. old-field preservation interacting with later-field call barriers.

This does **not** close exact descriptor `ref.cast`, arbitrary descriptor expressions outside the listed `select` / `if` / block-`br_if` / `ref.as_non_null` shapes, result-typed `try_table` families already covered separately, or broad old-field combinations outside the listed call-barrier interaction.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Descriptor/default chain with later-field call barrier | `0856` | Parity covered: safe default+descriptor chain stores fold, but descriptor stores stay blocked when a later constructor field call orders before a moved call value. |
| Later field reads target local while moved value has no local-state effect | `0859` | Parity covered positive: Binaryen folds despite the later-field target-local read; Starshine now matches. Direct target-local moved-value hazards remain covered separately by `1089`. |
| Later-field same/unrelated global read/write split | `0860`, `0861` | Parity covered: unrelated global read/write combinations fold, same-global conflicts preserve the later `struct.set`. |
| Pure descriptor `select` and block `br_if` operands | `0864`, `0877` | Parity covered positives: immutable descriptor globals selected or branched under pure conditions do not block folding. |
| Mutable descriptor-global split | `0871` | Parity covered: pure moved values fold across a mutable descriptor read; call-valued moved values remain blocked. |
| Call-condition descriptor/later-field select/if/block boundaries | `0872`-`0876` | Parity covered negatives: a call condition in descriptor or later-field control keeps the later `struct.set` because the moved call would cross another call. |
| Pure later-field block `br_if` condition | `0878` | Parity covered positive: pure branch/drop operands do not block folding. |
| Trapping descriptor/later-field select/if/block conditions | `0879`-`0884` | Parity covered negatives: folding a call-valued moved store before a possible trap is blocked. |
| Descriptor `ref.as_non_null` operand | `0865` | Parity covered negative: nullable descriptor trap ordering keeps the later `struct.set`. |
| Old-field side effects plus later-field call barrier | `0886`, `0887` | Parity covered: preserving old-field calls under `drop` does not permit moving a later call-valued store before another later constructor-field call, for descriptor or plain constructors. |

## Narrow closure

The descriptor/later-field barrier matrix above is narrow-closed for the enumerated expressions:

- every row is tied to a Binaryen `version_130` probe and focused Starshine test;
- the pure/effectful/trapping split is recorded explicitly instead of collapsing it into broad effect-mask drift;
- same-resource/same-global conflicts remain distinct from unrelated-resource positives; and
- the target-local hazard micro-audit in `1089` remains separate from the later-field target-local-read positive in `0859`.

HSO-D/E remain open for exact descriptor `ref.cast`, arbitrary descriptor expressions beyond this list, broader default/descriptor and old-field combinations, result-wrapper/tail-call interactions outside their own audits, and any future Binaryen source change to `Effects::orderedBefore(...)` or descriptor operand handling.

## Validation

Docs/status-only micro-audit. No new code changed and no tests were required for this note. The latest supporting focused HSO test run in this thread remains the prior `416/416` pass; cited source notes contain the individual focused test and Binaryen probe evidence.
