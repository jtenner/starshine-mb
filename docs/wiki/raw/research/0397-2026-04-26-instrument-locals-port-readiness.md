# `instrument-locals` port-readiness follow-up

_Date:_ 2026-04-26  
_Status:_ filed-back research note  
_Related living pages:_ `docs/wiki/binaryen/passes/instrument-locals/`

## Question

The `instrument-locals` dossier was already source-backed, but the Starshine page still made a future implementer infer the first safe local slice from the general upstream walkthrough. This follow-up asks:

1. Did Binaryen current `main` drift from the 2026-04-24 dossier contract?
2. What Starshine implementation slice would be valid and beginner-explainable if this pass is ever ported?
3. Which local code surfaces are relevant, and which are red herrings?

## Findings

- Current Binaryen `main` did **not** show teaching-relevant drift from the earlier dossier. `InstrumentLocals.cpp` still implements an effect-adding postwalk plus module helper-import injection.
- The source-backed rewrite surface remains narrower than the helper roster. `get_i64` / `set_i64` imports are still added, but ordinary `i64` local traffic still returns early in the get/set visitors.
- The public pass-help wording remains broader than the implementation: it says the build is instrumented to intercept loads and stores, while the owner file handles local reads/writes. The wiki should keep that contradiction explicit.
- Starshine currently rejects `instrument-locals` as an unknown pass name, not as boundary-only or removed.
- Starshine has reusable pieces for function imports (`src/lib/types.mbt`, `src/lib/module.mbt`) and HOT local nodes (`src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`), but no current instrumentation-pass owner that synthesizes helper function types/imports and reports Binaryen-like `addsEffects()` invalidation.

## Recommended future slice

If Starshine ever ports this pass, start with a scalar module pass, not a HOT-only peephole:

1. Add a deliberate registry status for `instrument-locals`: active module pass, boundary-only compatibility, removed compatibility, or explicitly kept-unknown.
2. If active, synthesize `env` helper imports and function types before rewriting bodies.
3. Implement only `i32`, `f32`, and `f64` local.get / local.set / local.tee wrapping first.
4. Preserve `i64`, reference, SIMD, unreachable-value, and `Pop` cases as negative fixtures.
5. Validate import-index/function-index stability after inserting helper imports.
6. Add an effect-composition test before composing with effect-sensitive cleanup passes.

## Code locations checked

- `src/passes/optimize.mbt:126-153` - boundary-only / removed names; no `instrument-locals`.
- `src/passes/optimize.mbt:156-267` - active pass and preset entries; no `instrument-locals`.
- `src/passes/optimize.mbt:363-367` and `446-489` - lookup and unknown-pass rejection behavior.
- `src/passes/optimize.mbt:407-421` - imported-function counting; useful for validating pipeline bookkeeping, but not helper import synthesis.
- `src/lib/types.mbt:181-185`, `430`, `8084-8085` - function imports and import sections.
- `src/lib/module.mbt:146-151` - function-import participation in module index construction.
- `src/ir/hot_core.mbt:42-44`, `src/ir/hot_lift.mbt:492-580` - local HOT node surface.
- `src/ir/effects.mbt:134-135` - current local-state effect modeling.
- `src/passes/registry_test.mbt:1-90`, `134-157` - registry and preset tests.

## Source links

- `docs/wiki/raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`
- Binaryen current-main `InstrumentLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
- Binaryen current-main `instrument-locals_all-features_disable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- Binaryen current-main `instrument-locals_effects.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
- Binaryen current-main `instrument-locals-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>

## Filed-back changes

- Added `docs/wiki/binaryen/passes/instrument-locals/starshine-port-readiness-and-validation.md`.
- Refreshed the overview and Starshine strategy page so the first-slice sequence and red-herring imported-function counter are explicit.
- Updated wiki index/log and pass catalog entries.

## Blocker

The run started with many unrelated uncommitted shared wiki and source changes. Commit only if those changes can be isolated safely; otherwise leave this note and the living-page edits unstaged for the owning thread to merge deliberately.
