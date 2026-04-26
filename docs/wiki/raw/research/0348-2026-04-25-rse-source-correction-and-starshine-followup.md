---
kind: research
status: superseded
last_reviewed: 2026-04-26
superseded_by:
  - ./0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
sources:
  - ./0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../binaryen/2026-04-25-rse-source-correction.md
  - ../binaryen/2026-04-22-rse-primary-sources.md
  - ./0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ./0114-2026-04-20-rse-binaryen-research.md
  - ../../binaryen/passes/rse/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
---

# RSE source correction and Starshine follow-up

## Supersession notice

This 2026-04-25 note is superseded for the claim that Binaryen `version_129` `rse` is a straight-line `PostWalker` with no CFG predecessor merge. The 2026-04-26 recheck in [`0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md`](./0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md) restores the source-backed CFG/value-flow reading: `rse` uses `CFGWalker`, block start/end local-value arrays, predecessor merge value numbers, same-value set/tee removal, and refined local-get retargeting. This note remains useful provenance for narrowing the pass away from `LocalGraph`, liveness, memory/global/heap-field stores, and arbitrary overwritten-write deletion.

## Question

The existing `rse` living dossier taught Binaryen `version_129` as a locals-only but fairly broad dataflow pass using `LocalGraph`, liveness, predecessor merges, copied-local inheritance, same-block `local.get` rewriting, and overwritten-write deletion.
A focused current-primary-source reread asked whether that was really the `version_129` contract future Starshine work should port.

## Answer

No.
The official `version_129` source shows a much smaller pass:

- `RedundantSetElimination.cpp` is a `PostWalker` over `LocalGet` and `LocalSet`.
- The pass-local state is one remembered value number per local.
- `visitLocalGet` only refines the value-numbered type for the current local when the remembered expression's type is a subtype of the declared local-get type.
- `visitLocalSet` removes a set or tee only when the RHS value number equals the remembered current value number for the same local.
- The pass clears remembered facts at conservative local/control/effect barriers; it does not compute predecessor merges or same-block read rewrites.
- The final `vacuum` slot is still part of the payoff because redundant plain sets become `drop(value)` when the RHS has a value.

A focused current-`main` spot check on 2026-04-25 found no teaching-relevant drift from that corrected `version_129` contract.

## What changed in the living wiki

- Refreshed `docs/wiki/binaryen/passes/rse/index.md` around the corrected pass purpose, invariants, inputs/outputs, edge cases, validation, and superseded older interpretation.
- Rewrote `binaryen-strategy.md` so Binaryen's actual approach is the small value-number vector plus conservative invalidation strategy.
- Added `implementation-structure-and-tests.md` so the owner files, registration files, helper headers, and test surfaces are directly findable.
- Reframed `cfg-and-value-tracking.md` from a predecessor-merge guide into a barrier-and-single-fact guide.
- Rewrote `wat-shapes.md` to keep only source-backed transforms and negative shapes: repeated same-value sets, repeated tees, GC/refinement gets, barrier clearing, and overwritten-write non-goals.
- Refreshed `starshine-strategy.md` to make the future port smaller and more precise: late HOT local value-number tracking, not a generic liveness write-elimination pass.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md` so the correction is discoverable.
- Updated `agent-todo.md` to remove stale RSE deliverables about overwritten writes, globals, GC field writes, liveness, and broad write elimination.

## Superseded claims

This note supersedes the algorithm interpretation in:

- `docs/wiki/raw/research/0114-2026-04-20-rse-binaryen-research.md`
- `docs/wiki/raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md`
- `docs/wiki/raw/binaryen/2026-04-22-rse-primary-sources.md`

Only the over-broad strategy claims are superseded.
Those notes remain useful historical provenance for why the folder exists and which sources were inspected.

## Local follow-up

When Starshine implements `rse`, the smallest source-faithful slice is:

1. add a real active pass entry instead of the current removed-name-only registry entry in `src/passes/optimize.mbt`;
2. add a dispatcher case in `src/passes/pass_manager.mbt`;
3. track per-local value identity across straight-line HOT expressions;
4. remove same-value `local.set` / `local.tee` shells while preserving RHS evaluation;
5. conservatively clear facts at control/effect/local-state boundaries;
6. verify the pass directly against Binaryen `--rse`, then in the late `rse -> vacuum` cluster.

Do not start by implementing global-set, heap-field, memory-store, LocalGraph, or liveness behavior unless a separate Starshine-local design deliberately expands beyond Binaryen parity.
