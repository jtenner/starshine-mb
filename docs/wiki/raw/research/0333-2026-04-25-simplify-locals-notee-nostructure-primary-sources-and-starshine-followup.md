# 0333 - `simplify-locals-notee-nostructure` primary sources and Starshine follow-up

## Scope

Refresh the existing `simplify-locals-notee-nostructure` dossier so it matches the current wiki quality bar:

- add an immutable Binaryen primary-source manifest
- add the missing dedicated Starshine status / port-strategy page
- add the missing source-confirmed implementation/test-map page
- make the older 0129 research note explicitly superseded for provenance and local status
- keep the already-good overview, Binaryen strategy, transformed-shape catalog, and variant-surface pages non-duplicative

## Why this pass was chosen

The folder already had useful 2026-04-20 teaching coverage, but it was still weaker than neighboring locals-family dossiers:

- no committed raw primary-source manifest existed under `docs/wiki/raw/binaryen/`
- no dedicated Starshine status page existed, so the local implementation truth was only scattered across `src/passes/optimize.mbt`, `src/cmd/cmd.mbt`, `src/passes/pass_manager.mbt`, the active full `simplify-locals` owner file, and `agent-todo.md`
- no dedicated implementation/test-map page existed, so readers had to infer the owner-file split from the Binaryen strategy page
- `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` still described the folder as a working dossier rather than a source-captured bridge

## Primary upstream sources reviewed

Captured in `docs/wiki/raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`:

- Binaryen GitHub release `version_129`
- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/opt-utils.h`
- `src/ir/local-utils.h`
- `src/ir/effects.h`
- `src/ir/equivalent_sets.h`
- `src/ir/linear-execution.h`
- `src/ir/properties.h`
- `src/ir/branch-utils.h`
- `src/ir/manipulation.h`
- `test/passes/simplify-locals-notee-nostructure.wast`
- `test/passes/simplify-locals-notee-nostructure.txt`
- neighboring `simplify-locals*` variant WAT/TXT files for contrast
- flatten-neighbor `simplify-locals-nonesting` combo lit files as adjacent flat-pipeline context, not as direct evidence for this sibling

## Source-backed Binaryen contract retained

The older dossier mechanics remain correct after this refresh:

- upstream public name: `simplify-locals-notee-nostructure`
- shared owner file: `SimplifyLocals.cpp`
- factory: `createSimplifyLocalsNoTeeNoStructurePass()`
- exact policy: `SimplifyLocals<false, false, true>`
- disabled surfaces: fresh `local.tee` creation and structure formation
- still-enabled surfaces: direct single-use sinking into existing consumers, ordinary nesting into existing use sites, equivalent-get cleanup, final dead-set cleanup, and refinalization when needed
- dedicated proof surface: `simplify-locals-notee-nostructure.wast` / `.txt`
- scheduler surface: aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood, including nested aggressive reruns from optimizing passes
- deliberate distinction from `simplify-locals-nonesting`: this sibling does not promise flatness preservation because `allowNesting` stays true

## Starshine status found in this run

Current Starshine has **no** active `simplify-locals-notee-nostructure` implementation.
The precise local state is:

- `src/passes/optimize.mbt` tracks only the local alias `simplify-locals-no-tee-no-structure` in `pass_registry_removed_names()`.
- The exact upstream spelling `simplify-locals-notee-nostructure` is not registered locally.
- `src/cmd/cmd.mbt` accepts only active hot/module/preset registry categories as CLI pipeline pass flags, so the removed alias is reported to users as an unknown pass flag and is hidden from help.
- `src/passes/pass_manager.mbt` dispatches only the active full `simplify-locals` pass, not a no-tee/no-structure sibling.
- `src/passes/simplify_locals.mbt` is the likely future landing zone, but today it implements the full local pass with ordinary sinking, structure formation, equivalent cleanup, and dead cleanup; it has no `allowTee` / `allowStructure` / `allowNesting` mode surface.
- `agent-todo.md` has no dedicated `simplify-locals-notee-nostructure` / `simplify-locals-no-tee-no-structure` backlog slice. The neighboring `SLNS` slice is for `simplify-locals-nostructure`, a different upstream variant.

## Future port shape

A faithful Starshine port should probably extend or sibling-split the active `src/passes/simplify_locals.mbt` machinery rather than create an unrelated owner file.
The future work needs a policy mode that can prove:

- no fresh tees
- no block / `if` / loop result-structure synthesis
- direct one-use sinking still works
- ordinary nesting into already-existing consumers remains allowed unless Starshine intentionally diverges
- equivalent-get cleanup and dead-set cleanup still work
- explicit EH and effect-ordering barriers remain conservative
- the pass remains distinct from both `simplify-locals-nostructure` and `simplify-locals-nonesting`
- the local alias and upstream spelling decision is tested explicitly

## Pages updated

- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession

This note supersedes `docs/wiki/raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md` for raw-source provenance and Starshine local status only.
The older note remains useful for the first-pass mechanics reading and the original rationale for creating the folder.
