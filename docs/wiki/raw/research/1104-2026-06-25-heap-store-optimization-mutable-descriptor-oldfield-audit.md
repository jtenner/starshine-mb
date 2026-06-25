---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1011-2026-06-23-heap-store-optimization-mutable-descriptor-result-wrapper.md
  - ./1012-2026-06-23-heap-store-optimization-mutable-descriptor-call-ref.md
  - ./1013-2026-06-23-heap-store-optimization-mutable-descriptor-tail-calls.md
  - ./1014-2026-06-23-heap-store-optimization-mutable-descriptor-return-call-ref.md
  - ./1045-2026-06-25-heap-store-optimization-profile-mutable-descriptor-old-field.md
  - ./1049-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-callrefs.md
  - ./1050-2026-06-25-heap-store-optimization-mutable-descriptor-direct-oldfield-call.md
  - ./1051-2026-06-25-heap-store-optimization-mutable-descriptor-tail-oldfield-call.md
  - ./1052-2026-06-25-heap-store-optimization-mutable-descriptor-return-call-ref-oldfield.md
  - ./1055-2026-06-25-heap-store-optimization-mutable-default-descriptor-oldfield.md
  - ./1086-2026-06-25-heap-store-optimization-result-wrapper-oldfield-audit.md
  - ./1100-2026-06-25-heap-store-optimization-result-wrapper-later-field-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO mutable descriptor result-wrapper old-field micro-audit

## Question

Can the HSO-D/E/G residual wording around mutable descriptor result-wrapper old-field variants be narrowed using the focused source-backed tests from `1049`-`1052`, the generated profile root from `1045`, and the mutable default-descriptor boundary from `1055`?

## Scope audited

This note covers result-typed wrapper boundaries where a fresh object is built with a mutable descriptor operand and a later same-field store might otherwise be folded through a wrapper or descriptor read:

1. non-tail direct, indirect, and typed-function-reference result wrappers after a mutable descriptor `global.get`;
2. tail-call result wrappers (`return_call`, `return_call_indirect`, and `return_call_ref`) after a mutable descriptor `global.get`;
3. overwritten old fields produced by direct `call`, `call_indirect`, or `call_ref`;
4. the generated mutable-descriptor old-field root with an overwritten `memory.grow`; and
5. the `struct.new_default_desc` mutable descriptor catchable result-wrapper old-field boundary.

This does **not** claim arbitrary mutable descriptor expressions are exhaustive. It does not cover exact descriptor `ref.cast`, non-result-wrapper descriptor expressions outside the audited local/global/select/if/block-br_if matrices, or future mutable descriptor forms not represented by `global.get`.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Mutable descriptor result-wrapper boundaries | `1011`, `1012` | Parity covered: Binaryen preserves `struct.new_desc`, mutable descriptor `global.get`, non-tail direct/indirect/`call_ref` result wrappers, and later `struct.set`; Starshine matches, so immutable-descriptor folds from `1005`/`1007`/`1008` remain scoped away from mutable descriptor reads. |
| Mutable descriptor tail-call wrappers | `1013`, `1014` | Parity covered: direct, indirect, and typed-function-reference tail-call result wrappers preserve the mutable descriptor read and later `struct.set`; Starshine matches, keeping direct-root tail-call Starshine wins out of locally catchable result wrappers. |
| Mutable descriptor old-field calls | `1049`, `1050`, `1051`, `1052` | Focused coverage complete for the listed call spellings: overwritten old fields produced by direct `call`, `call_indirect`, or `call_ref` are preserved with the wrapper and later `struct.set`, including direct/indirect/typed-function-reference tail-call wrappers. |
| Generated mutable descriptor old field | `1045` | Profile covered: a mutable descriptor `global.get`, overwritten `memory.grow` old field, catchable direct-call result wrapper, and later `struct.set` are represented in the dedicated HSO profile and compare-smoked green. |
| Mutable default descriptor catchable wrapper | `1055` | Parity covered: Binaryen and Starshine preserve `struct.new_default_desc`, mutable descriptor `global.get`, call-bearing stores, catchable result wrapper, and the later pure `struct.set`; the immutable `1022` boundary has a mutable descriptor sibling. |
| Callable result-wrapper old-field aggregate | `1086` | Cross-reference: `1086` already ties callable old-field source notes and generated true call-result floors to the refreshed `1073` dedicated-profile lane. This note narrows the mutable descriptor subset that `1086` left visible in backlog text. |

## Narrow closure

The mutable descriptor result-wrapper old-field subset above is narrow-closed for the listed `global.get` descriptor shapes:

- mutable descriptor reads are preserved before locally catchable result wrappers;
- old-field calls and `memory.grow` side effects are preserved instead of dropped or reordered;
- tail-call wrappers remain no-fold in this locally catchable wrapper context; and
- `struct.new_default_desc` has a source-backed mutable descriptor boundary rather than being inferred from immutable/default coverage.

HSO-D/E/G remain open for exact descriptor `ref.cast`, arbitrary descriptor expressions outside the enumerated local/global/select/if/block-br_if/result-wrapper/default matrices, unlisted old-field operations without direct Binaryen probes, arbitrary catch/control combinations not covered by `1103`, and future Binaryen changes to mutable descriptor ordering.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited notes contain focused Binaryen `version_130` probes, Starshine focused tests, generated profile smokes, and direct compare evidence for the covered families.
