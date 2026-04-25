# Binaryen `coalesce-locals` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest and focused freshness bridge for the `docs/wiki/binaryen/passes/coalesce-locals/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `coalesce-locals` wiki-health pass. It complements, but does not replace, the tagged-source manifest in [`2026-04-22-coalesce-locals-primary-sources.md`](./2026-04-22-coalesce-locals-primary-sources.md).

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
- `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`

## Provenance

### Official source files consulted

- `CoalesceLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
  - Important visible anchors reviewed:
    - `doWalkFunction`, `increaseBackEdgePriorities`, and `calculateInterferences`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp#L371-L474>
    - greedy index picking and reverse-order comparison: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp#L693-L735>
    - `applyIndices` cleanup: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp#L736-L770>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Important visible anchors reviewed:
    - public registrations for `coalesce-locals` and `coalesce-locals-learning`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L742-L747>
    - default no-DWARF late function pipeline slots: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L1857-L1892>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Reviewed for nested after-inlining rerun context.
- Helper surfaces carried over from the tagged manifest:
  - `liveness-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>

### Official test files consulted

- `coalesce-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>
  - Important visible anchors reviewed:
    - type and interference negative cases plus equal-value overlap positive: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast#L157-L278>
    - copy-removal and dead-set cleanup families: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast#L279-L420>
    - loop/backedge and greedy-order families: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast#L421-L600>

## Durable observations from the captured sources

- Binaryen `version_129` remains the stable tagged source oracle for this dossier.
- A focused 2026-04-25 current-`main` recheck of `CoalesceLocals.cpp`, `pass.cpp`, `opt-utils.h`, and `coalesce-locals.wast` did not reveal a teaching-relevant drift from the living dossier's `version_129` contract. This is a narrow spot check, not a claim that every whitespace or helper refactor was identical.
- The important owner-file shape is still concentrated in `CoalesceLocals.cpp`: `LivenessWalker` setup, backedge copy priority boosting, value-numbered interference, exact-type greedy coloring, reverse-order comparison that prefers removed copies, and `applyIndices` cleanup/refinalization.
- The registration surface still exposes both public names, `coalesce-locals` and `coalesce-locals-learning`; the normal no-DWARF optimize path uses `coalesce-locals` twice.
- The dedicated lit file remains the best upstream teaching source for shape families: exact-type positives, type/interference negatives, equal-value overlap positives, zero-init cases, redundant-copy removal, dead-set/dead-tee cleanup, loop-backedge priority, and greedy-order sensitivity.
- Starshine status did not change during this recheck: the pass is still tracked as a removed name, not implemented by an active owner file.

## Consumability rule

When future pages need current-main freshness for `coalesce-locals`, cite this recheck together with the tagged raw manifest and the living dossier. Do not move the explanatory contract into this raw file; keep beginner-to-advanced interpretation in `docs/wiki/binaryen/passes/coalesce-locals/`.
