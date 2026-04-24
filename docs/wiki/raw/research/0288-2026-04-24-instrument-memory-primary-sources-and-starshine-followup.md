# `instrument-memory` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages

## Question

The `instrument-memory` folder already had a useful upstream dossier from 2026-04-21, but it still lagged behind newer pass dossiers in two ways:

1. it cited online source URLs directly but had no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. it had no dedicated Starshine status / strategy page explaining exactly where the local repo implements, rejects, or does not even register the pass.

The maintenance question for this run was whether that gap was worth fixing even though `instrument-memory` is upstream-only and outside the no-DWARF / saved-`-O4z` parity queues.

## Sources reviewed

- New raw capture: `docs/wiki/raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`
- Existing research: `docs/wiki/raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`
- Existing living pages under `docs/wiki/binaryen/passes/instrument-memory/`
- Neighboring instrumentation page: `docs/wiki/binaryen/passes/instrument-locals/index.md`
- Binaryen release and source URLs recorded in the raw capture, especially:
  - `src/passes/InstrumentMemory.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/passes.h`
  - `test/lit/passes/instrument-memory.wast`
  - `test/lit/passes/instrument-memory-filter.wast`
  - `test/lit/passes/instrument-memory-gc.wast`
  - `test/lit/passes/instrument-memory64.wast`
- Local Starshine surfaces:
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `src/ir/hot_core.mbt`
  - `src/ir/hot_lift.mbt`
  - `src/ir/hot_lower.mbt`
  - `src/lib/types.mbt`
  - `src/binary/encode.mbt`
  - `src/binary/decode.mbt`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `agent-todo.md`

## Findings

- Binaryen `instrument-memory` is still best taught as a compact effectful postwalk plus module-level helper import injection.
- The upstream public help text remains too narrow: `pass.cpp` says the pass intercepts loads and stores, but `InstrumentMemory.cpp` and the dedicated lit files also cover `memory.grow` plus selected GC `struct.*` and `array.*` operations.
- The existing dossier's core `version_129` claims still held in the 2026-04-24 source recheck: helper imports are broader than filtered rewrites, the filter vocabulary is exact, memory64 widens address-side helper signatures, GC hooks are scalar-only, and `addsEffects()` is part of the pass contract.
- Current Starshine does not implement this pass and does not reserve its name in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()` in `src/passes/optimize.mbt`.
- That means explicit local requests would fail as an `unknown pass flag`, not as a boundary-only or removed pass. This is a sharper local status than the older upstream-only wording.
- Starshine does have reusable instruction surfaces for memory operations and selected GC operations (`HotOp::Load`, `HotOp::Store`, `HotOp::MemoryGrow`, library instruction variants, binary encode/decode, WAT lowering), but those are ordinary IR / parser / encoder infrastructure, not instrumentation-helper ABI or a partial implementation of Binaryen `instrument-memory`.
- `agent-todo.md` still has no dedicated `instrument-memory` slice, so no active local implementation plan was hidden outside the wiki.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/instrument-memory/starshine-strategy.md` as the dedicated local status and future-port map.
- Refreshed `index.md`, `binaryen-strategy.md`, `implementation-structure-and-tests.md`, `helper-import-roster-filters-and-unsupported-types.md`, and `wat-shapes.md` so they cite the raw primary-source manifest and cross-link the new Starshine strategy page.
- Refreshed `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Uncertainties and explicit non-claims

- No local implementation was added in this run.
- The current-main spot check was narrow; it was sufficient for wiki provenance refresh, not a full upstream drift audit.
- The future local implementation path is unresolved. A port would likely need a module-level import-injection pass, helper ABI synthesis, exact filter parsing, and a clear decision about whether Starshine wants to expose debug instrumentation passes at all.
- The wiki should not imply that `instrument-memory` is a parity blocker today. It is upstream-only tracking coverage unless a future product/debugging decision makes it locally relevant.
