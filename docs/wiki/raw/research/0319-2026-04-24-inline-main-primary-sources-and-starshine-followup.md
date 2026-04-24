# 0319 - `inline-main` primary sources and Starshine follow-up

Date: 2026-04-24  
Status: completed research ingest  
Pass: `inline-main`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/inline-main/`

## Why this follow-up was needed

The `inline-main` folder already had a landing page, Binaryen strategy, upstream file/test map, focused boundary guide, and WAT-shape catalog. It still lacked the same two durability pieces added to newer pass dossiers:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine status / port-strategy page with exact local code locations.

This follow-up keeps the existing teaching contract rather than creating a near-duplicate folder.

## Primary online sources reviewed

- Binaryen release page for `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` source:
  - `src/passes/Inlining.cpp`
  - `src/passes/pass.cpp`
  - helper context in `src/pass.h`, `src/passes/opt-utils.h`, `src/ir/find_all.h`, `src/ir/branch-utils.h`, `src/ir/names.h`, `src/ir/metadata.h`, and `src/ir/type-updating.h`
- Binaryen `version_129` test:
  - `test/lit/passes/inline-main.wast`
- Current Binaryen `main` spot checks:
  - `src/passes/Inlining.cpp`
  - `test/lit/passes/inline-main.wast`

The committed raw manifest is `docs/wiki/raw/binaryen/2026-04-24-inline-main-primary-sources.md`.

## Source-backed Binaryen conclusions

- `inline-main` is a real public Binaryen pass name registered separately from `inlining` and `inlining-optimizing`.
- The `InlineMainPass` chooser is intentionally narrow: defined `main`, defined `__original_main`, direct `Call` scan inside `main`, and exactly one target call.
- Imported `main`, imported `__original_main`, missing endpoints, zero calls, and multiple direct calls are all intentional no-op or bailout families.
- Successful rewriting is not a textual splice. The pass calls shared `doInlining(...)`, so it inherits ordinary inline-body repair: copied-body insertion, local/parameter remapping, return-to-break handling, label uniqueness, metadata copying, refinalization, and nondefaultable-local handling.
- The dedicated lit file is sufficient for the special-case chooser matrix but not for every shared-helper corner inherited from ordinary `inlining`.
- The narrow current-`main` spot check did not reveal teaching-relevant chooser drift. It was not a full shared-helper audit.

## Starshine local code map

Exact local surfaces reviewed:

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` contains `inline-main`.
  - `pass_registry_entries()` turns every boundary-only name into a `BoundaryOnly` registry entry with no descriptor.
  - `run_hot_pipeline_expand_passes(...)` rejects `BoundaryOnly` entries with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `inline-main`.
- `src/cmd/cmd.mbt`
  - `InliningOptions` currently contains only a placeholder `no_op` field.
  - `OptimizeOptions` carries `inlining`, `monomorphize_min_benefit`, `closed_world`, `low_memory_unused`, `low_memory_bound`, `traps_never_happen`, and validation controls, but no dedicated `inline-main` implementation hook.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - lists `inline-main` among Batch 4 compatibility / boundary names.
- `agent-todo.md`
  - has no active `inline-main` slice at the time of this review.

## Local status conclusion

Starshine currently preserves `inline-main` as a known boundary-only pass name. That is useful because the CLI/registry can distinguish it from unknown pass flags, but it is not executable. A direct request for `--inline-main` should fail before any hot or module pass body runs.

There is no local owner file equivalent to Binaryen's `InlineMainPass`, no shared inlining helper in active pass code that could safely substitute for it, no active preset role, and no active backlog slice.

## Future-port constraints

A faithful port should be module-level work, not a HOT peephole, because it must inspect two named module functions and rewrite a caller body using a callee body.

Minimum future-port checklist:

1. keep the public `inline-main` registry entry separate from `inlining`,
2. find exactly the functions named `main` and `__original_main`,
3. reject missing or imported endpoints,
4. scan only direct call expressions in `main`,
5. require exactly one call to `__original_main`,
6. reuse or build a full inline-body rewrite helper with local/parameter remapping, return lowering, label repair, metadata decisions, refinalization, and nondefaultable-local repair,
7. do not schedule the pass into default no-DWARF presets unless a later local policy change says so explicitly.

## Uncertainty and supersession

- This note supersedes `docs/wiki/raw/research/0177-2026-04-21-inline-main-binaryen-research.md` for raw-source provenance and Starshine status. The older note remains useful historical research and still agrees with the core source reading.
- The `InliningAction(..., true)` argument remains an inherited-helper nuance. The current dossier should keep its practical meaning as an inference rather than a source-commented upstream guarantee.
- The current-main check was intentionally narrow and does not prove all shared helper behavior is unchanged since `version_129`.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/binaryen/passes/inline-main/starshine-strategy.md`
- `docs/wiki/binaryen/passes/inline-main/index.md`
- `docs/wiki/binaryen/passes/inline-main/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inline-main/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inline-main/special-case-contract-and-boundaries.md`
- `docs/wiki/binaryen/passes/inline-main/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
