# `instrument-locals` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages

## Question

The `instrument-locals` folder already had a useful upstream dossier from 2026-04-21, but it still lagged behind newer pass dossiers in two ways:

1. it cited online source URLs directly but had no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. it had no dedicated Starshine status / strategy page explaining exactly where the local repo implements, rejects, or does not even register the pass.

The maintenance question for this run was whether that gap was worth fixing even though `instrument-locals` is upstream-only and outside the no-DWARF / saved-`-O4z` parity queues.

## Sources reviewed

- New raw capture: `docs/wiki/raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`
- Existing research: `docs/wiki/raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md`
- Existing living pages under `docs/wiki/binaryen/passes/instrument-locals/`
- Neighboring instrumentation page: `docs/wiki/binaryen/passes/instrument-memory/index.md`
- Binaryen release and source URLs recorded in the raw capture, especially:
  - `src/passes/InstrumentLocals.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/passes.h`
  - `test/lit/passes/instrument-locals_all-features_disable-gc.wast`
  - `test/lit/passes/instrument-locals_effects.wast`
  - `test/lit/passes/instrument-locals-eh-legacy.wast`
- Local Starshine surfaces:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `agent-todo.md`

## Findings

- Binaryen `instrument-locals` is still best taught as a tiny effectful postwalk over local traffic plus module-level helper import injection.
- The upstream public help text remains broader than the owner file: `pass.cpp` says "loads and stores," but `InstrumentLocals.cpp` instruments `local.get` and `local.set` / `local.tee` traffic, not memory operations.
- The existing dossier's core `version_129` claims still held in the 2026-04-24 source recheck: helper imports are broader than actual rewrite coverage, `i64` ordinary locals remain a TODO/no-op path, general references and typed function references are not fully supported, `Pop` payloads are skipped, and `addsEffects()` is part of the pass contract.
- Current Starshine does not implement this pass and does not even reserve its name in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()` in `src/passes/optimize.mbt`.
- That means explicit local requests would fail as an `unknown pass flag`, not as a boundary-only or removed pass. This is a sharper local status than the older upstream-only wording.
- The local optimizer's existing imported-function counting helper in `src/passes/optimize.mbt` is validation/pipeline hygiene, not an instrumentation-helper ABI or a partial implementation of Binaryen `instrument-locals`.
- `agent-todo.md` still has no dedicated `instrument-locals` slice, so no active local implementation plan was hidden outside the wiki.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/instrument-locals/starshine-strategy.md` as the dedicated local status and future-port map.
- Refreshed `index.md`, `binaryen-strategy.md`, `implementation-structure-and-tests.md`, `unsupported-types-effects-and-import-roster.md`, and `wat-shapes.md` so they cite the raw primary-source manifest and cross-link the new Starshine strategy page.
- Refreshed `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md`.

## Uncertainties and explicit non-claims

- No local implementation was added in this run.
- The current-main spot check was narrow; it was sufficient for wiki provenance refresh, not a full upstream drift audit.
- The future local implementation path is unresolved. A port would likely need a module-level import-injection pass and a clear decision about whether Starshine wants to expose debug instrumentation passes at all.
- The wiki should not imply that `instrument-locals` is a parity blocker today. It is upstream-only tracking coverage unless a future product/debugging decision makes it locally relevant.
