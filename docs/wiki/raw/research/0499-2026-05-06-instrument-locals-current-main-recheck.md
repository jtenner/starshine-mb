# `instrument-locals` current-main recheck

_Date:_ 2026-05-06  
_Status:_ filed-back research note  
_Related living pages:_ `docs/wiki/binaryen/passes/instrument-locals/`

## Question

Did current Binaryen `main` drift from the existing `instrument-locals` dossier contract, and if not, what exact source surfaces should the wiki keep pointing at?

## Findings

- Current Binaryen `main` did **not** show teaching-relevant drift from the earlier dossier.
- `InstrumentLocals.cpp` still implements an effect-adding postwalk plus module helper-import injection.
- The source-backed rewrite surface remains narrower than the helper roster: `get_i64` / `set_i64` imports are still added, but ordinary `i64` local traffic still returns early in the get/set visitors.
- The public pass-help wording remains broader than the implementation: it says the build is instrumented to intercept loads and stores, while the owner file handles local reads/writes. The wiki should keep that contradiction explicit.
- Starshine still treats `instrument-locals` as unknown rather than boundary-only or removed.

## Code locations checked

- `src/passes/InstrumentLocals.cpp` - helper roster, `addsEffects()`, local get/set wrapping, and module import injection.
- `src/passes/pass.cpp` - public pass registration and help text.
- `test/lit/passes/instrument-locals_all-features_disable-gc.wast` - helper roster, shared call-id sequencing, and ordinary `i64` no-op proof.
- `test/lit/passes/instrument-locals_effects.wast` - global-effects invalidation proof.
- `test/lit/passes/instrument-locals-eh-legacy.wast` - `Pop` boundary proof.
- `src/passes/optimize.mbt` - current local unknown-pass status.
- `src/lib/types.mbt`, `src/lib/module.mbt`, `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, `src/ir/effects.mbt` - module/import substrate and HOT local traffic surfaces that a future port would need.
- `src/passes/registry_test.mbt` - registry and preset coverage, still lacking `instrument-locals` expectations.

## Source links

- `docs/wiki/raw/binaryen/2026-05-06-instrument-locals-current-main-recheck.md`
- `docs/wiki/raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`
- Binaryen current-main `InstrumentLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main `instrument-locals_all-features_disable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- Binaryen current-main `instrument-locals_effects.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
- Binaryen current-main `instrument-locals-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>

## Filed-back changes

- Refreshed the living `instrument-locals` overview, strategy, implementation/test-map, shape catalog, and Starshine bridge pages to point at the new 2026-05-06 freshness layer.
- Updated the wiki index, pass folder index, and tracker entry so the new source bridge is visible from the shared catalogs.

## Blocker

The run started with many unrelated uncommitted shared wiki and source changes. Commit only if those changes can be isolated safely; otherwise leave the note and the living-page edits for the owning thread to merge deliberately.
