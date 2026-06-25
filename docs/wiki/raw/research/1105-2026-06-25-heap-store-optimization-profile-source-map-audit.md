---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ./1023-2026-06-24-heap-store-optimization-genvalid-profile.md
  - ./1024-2026-06-24-heap-store-optimization-default-profile-and-void-try-table.md
  - ./1025-2026-06-24-heap-store-optimization-try-table-profile-coverage.md
  - ./1026-2026-06-24-heap-store-optimization-profile-control-store-barriers.md
  - ./1027-2026-06-24-heap-store-optimization-profile-descriptor-constructors.md
  - ./1028-2026-06-24-heap-store-optimization-profile-catch-throw-skip-local-set.md
  - ./1029-2026-06-24-heap-store-optimization-profile-descriptor-catch-throw.md
  - ./1030-2026-06-24-heap-store-optimization-profile-descriptor-branch-skip.md
  - ./1031-2026-06-24-heap-store-optimization-profile-descriptor-oldfield-memory-grow.md
  - ./1032-2026-06-24-heap-store-optimization-profile-descriptor-result-try-value.md
  - ./1033-2026-06-24-heap-store-optimization-profile-descriptor-later-result-field.md
  - ./1034-2026-06-24-heap-store-optimization-profile-result-memory-fill.md
  - ./1035-2026-06-25-heap-store-optimization-profile-result-table-set.md
  - ./1036-2026-06-25-heap-store-optimization-profile-catchable-result-memory-fill.md
  - ./1037-2026-06-25-heap-store-optimization-profile-result-i32-store.md
  - ./1038-2026-06-25-heap-store-optimization-profile-result-growth.md
  - ./1039-2026-06-25-heap-store-optimization-profile-result-table-fill.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1042-2026-06-25-heap-store-optimization-profile-catchable-call.md
  - ./1043-2026-06-25-heap-store-optimization-profile-catchable-call-ref.md
  - ./1044-2026-06-25-heap-store-optimization-profile-catchable-call-indirect.md
  - ./1045-2026-06-25-heap-store-optimization-profile-mutable-descriptor-old-field.md
  - ./1046-2026-06-25-heap-store-optimization-profile-call-old-field.md
  - ./1047-2026-06-25-heap-store-optimization-profile-call-result-old-field-blocker.md
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
  - ./1074-2026-06-25-heap-store-optimization-de-hazard-audit.md
  - ./1080-2026-06-25-heap-store-optimization-random-all-profiles-lane.md
  - ./1082-2026-06-25-heap-store-optimization-regular-genvalid-100000.md
  - ./1103-2026-06-25-heap-store-optimization-catch-control-audit.md
  - ./1104-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-audit.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../../agent-todo.md
---

# HSO dedicated-profile source-map audit

## Question

After profile additions through `1070` and the green 10000-case dedicated-profile refresh in `1073`, can the generated `heap-store-optimization` profile be described as current, source-mapped regression coverage rather than an open broad blocker?

## Answer

Yes, with two important limits:

1. the dedicated profile is now current generated regression coverage for the listed HSO families; and
2. it is **not** a substitute for source-family closeout. Exact descriptor `ref.cast`, arbitrary descriptor/control expressions, unlisted effect roots, and performance remain open elsewhere.

The `local-cleanup-debris` normalizer remains scoped to the dedicated HSO profile only. It covers Binaryen-retained folded-store `nop` placeholders versus Starshine's nop-free validated output from `1023`/`1073`; it must not be silently applied to regular GenValid, wasm-smith, random all-profiles, or final direct lanes.

## Generated family map

| Profile area | Evidence | Current classification |
| --- | --- | --- |
| Core constructor/store folds | `1023`, `1024`, `1027` | Generated coverage current for local-set/tee constructor folds, repeated stores, `struct.new_default`, `struct.new_default_desc`, and `struct.new_desc` fold opportunities. |
| Try-table store/effect wrappers | `1024`-`1026`, `1034`-`1039` | Generated coverage current for void/result `try_table` roots, cross-family positives, same-resource barriers, catchable same-resource barriers, table-side counterparts, and cross-growth roots. |
| Skip-local-set control | `1028`-`1030`, `1041`, `1103` | Generated coverage current for ordinary and descriptor catch/throw hazards, descriptor branch skip-local-set roots, and exact descriptor `br_on_non_null` branch-result roots. |
| Descriptor and old-field side effects | `1031`-`1033`, `1045`, `1104` | Generated coverage current for descriptor `memory.grow` old fields, descriptor result-wrapper set values, descriptor later-field result wrappers, and mutable descriptor result-wrapper old-field roots. |
| Catchable call wrappers | `1042`-`1044`, `1100` | Generated coverage current for catchable result-typed direct-call, `call_indirect`, and `call_ref` wrappers. |
| True call-result old fields | `1047`, `1054`, `1056`-`1061`, `1074` | The old `1047` no-result-call blocker is retired for this generated submatrix: direct-call, `call_indirect`, `call_ref`, pure-descriptor, and mutable-descriptor true call-result old fields all have generated floors. |
| Tail-call result-wrapper old fields | `1062`-`1070`, `1086`, `1104` | Generated coverage current for direct, indirect, and typed-function-reference tail-call result-wrapper old fields across plain, pure-descriptor, and mutable-descriptor constructors. |
| Profile-scale evidence | `1073` | Current lane: `10000/10000` dedicated-profile cases compared with `10000` cleanup-normalized matches and `0` raw mismatches/failures under `--normalize local-cleanup-debris`. |
| Other closeout lanes | `1080`, `1082` | Regular GenValid and random all-profiles lanes stay separate and use no HSO profile normalizer; their green status is supporting evidence, not generated-profile coverage. |

## Narrow closure

The generated profile is narrow-closed as **current regression coverage** for the listed profile roots. This means future HSO source-family audits can cite the profile as reinforcement for these shapes instead of treating `1047` or the older missing generated roots as current blockers.

This does not close HSO-J or convert generated evidence into broad semantic approval. Reopen or extend the profile when:

- a new source-backed Binaryen family is implemented and should be fuzzed regularly;
- a profile root stops triggering HSO or stops validating;
- `local-cleanup-debris` hides anything other than Binaryen-retained `nop` placeholders from folded HSO stores;
- regular GenValid, wasm-smith, or random all-profiles lanes need an HSO-dedicated normalizer; or
- exact descriptor `ref.cast` becomes runnable and needs generated coverage after focused source coverage lands.

## Validation

Docs/status-only audit. No code changed and no tests were required for this note. The cited profile notes contain red-first generator/fuzz tests, focused smokes, direct compare smokes, and the `1073` 10000-case dedicated-profile refresh.
