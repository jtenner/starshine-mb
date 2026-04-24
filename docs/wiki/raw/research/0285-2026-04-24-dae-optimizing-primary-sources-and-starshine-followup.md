# `dae-optimizing` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages  
_Related living pages:_

- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md`
- `docs/wiki/binaryen/passes/dae-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md`
- `docs/wiki/raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`

## Question

The `dae-optimizing` folder already had beginner-to-advanced upstream coverage, but it still lacked two pieces required by the pass-wiki health loop:

1. an immutable primary-source manifest for the reviewed Binaryen sources; and
2. a dedicated Starshine strategy / status bridge with exact in-repo code locations.

The follow-up also needed a local naming audit because older living wording implied that Starshine registered the exact upstream spelling `dae-optimizing`.

## Sources read for this follow-up

Primary online sources are captured in:

- `docs/wiki/raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`

Local Starshine status sources:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

Neighboring living sources:

- `docs/wiki/binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/index.md`
- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/code-folding/index.md`

## Findings

### Binaryen contract remained stable for the reviewed teaching surface

The 2026-04-24 source spot check did not find a teaching-relevant drift between the existing dossier claims and the official Binaryen `version_129` plus current-`main` sources reviewed for this pass.

The important upstream split remains:

- `DeadArgumentElimination.cpp` owns the shared direct-call boundary rewrite engine;
- `pass.cpp` exposes the public pass-name split between plain `dae` and `dae-optimizing`;
- `opt-utils.h` owns the optimizing-only nested cleanup helper.

### Starshine does not currently implement either spelling as a real pass

`src/passes/optimize.mbt` currently keeps a boundary-only local entry named:

- `dead-argument-elimination-optimizing`

The exact upstream spelling:

- `dae-optimizing`

still appears in canonical Binaryen/path/audit/backlog documentation, but it is not currently one of the names in `pass_registry_boundary_only_names()`.
Because `run_hot_pipeline_expand_passes(...)` performs exact lookup before category rejection, the two names have different current user-facing behavior:

- `dead-argument-elimination-optimizing` is known but rejected as boundary-only;
- `dae-optimizing` is a Binaryen/audit/backlog spelling and should not be described as the current Starshine registry entry unless an alias is added.

This is a local documentation correction, not an upstream contradiction.

### The future port remains boundary-plus-scheduler work

The current active Starshine preset lists only implemented hot/module passes and does not schedule the late post-pass boundary cluster.
`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` still names `dae-optimizing` as the first late post-pass Binaryen slot, and `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json` records saved generated-artifact skipped slot `48` as `dae-optimizing`.

`agent-todo.md` keeps active DAE slices:

- `[DAE]001` for call-graph pruning, safe parameter removal, call localization, and touched-function tracking;
- `[DAE]002` for reproducing the nested `optimizeAfterInlining` cleanup replay and artifact comparison.

That means a future Starshine port must not be framed as a HOT peephole. It needs:

- a module-owned direct-call boundary analysis;
- function signature and callsite rewrite support;
- call-operand localization;
- return-rewrite and uninhabitable-result repair;
- a nested function-pipeline replay hook for touched functions.

## Wiki updates made from this research

- Added `docs/wiki/raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`.
- Refreshed the `dae-optimizing` landing, Binaryen strategy, focused signature/rerun page, and WAT-shape page so they cite the raw manifest and keep the upstream-vs-local naming split explicit.
- Updated the pass folder catalog, global wiki index, tracker, and log.

## Uncertainties and follow-up questions

- It is not yet decided whether Starshine should add an exact `dae-optimizing` alias beside `dead-argument-elimination-optimizing`, rename the current descriptive entry, or keep the current split and teach the mapping. The current wiki now records the split instead of smoothing it over.
- No local owner file exists yet for the actual transform. The future implementation location is likely a module-boundary pass area plus scheduler support, but this run intentionally did not invent a code layout.
