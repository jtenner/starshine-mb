---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./1072-2026-06-25-heap-store-optimization-allocation-heavy-performance-refresh.md
  - ./1073-2026-06-25-heap-store-optimization-dedicated-profile-refresh.md
  - ./1078-2026-06-25-heap-store-optimization-wasm-smith-rerun-after-cleanup.md
  - ./1080-2026-06-25-heap-store-optimization-random-all-profiles-lane.md
  - ./1081-2026-06-25-heap-store-optimization-o4z-slot-rerun.md
  - ./1082-2026-06-25-heap-store-optimization-regular-genvalid-100000.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
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
  - ./1102-2026-06-25-heap-store-optimization-exact-ref-cast-blocker-audit.md
  - ./1103-2026-06-25-heap-store-optimization-catch-control-audit.md
  - ./1104-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-audit.md
  - ./1105-2026-06-25-heap-store-optimization-profile-source-map-audit.md
  - ./1106-2026-06-25-heap-store-optimization-moved-value-residual-audit.md
  - ./1107-2026-06-25-heap-store-optimization-tryswap-residual-audit.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../agent-todo.md
---

# HSO closeout residual map

## Question

After micro-audits through `1107`, what still blocks declaring `heap-store-optimization` complete against Binaryen behavior parity?

## Answer

Within the current docs/wiki source matrix, the broad source-backed behavior families have been narrowed to audited submatrices. The pass is still **not complete** because three closeout blockers remain:

1. exact descriptor `ref.cast` is still a local decode/instruction-surface blocker, not an approved semantic non-goal;
2. HSO-I performance still misses the pass-local target on the allocation-heavy candidate fixture; and
3. HSO-J final closeout validation and publication work has not been rerun after the residual-map cleanup.

This note is a status map, not final signoff. It does not replace a fresh Binaryen source/lit reread if the oracle changes beyond `version_130`, and it does not approve any output-shape drift that has not been inspected and documented.

## Current source-family status

| Slice/family | Current status | Remaining reopen/close criteria |
| --- | --- | --- |
| HSO-A source/lit matrix | `0776` refreshed Binaryen `version_130` and found stable registration/lit behavior with directional movement details. | Reopen on newer explicit Binaryen oracle or source/lit drift. |
| HSO-C core chains | Closed by `0851` before this residual-map sequence. | Reopen on tee/subsequent-chain mismatch, repeated-store last-value regression, or new lit family. |
| HSO-D constructor/default/descriptor/old-field effects | Narrowed by `1086`, `1096`, `1097`, `1099`, `1100`, `1104`, `1105`, and `1106`. | Close only after exact descriptor `ref.cast` can run and preserve `struct.set`; reopen on new default/descriptor/old-field source behavior or non-local-cleanup profile mismatch. |
| HSO-E target-local and moved-value hazards | Narrowed by `1089`, `1096`, `1100`, `1104`, and `1106`. | Close only after exact descriptor `ref.cast` and any new moved-value source family are covered; arbitrary unprobed descriptor/later-field combinations remain reopening criteria rather than approved drift. |
| HSO-F skip-local-set control | Narrowed by `1094` and `1103`. | Close only after exact descriptor `ref.cast` and any unlisted/future control instruction surfaces are covered or explicitly approved; arbitrary descriptor/later-field plus catch/control combinations remain reopening criteria. |
| HSO-G `trySwap(...)` legality | Narrowed by `1095`, `1098`, `1099`, `1100`, `1101`, `1104`, and `1107`. | Close only after exact descriptor `ref.cast`, future HOT wrapper forms, unlisted effectful operations, and new Binaryen swap-legality drift are addressed or explicitly approved. |
| HSO-H explicit non-goals | Narrowed by `1091` and `1102`. | Exact descriptor `ref.cast` is not a non-goal; close only once Starshine can run the exact Binaryen probe and preserve `struct.set`, or a user explicitly approves a different narrow disposition. |
| HSO-I performance | Still open after `1072`, `1084`, `1085`, `1088`, and `1092`. | Needs a safe structural improvement, a measured artifact/neighborhood supersession, or explicit acceptance of the allocation-heavy slowdown. |
| HSO-J final evidence | Current lanes exist (`1073`, `1078`, `1080`, `1081`, `1082`, `1093`) but final closeout is not done. | Needs focused/full Moon validation, explicit native rebuild with `--target-dir target`, current direct/dedicated/random/wasm-smith/O4z evidence as required by the completion criteria, docs/log updates, and backlog cleanup. |

## Output-shape policy check

The only currently documented HSO output-shape differences that remain accepted are narrow and explicitly recorded:

- default/default-descriptor double-call folds (`0889`, `0890`) where Starshine folds more stores while preserving call order;
- direct-root `return_call_ref` dead-store cleanup (`0920`, `0921`) with reopening criteria;
- bottom-typed `return_call_indirect` old-field cleanup (`1053`) with reopening criteria; and
- dedicated-profile folded-store `nop` cleanup, scoped to `--normalize local-cleanup-debris` for the HSO profile only (`1023`, `1073`, `1105`).

No other output-shape drift should be treated as safe without fresh inspection, semantic reasoning, and documented benefit. In particular, the `local-cleanup-debris` normalizer remains forbidden for regular GenValid, wasm-smith, random all-profiles, and final direct lanes unless a future mismatch is separately inspected and justified.

## Next closeout path

1. Decide the exact descriptor `ref.cast` path: fix the decode/local surface enough to run Binaryen's exact probe through direct HSO, then require Starshine to preserve `struct.set` like Binaryen; or obtain explicit user approval for a narrow local-surface deferral with reopening criteria.
2. Resolve HSO-I: attempt a structural performance fix only if a safe target is clear, otherwise record measured release-context acceptance or artifact/neighborhood supersession.
3. Run final HSO-J validation and compare matrix using the explicit native binary path required by this workspace (`moon build --target-dir target --target native --release src/cmd`).
4. Update the dossier, fuzzing page if lane scope changes, wiki log, and `agent-todo.md`; only then close backlog slices.

## Validation

Docs/status-only residual map. No code changed and no tests were required for this note. The cited notes contain the focused tests, direct compare lanes, O4z slot replay, dedicated profile evidence, and performance measurements summarized here.
