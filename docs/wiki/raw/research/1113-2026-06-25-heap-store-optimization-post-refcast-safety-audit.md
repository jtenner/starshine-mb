---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./1086-2026-06-25-heap-store-optimization-result-wrapper-oldfield-audit.md
  - ./1089-2026-06-25-heap-store-optimization-target-local-hazard-audit.md
  - ./1091-2026-06-25-heap-store-optimization-non-goal-audit.md
  - ./1094-2026-06-25-heap-store-optimization-skip-local-control-audit.md
  - ./1095-2026-06-25-heap-store-optimization-try-table-swap-audit.md
  - ./1096-2026-06-25-heap-store-optimization-descriptor-later-field-barrier-audit.md
  - ./1097-2026-06-25-heap-store-optimization-default-oldfield-audit.md
  - ./1098-2026-06-25-heap-store-optimization-call-root-barrier-audit.md
  - ./1099-2026-06-25-heap-store-optimization-trap-oldfield-audit.md
  - ./1100-2026-06-25-heap-store-optimization-result-wrapper-later-field-audit.md
  - ./1101-2026-06-25-heap-store-optimization-nontry-wrapper-swap-audit.md
  - ./1103-2026-06-25-heap-store-optimization-catch-control-audit.md
  - ./1104-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-audit.md
  - ./1105-2026-06-25-heap-store-optimization-profile-source-map-audit.md
  - ./1106-2026-06-25-heap-store-optimization-moved-value-residual-audit.md
  - ./1107-2026-06-25-heap-store-optimization-tryswap-residual-audit.md
  - ./1108-2026-06-25-heap-store-optimization-closeout-residual-map.md
  - ./1109-2026-06-25-heap-store-optimization-exact-ref-cast-closure.md
  - ./1110-2026-06-25-heap-store-optimization-post-exact-refcast-compare.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO post-refcast safety family audit

## Question

After exact descriptor `ref.cast` became runnable in `1109`, do the HSO safety-family audits still hide a broad behavior blocker, or can the remaining work be limited to HSO-I performance and HSO-J final closeout?

## Answer

The exact descriptor `ref.cast` local-surface blocker called out in `1108` is closed by `1109`: Starshine now decodes, encodes, HOT-lifts, validates, and runs the exact Binaryen probe, preserving `ref.cast (ref (exact $desc))`, `struct.new_desc`, the helper call, and the later `struct.set` like Binaryen. The post-change direct 10000-case compare in `1110` was fully normalized-green with no failures.

With that blocker removed, the current source-backed safety matrix has focused positive/negative coverage or narrow documented wins/non-goals for every named HSO behavior family in the docs/wiki inventory. This is not final pass closeout: HSO-I performance and HSO-J final validation/compare/O4z/docs/backlog work remain open.

## Safety family map

| Family | Focused positives | Focused negatives / boundaries | Current disposition |
| --- | --- | --- | --- |
| HSO-C core chains | Tee-wrapped stores, later `local.get` chains, repeated stores where last value wins, many-fields/many-news independent chains (`0789`, `0848`-`0851`). | Wrong-local and pattern-breaker local-copy chains (`0789`, `0849`). | Closed before this note; no broad residual. |
| HSO-D constructor/default/descriptor/old-field effects | `struct.new_default` / `struct.new_default_desc` materialization, immutable descriptor operands, default double-call Starshine wins, old-field side-effect preservation (`1096`, `1097`, `1099`, `1104`, `1105`). | Descriptor/later-field call and trap barriers, mutable descriptor result-wrapper old fields, non-call old-field boundaries, exact descriptor `ref.cast` preserving `struct.set` (`1109`). | Safety covered for the current source-backed matrix. Reopen on new Binaryen source/lit behavior, arbitrary descriptor/later-field expression drift, or non-local-cleanup profile mismatches. |
| HSO-E target-local and moved-value hazards | Safe descriptor later-field target-local read, unrelated global read/write splits, pure condition folds, non-tail pure result-wrapper set-value folds (`1089`, `1096`, `1100`, `1106`). | Direct and descriptor target-local read/write hazards, same-global conflicts, effectful/trapping condition boundaries, mutable descriptor read with moved calls, exact descriptor `ref.cast` preserving `struct.set` (`1109`). | Safety covered for audited roots; future descriptor operators or unlisted moved-value hazards are reopening criteria. |
| HSO-F control skip-local-set / catch safety | External return/throw/tail-call positives, nested control traversal, one-disappearing-bad-get-style local-read disappearance, generated descriptor branch/catch roots (`1094`, `1103`, `1105`). | Locally caught call/throw negatives, active-catch throw, loop-backedge target-local reads, catchable `try_table` boundaries, result-wrapper tail-call no-folds. | Safety covered for current control/catch matrix; future exception-control surface drift is reopening criteria. |
| HSO-G `trySwap(...)` legality | Unrelated globals, cross-family memory/table roots, non-throwing `try_table` wrappers, block/if/loop/br_table wrapper positives, result-wrapper positives (`1095`, `1098`, `1101`, `1107`). | Final-root and constructor ping-pong boundaries, same-resource memory/table/bulk/passive barriers, call-root barriers, catchable call/throw wrappers, mutable descriptor boundaries. | Safety covered for audited wrappers/effects; future HOT wrapper forms and unlisted effectful ops are reopening criteria. |
| HSO-H non-goals / local surfaces | Ordinary memory/table roots are proven not to be non-goals; descriptor `br_on_non_null` generated roots now run; exact `ref.cast` now runs (`1041`, `1109`). | Array stores, generic non-fresh-reference struct DSE/load forwarding, direct unreachable constructor/set-value roots, bottom-typed tail cleanup boundaries (`1091`). | Non-goals are narrow and source-backed; exact `ref.cast` is no longer an HSO-H blocker. |

## Remaining blockers

- **HSO-I performance**: `1111` and `1112` keep the allocation-heavy 2000-function fixture well above the `<=2x Binaryen` target. This needs a safe structural improvement, explicit acceptance, or artifact/neighborhood supersession.
- **HSO-J final closeout**: final focused/full Moon validation, explicit native rebuild, final compare matrix/rerun decisions, O4z slot/neighborhood replay, docs/log updates, and backlog cleanup still need to run after the post-refcast changes.

## Validation

Docs/status-only audit. No code changed and no tests were required for this note. The cited research notes contain the focused positives/negatives, red/green fixes, profile smokes, direct compare lanes, and exact descriptor `ref.cast` closure evidence summarized here.
