---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0778-2026-06-20-heap-store-optimization-shallow-effects-fold.md
  - ./0856-2026-06-20-heap-store-optimization-descriptor-old-field-combinations.md
  - ./0885-2026-06-21-heap-store-optimization-descriptor-old-field-effects.md
  - ./0886-2026-06-21-heap-store-optimization-descriptor-old-field-call-barrier.md
  - ./0887-2026-06-21-heap-store-optimization-plain-old-field-call-barrier.md
  - ./0889-2026-06-21-heap-store-optimization-default-desc-starshine-win.md
  - ./0890-2026-06-21-heap-store-optimization-default-starshine-win.md
  - ./1021-2026-06-21-heap-store-optimization-later-field-result-try-table-descriptor-old-field-fold.md
  - ./1022-2026-06-21-heap-store-optimization-default-desc-catchable-later-field-result-try-table-store-boundary.md
  - ./1024-2026-06-24-heap-store-optimization-default-profile-and-void-try-table.md
  - ./1027-2026-06-24-heap-store-optimization-profile-descriptor-constructors.md
  - ./1031-2026-06-24-heap-store-optimization-profile-descriptor-oldfield-memory-grow.md
  - ./1055-2026-06-25-heap-store-optimization-mutable-default-descriptor-oldfield.md
  - ./1086-2026-06-25-heap-store-optimization-result-wrapper-oldfield-audit.md
  - ./1096-2026-06-25-heap-store-optimization-descriptor-later-field-barrier-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../agent-todo.md
---

# HSO default/descriptor old-field micro-audit

## Question

Can the default-constructor, descriptor-constructor, and old-field preservation portion of HSO-D be narrowed using existing Binaryen `version_130` probes and generated-profile roots, without claiming arbitrary descriptor or result-wrapper parity?

## Scope audited

This note covers the source-backed matrix where HSO folds later `struct.set` values back into fresh constructors while preserving any overwritten old-field side effects:

1. plain `struct.new` and `struct.new_default` shallow-effect handling;
2. `struct.new_default_desc` materialization to explicit `struct.new_desc` operands;
3. descriptor old-field call preservation under `drop`;
4. plain/descriptor later-field call barriers interacting with old-field preservation;
5. the two narrow default double-call Starshine wins from `0889` and `0890`;
6. default/descriptor generated-profile coverage for constructor/default and one descriptor old-field `memory.grow` root; and
7. the default-descriptor catchable result-wrapper boundary plus mutable-descriptor sibling, only as a named boundary already tested by `1022` and `1055`.

This does **not** close exact descriptor `ref.cast`, arbitrary descriptor expressions, broader callable result-wrapper old-field behavior beyond `1086`, or non-default old-field effect variants outside the listed call/default/profile roots.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Plain constructor shallow old-field effects | `0778` | Parity covered: folding a later call-valued store into plain `struct.new` is allowed when only the overwritten old field has call effects; the old call is preserved under `drop`. |
| Default descriptor materialization and later-field call split | `0856` | Parity covered: safe `struct.new_default_desc` chains materialize into `struct.new_desc`, while a later constructor-field call blocks moving another call-valued store before it. |
| Descriptor old-field call preservation | `0885` | Parity covered: overwritten descriptor-constructor calls are preserved under `drop` when the later same-field store folds into `struct.new_desc`. |
| Old-field preservation plus later-field call barrier | `0886`, `0887`, `1096` | Parity covered: preserving an overwritten call does not allow a moved later call to cross another later constructor-field call, for descriptor or plain constructors. |
| Default double-call materialization | `0889`, `0890` | Narrow Starshine wins: Binaryen folds only the first call-valued store for both descriptor and plain default constructors; Starshine folds both while preserving call order and, for descriptors, only crossing an immutable descriptor `global.get`. |
| Immutable descriptor later-field result wrapper old-field fold | `1021`, `1086` | Covered by the callable result-wrapper audit: pure same-field stores fold while old call/trap effects are preserved under `drop`. This note references it only to prevent reopening the default/descriptor old-field matrix for that already-audited sibling. |
| Default-descriptor catchable result-wrapper store boundary | `1022`, `1055` | Parity covered boundary: catchable result-wrapper store values keep the default descriptor constructor and later stores; the mutable descriptor-global sibling is also explicit. |
| Generated default/descriptor floors | `1024`, `1027`, `1031` | Profile covered: the dedicated HSO profile now emits ordinary default materialization, descriptor constructor/default opportunities, and a descriptor old-field `memory.grow` preservation root. |

## Narrow closure

The listed default/descriptor old-field matrix is narrow-closed:

- default materialization has both focused tests and generated-profile floors;
- descriptor old-field call preservation is source-backed and remains distinct from generic old-field side effects;
- old-field preservation does not weaken later-field call barriers;
- the plain/default double-call output drift is explicitly classified as a narrow Starshine win with reopening criteria in `0889` and `0890`, not as broad Binaryen-vs-Starshine drift; and
- the default-descriptor catchable result-wrapper boundary is kept conservative and explicit for immutable and mutable descriptor globals.

HSO-D remains open for exact descriptor `ref.cast`, arbitrary descriptor/later-field expressions beyond the enumerated `1096` barrier audit, broad non-call old-field side-effect combinations outside the direct notes, and future Binaryen changes that continue default chains differently or add new descriptor safety constraints.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited notes contain the focused tests, Binaryen `version_130` probes, generated-profile smokes, and direct compare evidence for their individual behavior slices.
