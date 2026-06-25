---
kind: research
status: active
created: 2026-06-25
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./1047-2026-06-25-heap-store-optimization-profile-call-result-old-field-blocker.md
  - ./1048-2026-06-25-heap-store-optimization-exact-ref-cast-recheck.md
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
  - ../../../src/fuzz/main_wbtest.mbt
---

# HSO-D/E residual hazard audit

## Question

After the source-backed HSO implementation and generated-profile work through `1070`, which constructor/default/descriptor/old-field and target-local/moved-value hazard claims are actually still open?

## Answer

The old generated call-result profile blocker from `1047` is no longer current as a broad blocker. It has been narrowed by true generated floors for:

- plain direct-call, `call_indirect`, and `call_ref` result old fields (`1054`, `1056`, `1057`);
- pure descriptor direct-call, `call_indirect`, and `call_ref` result old fields (`1058`, `1060`, `1061`);
- mutable-descriptor direct-call result old fields (`1059`);
- plain direct/indirect/typed-function-reference tail-call result-wrapper old fields (`1062`-`1064`);
- pure-descriptor direct/indirect/typed-function-reference tail-call result-wrapper old fields (`1065`-`1067`); and
- mutable-descriptor direct/indirect/typed-function-reference tail-call result-wrapper old fields (`1068`-`1070`).

The refreshed 10000-case dedicated profile lane in `1073` then exercised the aggregate profile with `10000/10000` cleanup-normalized matches and no mismatches or command failures.

That evidence is strong generated coverage, but it is not source-family closeout by itself. HSO-D and HSO-E should remain open for the source-backed residuals below.

## Residual HSO-D scope

Keep HSO-D open for:

1. **Exact descriptor `ref.cast` trap-order blocker.** `1048` rechecked the exact `(ref.cast (ref (exact $desc)) ...)` descriptor operand. Binaryen `version_130` accepts the input and preserves the later `struct.set`; Starshine still fails before HSO in binary decode with `DecodeAt(InvalidS33Range, 71, 34)`. This is a decode/local-surface blocker, not an accepted HSO semantic non-goal.
2. **Arbitrary descriptor operand expressions.** The audit now has many focused pure/effectful/trapping `select`, `if`, block-`br_if`, `br_on_non_null`, result-wrapper, call, indirect-call, `call_ref`, tail-call, and mutable-descriptor combinations, but no source review has proven that this list exhausts Binaryen's descriptor operand expression space.
3. **Broader default/descriptor old-field combinations.** The generated profile now covers the previously stale call-result and tail-call old-field floors, but HSO-D still needs a deliberate closeout pass before claiming every old-field side-effect/trap/store/bulk/passive/control combination is source-covered.

## Residual HSO-E scope

Keep HSO-E open for:

1. **Moved-value hazard combinations not yet explicitly mapped.** Current focused tests cover target-local read/write negatives, descriptor target-local hazards, later-field target-local positives, global read/write splits, mutable descriptor-global splits, descriptor/later-field `select`/`if`/block condition call and trap barriers, result-wrapper later-field splits, and default-descriptor catchable result-wrapper barriers.
2. **No broad drift approval.** The documented default double-fold Starshine wins (`0889`, `0890`) are narrow call-order-preserving wins, not permission to accept arbitrary extra folding across descriptor/later-field barriers.
3. **Exact-cast interaction.** Once Starshine can decode/represent the exact descriptor `ref.cast` negative, HSO-E should verify that moved calls or moved values still do not cross that descriptor-cast trap.

## Status update

This is a status/evidence cleanup only. No behavior changed and no new tests were needed. The next implementation slice should either add a focused red-first test for a newly identified source-backed gap, or run a closeout audit that maps the remaining descriptor/later-field expression space to existing tests and explicitly lists any narrow, evidence-backed residuals.
