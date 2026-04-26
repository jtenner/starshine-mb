---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../binaryen/2026-04-25-rse-source-correction.md
  - ../binaryen/2026-04-22-rse-primary-sources.md
  - ./0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../binaryen/passes/rse/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/ir/use_def.mbt
  - ../../../../src/ir/hot_module_context.mbt
  - ../../../../agent-todo.md
---

# RSE CFG source correction and port-readiness bridge

## Question

The 2026-04-25 `rse` correction made the dossier source-correct on the pass's narrow semantic scope, but it overcorrected the implementation structure by teaching `version_129` as a straight-line `PostWalker` with no CFG predecessor merge.
A new primary-source reread asked whether Binaryen really computes block start/end values and whether Starshine's future first slice should account for that.

## Answer

Yes: official Binaryen `version_129` `RedundantSetElimination.cpp` builds a `CFGWalker` graph, flows per-local value numbers through basic blocks, merges predecessor values with block-specific merge numbers, and then performs the set/get optimization inside each block from the computed block-start state.

The corrected contract is:

- locals-only and same-value-write-only for deletion;
- CFG-aware for the local value facts used to identify same-value writes and refined local-get choices;
- not LocalGraph/liveness and not arbitrary dead overwritten-set elimination;
- type-sensitive when `local.get` is retargeted to a refined local or a `local.tee` is removed under a more specific replacement value.

The current `main` source still has the same teaching-relevant structure on 2026-04-26.

## What changed in the living wiki

- Refreshed `docs/wiki/binaryen/passes/rse/index.md` so the overview describes the CFG/value-flow contract instead of the stale straight-line-only model.
- Rewrote `binaryen-strategy.md` around the actual three-phase Binaryen algorithm: collect CFG items, flow values, optimize sets/gets.
- Rewrote `implementation-structure-and-tests.md` so `CFGWalker`, `UniqueDeferredQueue`, `ValueNumbering`, `Properties::getFallthrough`, refined-local retargeting, and conditional `ReFinalize` are visible in the owner-file map.
- Reframed `cfg-and-value-tracking.md` back into a true CFG/value-flow guide while preserving the important non-goals around `LocalGraph`, liveness, and broad dead-store elimination.
- Refreshed `wat-shapes.md` to add branch/merge positives and refined-local retargeting shapes while keeping overwritten-different-value negatives explicit.
- Refreshed `starshine-strategy.md` and added `starshine-port-readiness-and-validation.md` so future implementers can see the exact Starshine registry/dispatcher/backlog state, missing CFG/value-numbering substrate, safe first-slice order, and Binaryen oracle ladder.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, `CHANGELOG.md`, and the `RSE` section of `agent-todo.md` so stale 2026-04-25 wording does not keep pointing implementers at a straight-line-only plan.

## Superseded claims

This note supersedes the 2026-04-25 claim that `rse` has no CFG predecessor merge or block start/end value flow.
It does **not** restore the older overbroad claim that `rse` uses `LocalGraph`, liveness, same-block read rewriting in a separate liveness sense, copied-local provenance outside value numbers, or arbitrary overwritten-write deletion.

The practical phrasing is:

> Binaryen `rse` is CFG-aware same-value local-set elimination plus refined local-get retargeting; it is not a broad dead-store eliminator.

## Starshine follow-up

The future Starshine implementation should now be sliced as:

1. registry honesty and dispatcher wiring for `redundant-set-elimination`, with an explicit `rse` alias decision;
2. a HOT/basic-block value-flow substrate that can compute block start/end local value identities and converge through loops/diamonds;
3. same-value `local.set` / `local.tee` shell removal with RHS evaluation preserved;
4. reference-local equivalence tracking and refined `local.get` retargeting, including refinalization/writeback validation;
5. direct Binaryen `--rse` comparison, then `--rse --vacuum`, then no-DWARF late-tail replay around historical slot `46`.

The open local design question is not whether Binaryen has CFG flow; it does.
The open question is whether Starshine builds a small pass-local CFG/value numbering helper for `rse` or reuses broader HOT block/use-def infrastructure without accidentally turning the first slice into liveness-based dead-store elimination.
