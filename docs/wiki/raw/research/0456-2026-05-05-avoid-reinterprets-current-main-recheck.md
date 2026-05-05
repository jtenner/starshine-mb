---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md
  - ../binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../binaryen/passes/avoid-reinterprets/index.md
  - ../../binaryen/passes/avoid-reinterprets/binaryen-strategy.md
  - ../../binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md
  - ../../binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md
  - ../../binaryen/passes/avoid-reinterprets/wat-shapes.md
  - ../../binaryen/passes/avoid-reinterprets/starshine-strategy.md
  - ../../binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/avoid_reinterprets.mbt
  - ../../../../src/passes/avoid_reinterprets_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/cli/cli_test.mbt
---

# `avoid-reinterprets` current-main refresh

## Why this follow-up exists

The `avoid-reinterprets` dossier was already source-correct and teaching-complete, but its freshness layer still stopped at the 2026-04-26 port-readiness recheck.
This follow-up records the 2026-05-05 current-main bridge and updates the living pages so the direct-slice implementation, the exact local code anchors, and the remaining indirect-family gap are visible from the canonical overview and Starshine planning pages.

## Primary source rechecked

The refreshed source manifest rechecked official Binaryen current-main sources for:

- `src/passes/AvoidReinterprets.cpp`
- `src/passes/pass.cpp`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `test/lit/passes/avoid-reinterprets.wast`
- `test/lit/passes/avoid-reinterprets64.wast`

The review did not surface teaching-relevant drift from the existing contract.
The same narrow load/reinterpret rewrite model still stands:

- direct `reinterpret(load)` flips for full-width loads
- indirect `reinterpret(local.get <- load)` helper-local rewrites only when one source load is provable

## Durable update

The living dossier pages now point at the 2026-05-05 bridge so future maintainers can see that the pass was rechecked after the earlier 2026-04-26 port-readiness wave.
The local Starshine status is also now easier to follow because the strategy page cites the exact landed implementation file and test file instead of only the registry and dispatcher surfaces.

## Supersession note

This note extends the earlier 2026-04-26 `avoid-reinterprets` source notes.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
The earlier port-readiness bridge is still useful history, but it now reads as the pre-implementation proof sketch rather than the final local status.
