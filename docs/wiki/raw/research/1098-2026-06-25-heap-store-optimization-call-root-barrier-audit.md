---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0891-2026-06-21-heap-store-optimization-call-indirect-swap-boundary.md
  - ./0914-2026-06-21-heap-store-optimization-call-ref-constructor-boundary.md
  - ./0915-2026-06-21-heap-store-optimization-call-ref-old-field-boundary.md
  - ./0916-2026-06-21-heap-store-optimization-call-ref-table-set-boundary.md
  - ./0917-2026-06-21-heap-store-optimization-call-ref-old-field-table-set-boundary.md
  - ./0923-2026-06-21-heap-store-optimization-call-old-field-store-boundary.md
  - ./0924-2026-06-21-heap-store-optimization-call-indirect-table-set-boundary.md
  - ./0925-2026-06-21-heap-store-optimization-call-indirect-old-field-store-boundary.md
  - ./0926-2026-06-21-heap-store-optimization-call-indirect-memory-store-boundary.md
  - ./0928-2026-06-21-heap-store-optimization-call-constructor-store-boundary.md
  - ./0929-2026-06-21-heap-store-optimization-call-old-field-memory-boundary.md
  - ./0930-2026-06-21-heap-store-optimization-call-ref-memory-store-boundary.md
  - ./0931-2026-06-21-heap-store-optimization-call-constructor-growth-boundary.md
  - ./0932-2026-06-21-heap-store-optimization-call-indirect-growth-boundary.md
  - ./0933-2026-06-21-heap-store-optimization-call-ref-growth-boundary.md
  - ./0934-2026-06-21-heap-store-optimization-call-indirect-old-field-growth-boundary.md
  - ./0935-2026-06-21-heap-store-optimization-call-old-field-growth-boundary.md
  - ./0936-2026-06-21-heap-store-optimization-block-call-store-boundary.md
  - ./0937-2026-06-21-heap-store-optimization-block-call-growth-boundary.md
  - ./0938-2026-06-21-heap-store-optimization-block-call-indirect-store-boundary.md
  - ./0939-2026-06-21-heap-store-optimization-block-call-indirect-growth-boundary.md
  - ./0940-2026-06-21-heap-store-optimization-block-call-ref-store-boundary.md
  - ./0941-2026-06-21-heap-store-optimization-block-call-ref-growth-boundary.md
  - ./0942-2026-06-21-heap-store-optimization-block-call-ref-old-field-store-boundary.md
  - ./0943-2026-06-21-heap-store-optimization-block-call-ref-old-field-growth-boundary.md
  - ./0944-2026-06-21-heap-store-optimization-block-call-indirect-old-field-store-boundary.md
  - ./0945-2026-06-21-heap-store-optimization-block-call-indirect-old-field-growth-boundary.md
  - ./0946-2026-06-21-heap-store-optimization-if-call-old-field-store-boundary.md
  - ./0947-2026-06-21-heap-store-optimization-if-call-old-field-growth-boundary.md
  - ./0948-2026-06-21-heap-store-optimization-if-call-indirect-old-field-store-boundary.md
  - ./0949-2026-06-21-heap-store-optimization-if-call-indirect-old-field-growth-boundary.md
  - ./0950-2026-06-21-heap-store-optimization-if-call-ref-old-field-store-boundary.md
  - ./0951-2026-06-21-heap-store-optimization-if-call-ref-old-field-growth-boundary.md
  - ./0952-2026-06-21-heap-store-optimization-loop-call-old-field-store-boundary.md
  - ./0953-2026-06-21-heap-store-optimization-loop-call-old-field-growth-boundary.md
  - ./0954-2026-06-21-heap-store-optimization-loop-call-indirect-old-field-store-boundary.md
  - ./0955-2026-06-21-heap-store-optimization-loop-call-indirect-old-field-growth-boundary.md
  - ./0956-2026-06-21-heap-store-optimization-loop-call-ref-old-field-store-boundary.md
  - ./0957-2026-06-21-heap-store-optimization-loop-call-ref-old-field-growth-boundary.md
  - ./0958-2026-06-21-heap-store-optimization-loop-call-constructor-store-boundary.md
  - ./0959-2026-06-21-heap-store-optimization-loop-call-constructor-growth-boundary.md
  - ./0960-2026-06-21-heap-store-optimization-loop-call-indirect-constructor-store-boundary.md
  - ./0961-2026-06-21-heap-store-optimization-loop-call-indirect-constructor-growth-boundary.md
  - ./0962-2026-06-21-heap-store-optimization-loop-call-ref-constructor-store-boundary.md
  - ./0963-2026-06-21-heap-store-optimization-loop-call-ref-constructor-growth-boundary.md
  - ./0964-2026-06-21-heap-store-optimization-branch-loop-call-constructor-store-boundary.md
  - ./0965-2026-06-21-heap-store-optimization-branch-loop-call-constructor-growth-boundary.md
  - ./0966-2026-06-21-heap-store-optimization-branch-loop-call-indirect-constructor-store-boundary.md
  - ./0967-2026-06-21-heap-store-optimization-branch-loop-call-indirect-constructor-growth-boundary.md
  - ./0968-2026-06-21-heap-store-optimization-branch-loop-call-ref-constructor-store-boundary.md
  - ./0969-2026-06-21-heap-store-optimization-branch-loop-call-ref-constructor-growth-boundary.md
  - ./0970-2026-06-21-heap-store-optimization-branch-loop-call-old-field-store-boundary.md
  - ./0971-2026-06-21-heap-store-optimization-branch-loop-call-old-field-growth-boundary.md
  - ./0972-2026-06-21-heap-store-optimization-branch-loop-call-indirect-old-field-store-boundary.md
  - ./0973-2026-06-21-heap-store-optimization-branch-loop-call-indirect-old-field-growth-boundary.md
  - ./0974-2026-06-21-heap-store-optimization-branch-loop-call-ref-old-field-store-boundary.md
  - ./0975-2026-06-21-heap-store-optimization-branch-loop-call-ref-old-field-growth-boundary.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO call-root barrier micro-audit

## Question

Can the broad call-valued constructor-operand and call-valued old-field boundary matrix be narrowed for HSO-D/G using the focused Binaryen `version_130` probes from `0891` and `0914`-`0975`?

## Scope audited

This note covers call-bearing values that Binaryen treats as no-swap/no-fold boundaries across intervening global/table/memory roots:

1. direct `call`, `call_indirect`, and typed-function-reference `call_ref` constructor operands;
2. direct/indirect/typed-function-reference overwritten old fields;
3. intervening unrelated mutable `global.set`, `table.set`, `i32.store`, `memory.grow`, and `table.grow` roots;
4. block-wrapped call roots;
5. if-wrapped old-field call roots;
6. branchless loop-wrapped constructor and old-field call roots; and
7. branch-containing outer-block/inner-loop constructor and old-field call roots.

This does **not** cover `try_table` result-wrapper call boundaries already narrow-audited in `1086` and `1095`, direct-root dead tail-call Starshine wins from `0920`/`0921`, pure/trapless contained-control old-field folds from `0978`, or arbitrary call-like branch/catch combinations outside the listed wrappers.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Direct unwrapped call roots across table/global roots | `0914`-`0917`, `0923`-`0925` | Parity covered: `call_ref`, direct-call, and `call_indirect` constructor/old-field forms preserve the call, intervening root, and later `struct.set`. |
| Direct unwrapped call roots across memory store/growth roots | `0926`, `0928`-`0935` | Parity covered: direct, indirect, and typed-function-reference calls are not moved across `i32.store`, `memory.grow`, or `table.grow`; old-field variants also keep the later `struct.set`. |
| Standalone indirect-call constructor/global boundary | `0891` | Parity covered: a `call_indirect` constructor field before unrelated `global.set` remains a no-swap boundary. |
| Block-wrapped constructor call roots | `0936`-`0941` | Parity covered: wrapping a direct/indirect/typed-function-reference call in a block does not make it safe to move across ordinary store or growth roots. |
| Block-wrapped old-field call roots | `0942`-`0945` | Parity covered: overwritten block-wrapped `call_ref` and `call_indirect` old fields remain preserved with the later same-field `struct.set`. |
| If-wrapped old-field call roots | `0946`-`0951` | Parity covered: overwritten if-wrapped direct/indirect/typed-function-reference calls remain no-fold boundaries across store and growth roots. |
| Branchless loop-wrapped old-field call roots | `0952`-`0957` | Parity covered: branchless loop wrappers preserve direct/indirect/typed-function-reference old-field calls and the later `struct.set`. |
| Branchless loop-wrapped constructor call roots | `0958`-`0963` | Parity covered: branchless loop-wrapped direct/indirect/typed-function-reference constructor calls remain no-swap boundaries across store and growth roots. |
| Branch-containing loop constructor call roots | `0964`-`0969` | Parity covered: outer-block/inner-loop wrappers with a branch keep call-valued constructor operands, branch/control debris, root effects, and later `struct.set`. |
| Branch-containing loop old-field call roots | `0970`-`0975` | Parity covered: overwritten direct/indirect/typed-function-reference old-field calls in the same branch-containing wrapper matrix remain preserved with the later same-field `struct.set`. |

## Narrow closure

The call-root barrier matrix above is narrow-closed for the listed roots and wrappers:

- direct, indirect, and typed-function-reference calls are all covered;
- constructor operands and overwritten old fields are both covered;
- ordinary store roots, table roots, memory roots, and growth roots are distinguished;
- wrappers are explicit instead of inferred from unwrapped roots; and
- every row maps to a focused Binaryen `version_130` probe and Starshine test where Starshine already matched.

HSO-D/G remain open for result-wrapper and catchable call surfaces outside `1086`/`1095`, exact descriptor `ref.cast`, arbitrary branch/catch/control call shapes not in this matrix, and future Binaryen source changes that allow moving specific call-like expressions across roots with stronger effect reasoning.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited source notes contain the focused test/probe evidence for each family.
