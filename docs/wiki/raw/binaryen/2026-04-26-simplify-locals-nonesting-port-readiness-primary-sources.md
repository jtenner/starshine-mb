# Binaryen `simplify-locals-nonesting` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable current-main / Starshine-readiness bridge for the `docs/wiki/binaryen/passes/simplify-locals-nonesting/` dossier

## Scope

This source capture supplements the 2026-04-25 primary-source manifest for `simplify-locals-nonesting`.
It focuses on the first Starshine-port slice and validation ladder rather than re-explaining the whole pass.
The living pages should cite this file when they discuss future implementation order or current-main freshness.

## Official online sources rechecked

- Binaryen `src/passes/SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
  - Teaching use: shared `SimplifyLocals<allowTee, allowStructure, allowNesting>` engine, the `createSimplifyLocalsNoNestingPass()` factory, the `allowNesting == false` sink gate, the late equivalent-local cleanup, and dead-set cleanup.
- Binaryen `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Teaching use: public pass spelling `simplify-locals-nonesting` and official flatness-preserving description.
- Binaryen `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Teaching use: first-class public constructor surface.
- Binaryen dedicated tests
  - `test/passes/simplify-locals-nonesting.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - `test/passes/simplify-locals-nonesting.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - current-main input: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast>
  - current-main expected output: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt>
  - Teaching use: flat local-copy cleanup positives and no visible tee/structure/nesting synthesis in the dedicated expected output.
- Binaryen combo lit tests
  - `flatten_simplify-locals-nonesting_dfo_O3.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - Teaching use: the pass has a real flatten-neighbor role before flatness-sensitive downstream analysis/extraction passes.

## Starshine local sources rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` includes the local compatibility spelling `simplify-locals-no-nesting`.
  - Active presets use full `simplify-locals`, not the nonesting sibling.
  - `run_hot_pipeline_expand_passes(...)` rejects removed names if they reach the lower-level pipeline.
- `src/cmd/cmd.mbt`
  - `cmd_resolve_pipeline_steps(...)` accepts only active hot, module, or preset entries as CLI pass flags, so the removed local alias remains hidden/rejected at the CLI layer.
- `src/passes/pass_manager.mbt`
  - `hot_pass_run(...)` dispatches active hot descriptors; there is no sibling descriptor or policy mode for nonesting today.
- `src/passes/simplify_locals.mbt`
  - `simplify_locals_descriptor()` and `simplify_locals_summary()` name the full active pass.
  - The current run loop includes main sinking, dead cleanup, structure rewrites, and late equivalent cleanup; those surfaces are reusable, but they are not currently parameterized by Binaryen's `allowTee` / `allowStructure` / `allowNesting` axes.

## Current-main freshness result

No teaching-relevant drift was found for this port-readiness bridge.
The current-main sources still expose the same public pass spelling, shared owner file, constructor family, dedicated test pair, and flatten-neighbor lit role captured in the 2026-04-25 dossier.
This recheck does **not** claim byte-for-byte equivalence or a full semantic audit of all shared `SimplifyLocals.cpp` internals after `version_129`; it is a focused source check for the future Starshine first-slice plan.

## Durable conclusions

- A faithful Starshine port should be a policy-mode sibling of the active full `simplify-locals` implementation, not a separate one-off peephole pass.
- The minimum safe first slice is analyzer/registry honesty plus flat copy-chain cleanup and direct set-value rewriting while all three aggressive axes remain disabled: no fresh tee, no structure synthesis, and no non-copy ordinary-consumer nesting.
- Later slices can add late equivalent-copy cleanup and dead-set cleanup reuse, but only after negative tests prove that full-pass structure rewrites and nested sinks remain disabled.
- The local spelling policy is unresolved: Starshine currently stores only `simplify-locals-no-nesting`, while Binaryen publishes `simplify-locals-nonesting`.
- Validation should compare against Binaryen's `--simplify-locals-nonesting` only after the local alias / upstream spelling decision is explicit in tests and docs.
