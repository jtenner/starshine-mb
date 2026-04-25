# Binaryen `local-subtyping` implementation/test-map source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest and correction for the `docs/wiki/binaryen/passes/local-subtyping/` dossier

## Scope

This file captures the official online Binaryen sources rechecked while deepening the `local-subtyping` dossier. It supersedes the teaching conclusions in `docs/wiki/raw/binaryen/2026-04-22-local-subtyping-primary-sources.md` where that older manifest described the pass as set/tee-only, parameter-skipping at scan time, `TypeUpdating::canHandleAsLocal(...)`-gated, and non-refinalizing.

The corrected source reading is that Binaryen `version_129` and current `main` use the same teaching-relevant strategy checked here: collect relevant reference locals, remember both sets and gets, iteratively refinalize while type evidence improves, compute LUBs from set values, gate non-null locals with structural dominance over gets, rewrite only non-parameter body-local declarations, and retag `local.get` / `local.tee` expression types.

## Official source files consulted

### Tagged `version_129` oracle

- `LocalSubtyping.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `lubs.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `local-structural-dominance.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- `lubs.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.cpp>

### Current-main spot check

- `LocalSubtyping.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `local-subtyping.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>

### Official test files consulted

- `local-subtyping.wast` in `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## Corrected source observations

- `LocalSubtyping` is a function-parallel optimization pass; `isFunctionParallel()` returns `true` in the owner file.
- `doWalkFunction(...)` exits unless GC is enabled.
- The first nested `Scanner` marks locals relevant when their current type is a reference type. The source has a TODO about ignoring params, so the scanner itself is not body-local-only.
- The scanner records both:
  - `local.set` / `local.tee` sites for relevant locals
  - `local.get` sites for relevant locals
- The outer loop is iterative. It calls `ReFinalize().walkFunctionInModule(func, module)` before each scan after the first iteration, because earlier local declaration rewrites can make later set-value types more precise.
- Candidate types are computed from set/tee value types with `LUBFinder`. The pass does not directly treat gets as LUB evidence, but gets are central to non-null dominance and type repair.
- Locals without any recorded set are skipped. The source carries a TODO that such locals are always null and could be handled in the future.
- If the candidate type is non-defaultable, Binaryen currently requires that it is a non-null reference and that `LocalStructuralDominance(...).getNonDominatingIndices(...)` returns no non-dominated gets. Otherwise the candidate is re-nullified.
- Declaration rewriting starts at `func->getVarIndexBase()`, so parameters are still not rewritten even though the scanner may record them.
- `local.get` expression types are updated to the new local declaration unless the get is one of the non-dominated sites kept at the old nullable type.
- `local.tee` expression types are updated from the rewritten local declaration.
- The pass returns `changed` if any declaration changed; the loop reruns until no further declaration refinement is found.

## Dedicated lit-test surface

The official `local-subtyping.wast` file is the direct proof surface for the user-visible behavior. It covers:

- basic local declaration narrowing
- non-nullability with dominated gets
- loops and dominance failures
- `local.tee` retagging
- repeated refinement that depends on refinalization
- named-type LUB cases
- parameter and nondefaultable tuple preservation
- many combinations with `optimize-casts`, `coalesce-locals`, and `local-cse` in the same local-cleanup neighborhood

## Current-main freshness result

A focused current-main recheck found no teaching-relevant drift from the tagged `version_129` contract on the checked owner, scheduler, helper, and dedicated-test surfaces. The important correction is therefore not a `version_129` vs current-main drift; it is a correction to this repository's earlier 2026-04-22 source interpretation.

## Consumability rule

Use this file as the provenance anchor for the corrected `local-subtyping` living pages added or refreshed on 2026-04-25. Keep the older 2026-04-22 manifest as historical provenance, but treat the corrected conclusions here as stronger for implementation planning and reader-facing explanations.
