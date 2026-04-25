# 0331 - `simplify-locals-nonesting` primary sources and Starshine follow-up

## Scope

Refresh the existing `simplify-locals-nonesting` dossier so it matches the current wiki quality bar:

- add an immutable Binaryen primary-source manifest
- add the missing dedicated Starshine status / port-strategy page
- make the older 0186 research note explicitly superseded for provenance and local status
- keep the already-good overview, Binaryen strategy, transformed-shape catalog, and flatness-boundary pages non-duplicative

## Why this pass was chosen

The folder already had useful 2026-04-21 teaching coverage, but it was still weaker than neighboring locals-family dossiers:

- no committed raw primary-source manifest existed under `docs/wiki/raw/binaryen/`
- no dedicated Starshine status page existed, so the local implementation truth was only scattered across `src/passes/optimize.mbt`, `src/cmd/cmd.mbt`, `src/passes/pass_manager.mbt`, the active full `simplify-locals` owner file, and `agent-todo.md`
- `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` still described the folder as a working dossier rather than a source-captured bridge

## Primary upstream sources reviewed

Captured in `docs/wiki/raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`:

- Binaryen GitHub release `version_129`
- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/linear-execution.h`
- `src/ir/effects.h`
- `src/ir/equivalent_sets.h`
- `src/ir/local-utils.h`
- `src/ir/branch-utils.h`
- `src/ir/manipulation.h`
- `test/passes/simplify-locals-nonesting.wast`
- `test/passes/simplify-locals-nonesting.txt`
- `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`
- neighboring `simplify-locals*` variant WAT files for contrast

## Source-backed Binaryen contract retained

The older dossier mechanics remain correct after this refresh:

- upstream public name: `simplify-locals-nonesting`
- shared owner file: `SimplifyLocals.cpp`
- factory: `createSimplifyLocalsNoNestingPass()`
- exact policy: `SimplifyLocals<false, false, false>`
- disabled surfaces: fresh `local.tee` creation, structure formation, and ordinary new nesting
- still-enabled surfaces: flat copy retargeting, same-set-value-position substitution, equivalent-copy cleanup, final dead-set cleanup, and refinalization when needed
- dedicated proof surface: `simplify-locals-nonesting.wast` / `.txt`
- pipeline proof surface: `flatten -> simplify-locals-nonesting -> dfo` plus `souperify` / `souperify-single-use` combos

## Starshine status found in this run

Current Starshine has **no** active `simplify-locals-nonesting` implementation.
The precise local state is:

- `src/passes/optimize.mbt` tracks only the local alias `simplify-locals-no-nesting` in `pass_registry_removed_names()`.
- The exact upstream spelling `simplify-locals-nonesting` is not registered locally.
- `src/passes/optimize.mbt` rejects removed pass names in `run_hot_pipeline_expand_passes(...)` if called through the lower-level pipeline API.
- `src/cmd/cmd.mbt` accepts only active hot/module/preset registry categories as CLI pipeline pass flags, so the removed alias is reported to users as an unknown pass flag and is hidden from help.
- `src/passes/pass_manager.mbt` dispatches only the active full `simplify-locals` pass, not a nonesting sibling.
- `src/passes/simplify_locals.mbt` is the likely future landing zone, but today it implements the full local pass with ordinary sinking, structure formation, equivalent cleanup, and dead cleanup; it has no `allowTee` / `allowStructure` / `allowNesting` mode surface.
- `agent-todo.md` has no dedicated `simplify-locals-nonesting` / `simplify-locals-no-nesting` backlog slice.

## Future port shape

A faithful Starshine port should probably extend or sibling-split the active `src/passes/simplify_locals.mbt` machinery rather than create an unrelated owner file.
The future work needs a policy mode that can prove:

- no fresh tees
- no block / `if` / loop result-structure synthesis
- no sinking of non-copy values into arbitrary consumers
- copy retargeting and dead/equivalent cleanup still work
- the pass remains distinct from `simplify-locals-notee-nostructure`
- the local alias and upstream spelling decision is tested explicitly

## Pages updated

- `docs/wiki/binaryen/passes/simplify-locals-nonesting/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/flatness-variant-boundaries.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession

This note supersedes `docs/wiki/raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md` for raw-source provenance and Starshine local status only.
The older note remains useful for the first-pass mechanics reading and the original rationale for creating the folder.
