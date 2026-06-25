---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0892-2026-06-21-heap-store-optimization-trapping-old-field-preservation.md
  - ./0893-2026-06-21-heap-store-optimization-trapping-trunc-old-field.md
  - ./0894-2026-06-21-heap-store-optimization-ref-as-non-null-old-field.md
  - ./0895-2026-06-21-heap-store-optimization-memory-load-old-field.md
  - ./0896-2026-06-21-heap-store-optimization-table-get-old-field.md
  - ./0897-2026-06-21-heap-store-optimization-memory-grow-old-field.md
  - ./0898-2026-06-21-heap-store-optimization-table-grow-old-field.md
  - ./0899-2026-06-21-heap-store-optimization-global-set-old-field.md
  - ./0900-2026-06-21-heap-store-optimization-memory-store-old-field.md
  - ./0901-2026-06-21-heap-store-optimization-table-store-old-field.md
  - ./0902-2026-06-21-heap-store-optimization-data-drop-old-field.md
  - ./0903-2026-06-21-heap-store-optimization-elem-drop-old-field.md
  - ./0904-2026-06-21-heap-store-optimization-memory-fill-old-field.md
  - ./0905-2026-06-21-heap-store-optimization-table-fill-old-field.md
  - ./0906-2026-06-21-heap-store-optimization-memory-copy-old-field.md
  - ./0907-2026-06-21-heap-store-optimization-table-copy-old-field.md
  - ./0908-2026-06-21-heap-store-optimization-memory-init-old-field.md
  - ./0909-2026-06-21-heap-store-optimization-table-init-old-field.md
  - ./0978-2026-06-21-heap-store-optimization-contained-branch-old-field-fold.md
  - ./1031-2026-06-24-heap-store-optimization-profile-descriptor-oldfield-memory-grow.md
  - ./1097-2026-06-25-heap-store-optimization-default-oldfield-audit.md
  - ./1098-2026-06-25-heap-store-optimization-call-root-barrier-audit.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../agent-todo.md
---

# HSO trapping and side-effectful old-field micro-audit

## Question

Can the old-field trap and side-effect preservation variants under HSO-D/G be narrowed using the focused Binaryen `version_130` probes from `0892`-`0909` and the contained-control follow-up from `0978`?

## Scope audited

This note covers overwritten constructor-field expressions whose evaluation must either be preserved under `drop` when a later store folds, or must keep the later `struct.set` because moving/folding would cross an ordering barrier:

1. exact trapping numeric and reference/memory/table old fields;
2. value-producing growth and global-write old fields that can be preserved under `drop` when resource ordering permits;
3. memory/table store, fill, copy, and init old-field boundaries;
4. passive data/element old-field folds;
5. pure branch-containing old fields that become droppable after `0978`; and
6. generated descriptor old-field `memory.grow` profile coverage.

This does **not** cover call-valued old fields audited in `1098`, default/descriptor call old-field combinations audited in `1097`, result-wrapper old-field families audited in `1086`, or arbitrary effectful expressions outside the listed exact operations.

## Source-backed behavior map

| Family | Evidence | Current classification |
| --- | --- | --- |
| Exact integer div/rem traps | `0892` | Parity covered after fix: overwritten `i32.div_s` / related exact div/rem old fields are trapping and cannot be silently dropped or moved across an intervening mutable global write. |
| Exact non-saturating trunc traps | `0893` | Parity covered after fix: overwritten `i32`/`i64.trunc_f32`/`trunc_f64` old fields keep trap ordering like Binaryen. |
| Reference/memory/table read traps | `0894`-`0896` | Parity covered: overwritten `ref.as_non_null`, `i32.load`, and `table.get` old fields preserve the later `struct.set` before an unrelated mutable `global.set`. |
| Growth old-field side effects | `0897`, `0898`, `1031` | Parity covered: overwritten `memory.grow` and `table.grow` values may be preserved under `drop` while the later store folds; descriptor `memory.grow` has generated profile coverage. |
| Global-write old-field side effects | `0899` | Parity covered after fix: unrelated global writes can fold with the old `$g0` write preserved under `drop`; same-global conflicts remain blocked by exact global-order analysis. |
| Value-producing ordinary store old fields | `0900`, `0901` | Parity covered boundaries: overwritten `i32.store` and `table.set` value-producing old fields keep the later `struct.set` in the probed unrelated-global shape. |
| Passive data/element old fields | `0902`, `0903` | Parity covered positives: overwritten value-producing `data.drop` and `elem.drop` side effects are preserved under `drop` while the later store folds. |
| Bulk fill/copy/init old fields | `0904`-`0909` | Parity covered boundaries: overwritten memory/table fill, copy, and init old fields keep the later `struct.set` before the intervening mutable global write. |
| Pure branch-containing old fields | `0978` | Parity covered after fix: trapless contained-control old fields can be dropped when overwritten, while unrelated store/growth roots are preserved and the later same-field store folds. |

## Narrow closure

The trapping and side-effectful old-field matrix above is narrow-closed for the exact operation families listed:

- traps are separated from ordinary side effects instead of treated as generic effect drift;
- fold-positive side effects (`memory.grow`, `table.grow`, unrelated `global.set`, `data.drop`, `elem.drop`) are distinguished from no-fold store/bulk boundaries;
- same-global conflicts remain distinct from unrelated-global positives; and
- pure contained-control old fields are covered only for the `0978` branch-wrapper shape, not arbitrary control effects.

HSO-D/G remain open for exact descriptor `ref.cast`, result-wrapper/catchable old-field interactions outside `1086`/`1095`, arbitrary effectful descriptor/later-field expressions, and any unlisted operation whose Binaryen `orderedBefore(...)` behavior changes or has not been directly probed.

## Validation

Docs/status-only micro-audit. No code changed and no tests were required for this note. The cited research notes contain the red-first fixes, focused tests, generated-profile smoke, and direct compare evidence for their individual behavior slices.
