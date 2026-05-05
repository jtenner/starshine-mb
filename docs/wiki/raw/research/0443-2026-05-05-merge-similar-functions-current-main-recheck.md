# 0443 - `merge-similar-functions` current-main refresh and status correction

Date: 2026-05-05  
Status: completed research ingest  
Pass: `merge-similar-functions`  
Local registry status: `removed` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/merge-similar-functions/`

## Why this follow-up exists

The `merge-similar-functions` dossier was already source-correct and mechanically deep, but its local status wording had drifted: the living pages still called it boundary-only even though the current registry code places it in the removed-name list.

This follow-up records the 2026-05-05 source refresh and corrects the living pages so they describe the current Starshine state honestly:

- removed-registry known name
- explicit request rejection before execution
- no local owner file
- no module dispatcher case
- no active backlog slice
- no preset role

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/MergeSimilarFunctions.cpp`
  - `src/passes/pass.cpp`
  - `src/ir/hashed.h`
  - `src/ir/manipulation.h`
  - `src/ir/module-utils.h`
  - `src/ir/names.h`
  - `src/wasm-limits.h`
  - `test/lit/passes/merge-similar-functions.wast`
  - `test/lit/passes/merge-similar-functions_all-features.wast`
  - `test/lit/passes/merge-similar-functions_types.wast`
  - `test/lit/passes/merge-similar-functions-param-limit.wast`
- Tagged comparison anchor:
  - the same owner and lit files on `version_129`
- Existing living dossier pages for the pass

## Source-backed Binaryen conclusions

- `merge-similar-functions` is still the same late whole-module shrink pass.
- The contract is helper-plus-thunk parameterization of near-duplicate functions, not exact-duplicate removal.
- The source-backed difference surface remains narrow: literal `Const` payloads and, with reference types plus GC, direct-call targets that can be parameterized safely.
- Hashing is only a prefilter; exact class formation is separate.
- `255` synthetic params is a hard boundary.
- The current-main recheck did not surface teaching-relevant drift on the reviewed surfaces.

## Starshine local code map

The current local state is removed-registry, not boundary-only:

- `src/passes/optimize.mbt:145-146`
  - `pass_registry_removed_names()` includes `merge-similar-functions`.
- `src/passes/optimize.mbt:504-523`
  - `run_hot_pipeline_expand_passes(...)` rejects removed requests before any execution.
- `src/passes/optimize.mbt:451-459`
  - `shrink_preset_passes(...)` does not include `merge-similar-functions`.
- `src/passes/pass_manager.mbt:8912-8940`
  - the module-pass dispatcher has no `merge-similar-functions` case.
- `src/cmd/cmd.mbt:1638-1642`
  - default pass synthesis only produces `optimize` or `shrink`.
- `src/cmd/cmd.mbt:3475-3479`
  - explicit pass flags are expanded before execution, but there is still no `merge-similar-functions` implementation hook.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - the older batch map still records the pass.
- `agent-todo.md`
  - no active `merge-similar-functions` slice was present at this review point.

## Local status conclusion

Starshine preserves `merge-similar-functions` as a known removed-name pass. That is useful because CLI / registry surfaces can reject it explicitly, but it is not executable.

There is still no local owner file equivalent to Binaryen's `MergeSimilarFunctions.cpp`, no module dispatcher case, no active preset slot, no implementation tests, and no active backlog slice.

## Future-port constraints

A faithful future port should remain module-level work, not a HOT peephole.
It must preserve the helper-plus-thunk rewrite, the call-target parameterization gates, the local-index repair, and the profitability boundary before claiming parity.

Minimum future-port checklist:

1. keep the public `merge-similar-functions` registry entry separate from `duplicate-function-elimination`, `duplicate-import-elimination`, and `inlining`;
2. run in a late module-cleanup context rather than the current hot preset by default;
3. scan only defined functions and reject imports, mismatched function signatures, and mismatched total local counts;
4. implement hash prefiltering and then exact equivalence-class splitting; do not treat same-hash as merge proof;
5. limit parameterizable differences to the source-backed literal and direct-callee families until broader proof exists;
6. reuse one synthetic parameter for repeated identical per-function difference vectors;
7. build helpers with original params first and synthetic params appended;
8. repair old non-param local indices after appending synthetic params;
9. preserve original function names as thunks that forward original params plus per-function payloads;
10. implement the reference-types-plus-GC and same-function-type gates for direct-callee indirection;
11. preserve `call` / `return_call` and `call_ref` / `return_call_ref` style where Binaryen does;
12. enforce the `255` synthetic-param boundary; and
13. keep an explicit profitability check so tiny legal functions can remain unchanged.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/equivalence-classes-param-derivation-and-thunk-rewrites.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/profitability-indirection-and-type-barriers.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-25 `merge-similar-functions` source notes.
It supersedes the stale boundary-only wording in the living dossier, but it does not replace the earlier algorithm, implementation, or mechanics explanations.
