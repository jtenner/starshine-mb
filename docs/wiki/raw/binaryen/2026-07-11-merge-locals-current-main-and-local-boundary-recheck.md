---
kind: raw-source
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast
  - ../../../../src/passes/merge_locals.mbt
  - ../../../../src/passes/merge_locals_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../binaryen/passes/merge-locals/index.md
  - ../../binaryen/passes/merge-locals/implementation-structure-and-tests.md
  - ../../binaryen/passes/merge-locals/starshine-strategy.md
  - ../../binaryen/passes/merge-locals/fuzzing.md
---

# Binaryen `merge-locals` current-main and Starshine-boundary recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable source bridge for the living `merge-locals` dossier

## Scope

This capture rechecks the upstream owner, registration, and dedicated fixture on Binaryen `main`, then reconciles them with Starshine's active direct-pass implementation. It supersedes neither the older tagged-source manifests nor their historical research notes: those documents correctly describe pre-landing Starshine status for their dates. The living pages, however, must not repeat that old status as present tense.

## Official sources consulted

### Binaryen `main`

- [`MergeLocals.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp)
  - Reviewed the copy-shaped `local.set` / `local.get` candidate path, temporary `local.tee` instrumentation, eager `LocalGraph` construction, two-orientation solve, post-rewrite graph verification, rollback, and `invalidatesDWARF()` declaration.
- [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
  - Reviewed public `merge-locals` registration and default-function-pipeline admission at stronger optimize/shrink levels.
- [`merge-locals.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast)
  - Reviewed the dedicated `between-unreachable` regression. It is a conservative robustness boundary, not a complete positive-shape suite.

## Repository sources consulted

- [`src/passes/merge_locals.mbt`](../../../../src/passes/merge_locals.mbt)
  - Current direct module pass: it records forward source-to-destination aliases only for adjacent same-typed `local.get; local.set` copies, tracks target write epochs, and replaces later source gets while the destination epoch remains unchanged.
  - It recursively processes nested expression bodies but clears parent aliases at every `block`, `loop`, `if`, and `try_table` boundary. It has no `LocalGraph`, no destination-to-source orientation, and no post-rewrite rollback.
- [`src/passes/merge_locals_test.mbt`](../../../../src/passes/merge_locals_test.mbt)
  - Confirms public-pass admission, a same-typed forward-retargeting positive, destination-write invalidation, and a control boundary that prevents outer alias reuse.
- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt), and [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts)
  - Confirm active module-pass registry/dispatch and direct compare-harness admission.

## Durable observations

- Upstream Binaryen `merge-locals` remains a graph-checked, bidirectional copy-traffic balancing pass. Its temporary tee, `LocalGraph` influence proof, orientation choice, and rollback are one integrated contract.
- Starshine is no longer removed or boundary-only for this spelling. It has an active direct module pass and harness admission.
- Starshine's current subset is intentionally narrower than Binaryen: a per-expression linear epoch-alias scan, forward source-to-destination retargeting only, and deliberate alias clearing around structured control.
- Therefore, direct pass fuzz evidence supports the landed subset but does not establish full Binaryen `LocalGraph` parity or preset readiness.
- No upstream behavior-bearing drift was found on the reviewed owner, registration, or dedicated-fixture surfaces. The material wiki correction in this run is local-status reconciliation and an explicit definition of the remaining semantic boundary.

## Consumability rule

Cite this raw capture for the 2026-07-11 upstream/current-local reconciliation. Cite the living `merge-locals` dossier for explanations, examples, implementation planning, and validation commands.
