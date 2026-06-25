---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1001-2026-06-21-heap-store-optimization-result-try-table-return-call-old-field-boundary.md
  - ./1002-2026-06-21-heap-store-optimization-result-try-table-return-call-indirect-old-field-boundary.md
  - ./1003-2026-06-21-heap-store-optimization-result-try-table-return-call-ref-old-field-boundary.md
  - ./1004-2026-06-21-heap-store-optimization-result-try-table-call-ref-old-field-boundary.md
  - ./1006-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-old-field-boundary.md
  - ./1009-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-indirect-old-field-boundary.md
  - ./1010-2026-06-21-heap-store-optimization-result-try-table-descriptor-call-ref-old-field-boundary.md
  - ./1011-2026-06-21-heap-store-optimization-result-try-table-mutable-descriptor-call-boundary.md
  - ./1012-2026-06-21-heap-store-optimization-result-try-table-mutable-descriptor-call-ref-boundary.md
  - ./1013-2026-06-21-heap-store-optimization-result-try-table-mutable-descriptor-tail-call-boundary.md
  - ./1014-2026-06-21-heap-store-optimization-result-try-table-mutable-descriptor-return-call-ref-boundary.md
  - ./1019-2026-06-21-heap-store-optimization-later-field-result-try-table-old-field-fold.md
  - ./1020-2026-06-21-heap-store-optimization-later-field-result-try-table-tail-call-old-field-boundary.md
  - ./1021-2026-06-21-heap-store-optimization-later-field-result-try-table-descriptor-old-field-fold.md
  - ./1049-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-callrefs.md
  - ./1050-2026-06-25-heap-store-optimization-mutable-descriptor-direct-oldfield-call.md
  - ./1051-2026-06-25-heap-store-optimization-mutable-descriptor-tail-oldfield-call.md
  - ./1052-2026-06-25-heap-store-optimization-mutable-descriptor-return-call-ref-oldfield.md
  - ./1054-2026-06-25-heap-store-optimization-profile-direct-call-result-oldfield.md
  - ./1056-2026-06-25-heap-store-optimization-profile-call-indirect-result-oldfield.md
  - ./1057-2026-06-25-heap-store-optimization-profile-call-ref-result-oldfield.md
  - ./1058-2026-06-25-heap-store-optimization-profile-descriptor-call-result-oldfield.md
  - ./1059-2026-06-25-heap-store-optimization-profile-mutable-descriptor-call-result-oldfield.md
  - ./1060-2026-06-25-heap-store-optimization-profile-descriptor-call-indirect-result-oldfield.md
  - ./1061-2026-06-25-heap-store-optimization-profile-descriptor-call-ref-result-oldfield.md
  - ./1062-2026-06-25-heap-store-optimization-profile-return-call-oldfield.md
  - ./1063-2026-06-25-heap-store-optimization-profile-return-call-indirect-oldfield.md
  - ./1064-2026-06-25-heap-store-optimization-profile-return-call-ref-oldfield.md
  - ./1065-2026-06-25-heap-store-optimization-profile-descriptor-return-call-oldfield.md
  - ./1066-2026-06-25-heap-store-optimization-profile-descriptor-return-call-indirect-oldfield.md
  - ./1067-2026-06-25-heap-store-optimization-profile-descriptor-return-call-ref-oldfield.md
  - ./1068-2026-06-25-heap-store-optimization-profile-mutable-descriptor-return-call-oldfield.md
  - ./1069-2026-06-25-heap-store-optimization-profile-mutable-descriptor-return-call-indirect-oldfield.md
  - ./1070-2026-06-25-heap-store-optimization-profile-mutable-descriptor-return-call-ref-oldfield.md
  - ./1073-2026-06-25-heap-store-optimization-dedicated-profile-refresh.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../agent-todo.md
---

# HSO result-wrapper old-field micro-audit

## Question

Can any part of HSO-D's broad old-field/result-wrapper residual be narrowed using the focused and generated evidence already landed through `1073`?

## Answer

Yes. The callable result-wrapper old-field matrix is now narrow-closed for the covered constructor classes and call kinds listed below. This is a source-backed coverage closure, not a new behavior change.

## Covered result-wrapper old-field families

| Family | Evidence | Current classification |
|---|---|---|
| Plain constructor + direct `return_call` old field | `1001` | Binaryen preserves the old-field call, result wrapper, tail call, and later `struct.set`; Starshine matches. |
| Plain constructor + `return_call_indirect` old field | `1002` | Same conservative old-field/tail-wrapper preservation; Starshine matches. |
| Plain constructor + `return_call_ref` / non-tail `call_ref` old field | `1003`, `1004` | Typed-function-reference old-field result wrappers are preserved; Starshine matches. |
| Immutable descriptor + direct-call old field | `1006` | `1005`'s set-value fold stays scoped; old-field calls keep the wrapper, descriptor read, and later `struct.set`; Starshine matches. |
| Immutable descriptor + `call_indirect` / `call_ref` old field | `1009`, `1010` | Same old-field boundary for indirect and typed-function-reference calls; Starshine matches. |
| Mutable descriptor + non-tail direct/indirect/`call_ref` wrappers | `1011`, `1012`, focused siblings `1049`, `1050` | Mutable descriptor reads remain visible before catchable wrappers; later `struct.set` stays; Starshine matches. |
| Mutable descriptor + `return_call`, `return_call_indirect`, `return_call_ref` wrappers | `1013`, `1014`, focused siblings `1051`, `1052` | Mutable descriptor tail-call result wrappers remain no-fold; Starshine matches. |
| Later-field result-wrapper old-field fold/boundary split | `1019`, `1020`, `1021` | Non-tail pure folds preserve old-field calls/traps under `drop`; tail-call later fields remain boundaries; immutable descriptor counterpart matches. |
| Generated profile true call-result old fields | `1054`, `1056`-`1070`, refreshed lane `1073` | Dedicated profile now covers plain, immutable-descriptor, and mutable-descriptor direct/indirect/`call_ref` and tail-call result-wrapper old-field roots; the aggregate `1073` lane is green with the documented local-cleanup normalizer. |

## Narrow closure

For the families above, the old broad `1047` blocker is no longer current. The combination of focused source-backed tests and generated true call-result profile floors covers:

- plain `struct.new` result-wrapper old fields;
- immutable-descriptor `struct.new_desc` result-wrapper old fields;
- mutable-descriptor `struct.new_desc` result-wrapper old fields;
- direct calls, indirect calls, typed-function-reference calls, and their direct/indirect/typed tail-call result-wrapper siblings; and
- the later-field result-wrapper old-field split where pure non-tail folds are allowed but tail/catchable barriers are preserved.

This does **not** close HSO-D as a whole.

## Still open / reopening criteria

Keep HSO-D open for:

1. exact descriptor `ref.cast`, still blocked by Starshine decode/local surface per `1048`;
2. arbitrary descriptor expressions outside the enumerated `select` / `if` / block-branch / result-wrapper / call families;
3. old-field combinations outside the callable result-wrapper matrix, especially if a future Binaryen source change widens or changes `Effects::orderedBefore(...)` behavior; and
4. any generated-profile mismatch that escapes the dedicated profile's documented `local-cleanup-debris` normalization.

Reopen this micro-closed family if a future Binaryen oracle preserves or folds a listed result-wrapper old-field shape differently, if Starshine output stops validating, or if a compare lane finds a raw mismatch that is not the documented local-cleanup shape.

## Validation

Docs/status-only micro-audit. No new code changed and no tests were required for this note. The latest supporting validation remains the focused tests and direct smokes in `1049`-`1052`, the profile floor tests in `1054` and `1056`-`1070`, and the refreshed dedicated 10000-case profile lane in `1073`.
