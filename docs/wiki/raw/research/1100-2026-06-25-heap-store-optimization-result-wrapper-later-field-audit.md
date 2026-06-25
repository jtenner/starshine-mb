---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0996-2026-06-21-heap-store-optimization-result-try-table-return-call-ref-boundary.md
  - ./0997-2026-06-21-heap-store-optimization-result-try-table-call-cross-store-boundary.md
  - ./0998-2026-06-21-heap-store-optimization-result-try-table-call-indirect-cross-store-boundary.md
  - ./0999-2026-06-21-heap-store-optimization-result-try-table-return-call-boundary.md
  - ./1000-2026-06-21-heap-store-optimization-result-try-table-return-call-indirect-boundary.md
  - ./1005-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-fold.md
  - ./1007-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-indirect-fold.md
  - ./1008-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-ref-fold.md
  - ./1015-2026-06-21-heap-store-optimization-later-field-result-try-table-call-split.md
  - ./1016-2026-06-21-heap-store-optimization-later-field-result-try-table-call-ref-split.md
  - ./1017-2026-06-21-heap-store-optimization-later-field-result-try-table-call-indirect-split.md
  - ./1018-2026-06-21-heap-store-optimization-later-field-result-try-table-tail-call-boundary.md
  - ./1032-2026-06-24-heap-store-optimization-profile-descriptor-result-try-value.md
  - ./1033-2026-06-24-heap-store-optimization-profile-descriptor-later-result-field.md
  - ./1042-2026-06-25-heap-store-optimization-profile-catchable-call.md
  - ./1043-2026-06-25-heap-store-optimization-profile-catchable-call-ref.md
  - ./1044-2026-06-25-heap-store-optimization-profile-catchable-call-indirect.md
  - ./1086-2026-06-25-heap-store-optimization-result-wrapper-oldfield-audit.md
  - ./1095-2026-06-25-heap-store-optimization-try-table-swap-audit.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO result-wrapper later-field micro-audit

## Question

Can the HSO-D/E/G result-typed `try_table` later-field and set-value matrix be narrowed using the focused Binaryen `version_130` probes from `0996`-`1000`, `1005`, `1007`, `1008`, and `1015`-`1018`, plus the generated profile roots from `1032`, `1033`, and `1042`-`1044`?

## Scope audited

This note covers dropped result-typed `try_table` wrappers that appear as constructor fields or as intervening roots around a later same-object `struct.set`:

1. non-tail direct `call`, `call_indirect`, and `call_ref` result wrappers;
2. tail-call result wrappers (`return_call`, `return_call_indirect`, and `return_call_ref`);
3. descriptor `struct.new_desc` set-value positives with immutable descriptor reads;
4. later-field result-wrapper splits for pure versus call-valued moved set values; and
5. generated descriptor/catchable wrapper roots in the dedicated HSO profile.

This does **not** cover overwritten old-field result-wrapper preservation, which is separately narrow-audited in `1086`; the broader `try_table` swap/wrapper matrix, which is separately narrow-audited in `1095`; arbitrary catch/control call shapes; exact descriptor `ref.cast`; or future Binaryen changes that distinguish more precise `try_table` body effects.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Result-wrapper tail-call set-value boundaries | `0996`, `0999`, `1000` | Parity covered: Binaryen preserves the result wrapper, tail call, constructor, and later `struct.set` for `return_call_ref`, `return_call`, and `return_call_indirect`; Starshine matches instead of extrapolating the direct-root dead-tail-call Starshine wins from `0920`/`0921`. |
| Result-wrapper cross-store call boundaries | `0997`, `0998` | Parity covered: non-tail direct and indirect catchable calls inside result wrappers block folding across unrelated ordinary stores; the wrapper, call, store root, constructor resource read, and later `struct.set` remain. |
| Descriptor result-wrapper set-value positives | `1005`, `1007`, `1008`, `1032` | Parity covered after fixes/profile coverage: pure immutable-descriptor `struct.new_desc` constructors fold across dropped non-tail direct/indirect/typed-function-reference result wrappers while preserving the wrapper call and descriptor read. |
| Later-field non-tail call split | `1015`, `1016`, `1017`, `1033` | Parity covered: pure moved set values fold before later-field result wrappers containing direct, indirect, or typed-function-reference non-tail calls; call-valued moved set values remain after the later-field wrapper and keep the later `struct.set`. |
| Later-field tail-call boundary | `1018` | Parity covered after fix: result-wrapper tail-call later fields are no-fold barriers even when the moved set value is pure. |
| Generated catchable call roots | `1042`, `1043`, `1044` | Profile covered: the dedicated `heap-store-optimization` profile now exercises catchable direct-call, `call_ref`, and `call_indirect` result-wrapper roots with focused fuzz/profile/direct smoke evidence. |

## Narrow closure

The result-wrapper later-field/set-value matrix above is narrow-closed for the listed shapes:

- non-tail call wrappers use the Binaryen pure/effectful split instead of a broad no-fold rule;
- tail-call wrappers remain separate no-fold barriers, even for pure moved values;
- descriptor positives are limited to immutable descriptor reads and the explicit source/profile rows; and
- generated profile roots provide randomized regression coverage without replacing the source-family classification.

HSO-D/E/G remain open for exact descriptor `ref.cast`, arbitrary catch/control call shapes not represented by these result-wrapper rows, result-wrapper old-field variants outside `1086`, broader `trySwap(...)` operands outside `1095`, and any future oracle drift in `try_table` catchability or tail-call handling.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited research notes contain the focused red/green fixes, Binaryen probes, profile smokes, and direct compare evidence for each behavior family.
