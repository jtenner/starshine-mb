# 0321 - 2026-04-24 - `ssa` primary sources and Starshine follow-up

## Scope

Refresh the upstream-only `ssa` dossier so it matches the newer pass-wiki quality bar:

- add an immutable Binaryen primary-source manifest,
- add a dedicated Starshine status/port-strategy page,
- refresh the existing overview / Binaryen strategy / implementation map / shape pages with 2026-04-24 provenance,
- and keep the sibling split from implemented local `ssa-nomerge` explicit.

## Overlap scan

Before making new pages, re-read or inspected:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- existing `docs/wiki/binaryen/passes/ssa/` pages
- neighboring `docs/wiki/binaryen/passes/ssa-nomerge/` pages
- `src/passes/optimize.mbt`
- `src/passes/ssa_nomerge.mbt`
- `src/ir/ssa_policy.mbt`
- `src/ir/ssa_local.mbt`
- `src/ir/ssa_destroy.mbt`
- `src/passes/pass_common.mbt`

The existing `ssa` dossier already had the right page topology: overview, Binaryen strategy, implementation/test map, focused merge-local page, and WAT-shape catalog. The missing durable pieces were the raw primary-source capture and the dedicated Starshine local-status page.

## Primary sources captured

New raw manifest:

- `docs/wiki/raw/binaryen/2026-04-24-ssa-primary-sources.md`

Primary online sources recorded there:

- Binaryen GitHub release `version_129`
- `src/passes/SSAify.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/local-graph.h`
- `src/ir/LocalGraph.cpp`
- `src/ir/ReFinalize.cpp`
- `test/lit/passes/ssa.wast`
- `test/gtest/local-graph.cpp`
- sibling contrast file `test/passes/ssa-nomerge_enable-simd.wast`
- narrow current-`main` spot-check URLs for `SSAify.cpp`, `pass.cpp`, and `ssa.wast`

## Source-backed findings preserved

### Shared engine and policy split

`ssa` and `ssa-nomerge` are one upstream implementation file with one policy split:

- `SSAify(true)` for full `ssa`
- `SSAify(false)` for `ssa-nomerge`

That remains the central teaching point. Full `ssa` is not a separate algorithmic codebase; it is the merge-enabled sibling of the same LocalGraph-driven pass.

### Full `ssa` defining rewrite surface

The full sibling's important extra behavior is multi-source get handling:

1. allocate a merge local,
2. retarget the `local.get` to that merge local,
3. rewrite explicit incoming sets by wrapping their value in `local.tee mergeLocal`,
4. add function-entry prepends only for parameter-entry incoming values,
5. rely on the fresh merge local's default value for ordinary defaultable local-entry paths.

This is the beginner-to-advanced distinction from `ssa-nomerge` that future pages should not blur.

### Lit coverage versus source-derived behavior

The official `test/lit/passes/ssa.wast` file directly proves:

- repeated parameter overwrite splitting,
- reference-default replacement plus narrow refinalization,
- tuple default replacement.

It does not isolate the branch-merge tee / entry-prepend families in tiny goldens. Those examples remain strongly source-backed by `SSAify.cpp` and `LocalGraph`, but the living pages now continue to label them as source-derived rather than direct lit-file examples.

## Starshine status findings

Current local status is stronger than just “not implemented”:

- `src/passes/optimize.mbt` does not register `ssa` in active, removed, or boundary-only registry sets.
- Explicit `--ssa` requests therefore fall through to the unknown-pass path, unlike named removed or boundary-only passes.
- The local active sibling is `ssa-nomerge`.
- The active default `optimize` / `shrink` presets include `ssa-nomerge`, not full `ssa`.
- `agent-todo.md` has no dedicated full-`ssa` slice.

Starshine still has substantial local infrastructure that a future port would reuse:

- `src/ir/ssa_policy.mbt` defines local SSA value, phi, use, and exclusion vocabulary.
- `src/ir/ssa_local.mbt` builds a HOT SSA overlay with entry definitions and block phis using CFG, dominance, liveness, and use-def analysis.
- `src/ir/ssa_destroy.mbt` lowers that overlay back to HOT locals with concrete local assignment and predecessor copy insertion.
- `src/passes/ssa_nomerge.mbt` wraps the overlay/destruction path for the active local sibling.
- `src/passes/pass_common.mbt` exposes cached SSA analysis through `pass_require_ssa(...)`.

But this infrastructure is not a faithful Binaryen full-`ssa` port because it lowers overlay phis through predecessor copies and local assignment choices rather than implementing the upstream LocalGraph merge-local + incoming-`tee` + entry-prepend rewrite as a public `ssa` pass.

## Pages updated

- `docs/wiki/binaryen/passes/ssa/index.md`
- `docs/wiki/binaryen/passes/ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/ssa/merge-locals-entry-prepends-and-default-values.md`
- `docs/wiki/binaryen/passes/ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/ssa/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health-check finding

The focused health issue was stale local follow-along framing: the existing `ssa` pages repeatedly said the pass was “not currently in the local registry,” but did not give readers an exact code map showing what local SSA surfaces do exist and why they are not a full Binaryen `ssa` port. The new Starshine page closes that gap and the refreshed catalog/tracker entries now say the former provenance/local-status gap is closed.

## Durable conclusion

The `ssa` dossier is now complete enough for beginner through advanced readers:

- what the pass does,
- what shapes it transforms,
- how Binaryen implements it,
- what official sources prove directly versus source-derived behavior,
- how Starshine's active `ssa-nomerge` and HOT SSA infrastructure relate to it,
- and why current Starshine still does not expose full `ssa` as a pass.
