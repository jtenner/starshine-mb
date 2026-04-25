# 0332 - `merge-similar-functions` primary sources and Starshine follow-up

Date: 2026-04-25  
Status: completed research ingest  
Pass: `merge-similar-functions`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/merge-similar-functions/`

## Why this follow-up was needed

The `merge-similar-functions` folder already had a landing page, Binaryen strategy, upstream file/test map, focused mechanics guide, profitability/type-barrier guide, and WAT-shape catalog. It still lacked the same two durability pieces added to newer pass dossiers:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine status / port-strategy page with exact local code locations.

This follow-up keeps the existing teaching contract instead of creating a near-duplicate folder.

## Primary online sources reviewed

- Binaryen release page for `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` source:
  - `src/passes/MergeSimilarFunctions.cpp`
  - `src/passes/pass.cpp`
  - `src/pass.h`
  - helper context in `src/ir/hashed.h`, `src/ir/manipulation.h`, `src/ir/module-utils.h`, `src/ir/names.h`, and `src/wasm-limits.h`
- Binaryen `version_129` tests:
  - `test/lit/passes/merge-similar-functions.wast`
  - `test/lit/passes/merge-similar-functions_all-features.wast`
  - `test/lit/passes/merge-similar-functions_types.wast`
  - `test/lit/passes/merge-similar-functions-param-limit.wast`
- Current Binaryen `main` spot checks:
  - `src/passes/MergeSimilarFunctions.cpp`
  - `test/lit/passes/merge-similar-functions.wast`

The committed raw manifest is `docs/wiki/raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`.

## Source-backed Binaryen conclusions

- `merge-similar-functions` is a real public Binaryen pass name registered separately from `duplicate-function-elimination`, `inlining`, and `monomorphize`.
- The pass is a late whole-module shrink pass, not a hot per-function peephole. Binaryen schedules it in global post-passes only when `shrinkLevel >= 2`.
- The owner file is `src/passes/MergeSimilarFunctions.cpp`.
- The implementation builds helper-plus-thunk rewrites for near-duplicate functions by:
  1. rejecting imported functions, signature mismatches, and total-local-count mismatches,
  2. grouping with a custom function hash that ignores only supported difference sites,
  3. splitting buckets into real equivalence classes with exact structural comparison,
  4. deriving reusable synthetic parameters from lockstep expression-slot traversal,
  5. cloning one primary body into a generated helper and repairing non-param local indices after appending synthetic params, and
  6. replacing originals with original-name-preserving thunks.
- The supported difference surface is intentionally narrow: literal `Const` payloads and, when reference types plus GC allow it, direct `Call` targets that can safely become function-reference parameters.
- Profitability is part of the contract. Legal classes may stay unchanged when the helper/thunk overhead outweighs the saved duplication.
- The `MaxSyntheticFunctionParams` / `255` boundary is also part of the contract, proven by the dedicated param-limit lit file.
- The narrow current-`main` check did not reveal teaching-relevant drift in the reviewed owner/test surfaces. It was not a full audit of all helper dependencies.

## Starshine local code map

Exact local surfaces reviewed:

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` contains `merge-similar-functions`.
  - `pass_registry_entries()` turns every boundary-only name into a `BoundaryOnly` registry entry with no descriptor.
  - `run_hot_pipeline_expand_passes(...)` rejects `BoundaryOnly` entries with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `merge-similar-functions`; the current local shrink preset is still the same active hot/module subset as optimize, not Binaryen's full `shrinkLevel >= 2` late-global schedule.
- `src/cmd/cmd.mbt`
  - `resolve_effective_pass_flags(...)` can synthesize only `optimize` or `shrink` from `-O` / `-Oz`-style optimization flags when no explicit pass list is provided.
  - `make_optimize_options(...)` carries `shrink_level`, `monomorphize_min_benefit`, `closed_world`, low-memory options, traps policy, validation policy, and stack-function-pass controls, but there is no `merge-similar-functions` implementation hook or dedicated option.
- `src/cli/cli.mbt`
  - long-form kebab-case pass flags are collected into `CliParseResult.pass_flags`; pass availability is resolved later by the optimizer registry rather than by a `merge-similar-functions` parser special case.
- `src/passes/pass_manager.mbt`
  - active hot/module pipeline plumbing exists, but there is no `MergeSimilarFunctions` module-pass dispatcher case or owner implementation.
- `src/lib/types.mbt`
  - prerequisite module surfaces exist (`FuncIdx`, `TypeIdx`, `FuncCompType`, `Func`, `Code`, imports/exports/elements, locals, `call`, `return_call`, `ref.func`, `call_ref`, and related instruction variants), but these are only representation infrastructure, not a near-duplicate-function parameterization pass.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - lists `merge-similar-functions` among Batch 4 compatibility / boundary names.
- `agent-todo.md`
  - has no active `merge-similar-functions` slice at the time of this review.

## Local status conclusion

Starshine currently preserves `merge-similar-functions` as a known boundary-only pass name. That is useful because the CLI/registry can distinguish it from an unknown pass flag, but it is not executable. A direct request for `--merge-similar-functions` should fail before any hot or module pass body runs.

There is no local owner file equivalent to Binaryen's `MergeSimilarFunctions.cpp`, no module dispatcher case, no active preset slot, no implementation tests, and no active backlog slice.

## Future-port constraints

A faithful port should be module-level work, not a HOT peephole, because it must compare many defined functions, synthesize helper functions, replace existing function bodies with thunks, update call/call-ref/type/local-index details, and preserve module-level naming and export behavior.

Minimum future-port checklist:

1. keep the public `merge-similar-functions` registry entry separate from `duplicate-function-elimination`, `inlining`, and `monomorphize`,
2. run late in a size-biased module-cleanup context rather than in the current hot preset by default,
3. scan only defined functions and reject imports, mismatched function signatures, and mismatched total local counts,
4. implement hash prefiltering and then exact equivalence-class splitting; do not treat same-hash as merge proof,
5. limit parameterizable differences to the source-backed literal and direct-callee families until broader proof exists,
6. reuse one synthetic parameter for repeated identical per-function difference vectors,
7. build helpers with original params first and synthetic params appended,
8. repair old non-param local indices after appending synthetic params,
9. preserve original function names as thunks that forward original params plus per-function payloads,
10. implement the reference-types-plus-GC and same-function-type gates for direct-callee indirection,
11. preserve `call` / `return_call` and `call_ref` / `return_call_ref` style where Binaryen does,
12. enforce the `255` synthetic-param boundary, and
13. keep an explicit profitability check so tiny legal functions can remain unchanged.

## Uncertainty and supersession

- This note supersedes `docs/wiki/raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md` and `docs/wiki/raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md` for raw-source provenance and Starshine status. The older notes remain useful historical research and still agree with the core source reading.
- The current-main check was intentionally narrow and does not prove every helper dependency has identical behavior since `version_129`.
- The local Batch 4 map preserves intent, but without an `agent-todo.md` slice it should not be read as active implementation work.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/equivalence-classes-param-derivation-and-thunk-rewrites.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/profitability-indirection-and-type-barriers.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
