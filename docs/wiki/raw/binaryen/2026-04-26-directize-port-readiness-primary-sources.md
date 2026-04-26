# Binaryen `directize` port-readiness primary-source bridge

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source bridge for the `docs/wiki/binaryen/passes/directize/` dossier

## Scope

This file captures a focused source reread for the Starshine `directize` port-readiness pass-wiki refresh. It does not replace the tagged oracle manifest in [`2026-04-22-directize-primary-sources.md`](./2026-04-22-directize-primary-sources.md) or the current-main no-drift bridge in [`2026-04-25-directize-current-main-recheck.md`](./2026-04-25-directize-current-main-recheck.md).

The narrower question for this run was:

- what first Starshine implementation slice can be derived directly from Binaryen's current source boundaries, and
- which local Starshine code surfaces already represent the parser / IR / binary / validator / HOT primitives needed by that slice?

## Primary online sources checked

Official Binaryen repository sources:

- `src/passes/Directize.cpp`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Directize.cpp>
- `src/passes/call-utils.h`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/call-utils.h>
- `src/ir/table-utils.h`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.h>
- `src/ir/table-utils.cpp`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/table-utils.cpp>
- `src/ir/type-updating.h`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- `src/passes/pass.cpp`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/passes.h`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>

Official Binaryen lit tests:

- `test/lit/passes/directize_all-features.wast`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize_all-features.wast>
- `test/lit/passes/directize-gc.wast`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-gc.wast>
- `test/lit/passes/directize-wasm64.wast`
  - tagged oracle: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
  - current main: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/directize-wasm64.wast>

## Source-backed port-readiness findings

### 1. The first Starshine slice should be table-info first, not call rewrite first

`Directize.cpp` computes module-wide `TableUtils::computeTableInfo(...)` before walking functions and returns early when no table can optimize by entry. That makes a faithful local port start with table/import/export/element/mutation facts even though the visible user-facing win is a `call_indirect` rewrite.

For Starshine, that implies the first red tests should cover module facts and no-op behavior before any direct-call replacement is accepted as complete.

### 2. The target classifier is the core seam

Binaryen's durable target answers are still:

- `Known` function target,
- `Trap`, and
- `Unknown`.

A Starshine port should name this seam explicitly. It is the point where flat-table knowledge, constant target extraction, function-type compatibility, hole-vs-beyond-prefix behavior, and the ordinary-vs-immutable-initial-contents mode meet.

### 3. The first rewrite slice can ignore broad symbolic solving

The only nonconstant helper surface still worth modeling in the first complete port is the narrow `select` lowering owned by `call-utils.h`. The sources do not support teaching generic symbolic target solving, partial one-known-arm `select` lowering, or `call_ref` directization as part of this pass.

### 4. Trap replacement requires side-effect preservation and type repair

Known-trap replacement is not “delete the call.” Binaryen preserves child side effects before emitting `unreachable`, and post-edit refinalization is part of the pass contract because direct callees or traps can refine visible expression types.

The local validation plan must therefore include side-effectful operands and post-rewrite validation, not only text diffs showing `call_indirect` changed to `call`.

### 5. Current-main drift did not change the port plan

This run reused the current-main surfaces checked by the 2026-04-25 no-drift bridge and rechecked the same official source families for port-planning consequences. No new teaching-relevant drift was found. The durable port plan should still target the `version_129` contract, with current `main` treated as a freshness check rather than a different oracle.

## Local Starshine surfaces checked

These are not a local implementation yet; they are the exact in-repo primitives a future implementation has to build on or repair.

- Registry and request guard:
  - `src/passes/optimize.mbt:127-136`
  - `src/passes/optimize.mbt:452-470`
- WAT parser / lowering for indirect calls and table operations:
  - `src/wast/parser.mbt:1874-1885`
  - `src/wast/lower_to_lib.mbt:1919-1958`
  - `src/wast/lower_to_lib.mbt:2171-2252`
- Core IR representation:
  - `src/lib/types.mbt:198-212`
  - `src/lib/types.mbt:221`
  - `src/lib/types.mbt:526-531`
  - `src/lib/types.mbt:780-785`
- Binary codec:
  - `src/binary/decode.mbt:2544-2564`
  - `src/binary/decode.mbt:3264-3269`
  - `src/binary/encode.mbt:2008-2028`
- Text rendering and HOT roundtrip support:
  - `src/lib/show.mbt:866-882`
  - `src/ir/hot_side_tables.mbt:249-254`
  - `src/ir/hot_lower.mbt:993-1018`
- Validation:
  - `src/validate/typecheck.mbt:907-944`
  - `src/validate/typecheck.mbt:3216-3219`
  - `src/validate/typecheck_negative_tests.mbt:332-391`
- Backlog and scheduler context:
  - `agent-todo.md:689-701`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:34-35`

## Explicit open design questions for Starshine

- Should the first implementation live as a module pass over `@lib.Module`, or as a module preanalysis feeding a HOT rewrite? The Binaryen contract strongly favors module analysis first, but Starshine already has useful HOT side-table support for indirect-call signatures.
- Where should an eventual `directize-initial-contents-immutable` pass argument live in Starshine's current pass-option model? The existing boundary-only name has no option surface yet.
- How should Starshine model the known-prefix versus beyond-known-prefix distinction for table contents when element segments are present but table growth or mutation remains possible?
- What is the minimal type-repair mechanism after direct-call / trap / select rewrites: existing validation plus local reconstruction, a pass-local helper, or a reusable module rewrite repair layer shared with other boundary passes?

## Consumability rule

Use this file for the 2026-04-26 Starshine port-readiness and validation ladder. Continue to cite the older tagged and current-main source manifests for the full upstream strategy and no-drift evidence.
