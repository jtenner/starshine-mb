# Binaryen `directize` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/directize/` dossier

## Scope

This file captures the focused primary online sources checked on 2026-04-25 to refresh the existing `directize` dossier.
The dossier already had a `version_129` source manifest; this source bridge answers one narrower maintenance question:

- has current Binaryen `main` changed the teaching-important `directize` contract since the 2026-04-22 source capture?

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`

## Primary source URLs checked

### Official Binaryen current `main`

- `Directize.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Directize.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `call-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/call-utils.h>
- `table-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.h>
- `table-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.cpp>
- `type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Official Binaryen current `main` tests

- `directize_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize_all-features.wast>
- `directize-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-gc.wast>
- `directize-wasm64.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-wasm64.wast>

### Baseline tag retained for comparison

- The existing baseline remains the official Binaryen `version_129` source manifest captured in `docs/wiki/raw/binaryen/2026-04-22-directize-primary-sources.md`.
- Representative tagged URLs remain:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>

## Recheck result

No teaching-relevant current-`main` drift was found for the existing dossier.
The current `main` surfaces checked on 2026-04-25 still support the same durable contract taught from `version_129`:

- `directize` remains a public pass built around `Directize.cpp`, not a mode hidden inside another optimizer.
- The pass still reads `directize-initial-contents-immutable` as a pass argument before computing table facts.
- Whole-module `TableUtils::computeTableInfo(...)` still gates all entry-level call rewrites.
- The pass still fast-exits when no table can optimize by entry.
- The function walker still targets `CallIndirect` nodes, covering tail-call form through the existing indirect-call representation rather than adding a generic `call_ref` path.
- Constant targets still classify into the same three practical outcomes: known direct callee, known trap, or unknown.
- Trap outcomes still preserve child side effects before replacing the call site with `unreachable`.
- The nonconstant rewrite surface remains the narrow `select` helper in `call-utils.h`: both arms must be known-or-trap; an unknown arm is still a bailout rather than a partial directization.
- The table analysis still treats imports, exports, and runtime writers as mutation barriers, with destination `table.copy` remaining a source-backed barrier even though the directize lit coverage is stronger for `table.set`, `table.fill`, and `table.init`.
- The dedicated test files still cover the same teachable families: all-features table/direct/trap/select/mutation cases, GC subtype compatibility and result refinement, and wasm64 full-width index handling.

## Explicit non-changes to preserve in the living pages

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- generic `call_ref` directization in this pass;
- arbitrary symbolic target solving;
- partial lowering of a `select` with one known arm and one unknown arm;
- treating imported/exported tables as safe in ordinary mode;
- using `directize-initial-contents-immutable` as a substitute for flat-table construction;
- a nested cleanup rerun owned by `Directize.cpp` itself.

## Remaining caveats

- This was a focused source-surface recheck, not a full semantic diff across all Binaryen history after `version_129`.
- The source still makes destination `table.copy` a real mutation barrier. The living dossier should continue to distinguish that source-backed barrier from the stronger direct lit evidence for `table.set`, `table.fill`, and `table.init`.
- The old release-anchor facts in the 2026-04-22 manifest remain valid provenance for the tagged oracle; this file only refreshes current-main drift status.

## Consumability rule

Cite this file when refreshing `last_reviewed` or current-main freshness wording for `directize`.
Do not treat it as a replacement for the `version_129` primary-source manifest; it is a no-drift bridge layered on top of that manifest.
