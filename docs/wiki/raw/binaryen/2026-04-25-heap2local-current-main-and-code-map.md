# Binaryen `heap2local` current-main source and code-map capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest and Starshine code-map refresh for the `docs/wiki/binaryen/passes/heap2local/` dossier

## Scope

This file extends the earlier 2026-04-22 source manifest for `heap2local` with a focused current-`main` recheck and an exact current Starshine owner/test map.

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/heap2local/index.md`
- `docs/wiki/binaryen/passes/heap2local/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap2local/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap2local/validation-fixups-and-special-cases.md`
- `docs/wiki/binaryen/passes/heap2local/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap2local/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/heap2local/parity.md`

## Provenance

### Prior tagged oracle retained

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Prior manifest: `docs/wiki/raw/binaryen/2026-04-22-heap2local-primary-sources.md`
  - The earlier manifest records the release page observed on 2026-04-22 with publish date **2026-04-01**.

### Official current-main source files consulted

- `Heap2Local.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/src/passes/Heap2Local.cpp>
  - Key reviewed locations in current `main`:
    - allocation collection and per-function helper state around the file's `Heap2Local` driver,
    - `EscapeAnalyzer` declaration and value-flow comments around `Heap2Local.cpp` lines 1158-1190 in GitHub's source view,
    - parent interaction classification, array operation barriers, branch-flow mixing, and exclusivity via `getsAreExclusiveToSets()` around lines 1340-1510,
    - `Struct2Local` declaration, field/descriptor local allocation, null-placeholder strategy, type-flow adjustment, and `ReFinalize` hook around lines 1510-1600,
    - struct allocation replacement, scratch-temp initializer ordering, descriptor null-trap preservation, struct get/set/atomic/RMW/cmpxchg, direct `ref.*`, and descriptor rewrite visitors in the rest of `Struct2Local`,
    - array-to-struct lowering and final driver code near the end of the file.
- `heap2local.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/test/lit/passes/heap2local.wast>
  - Key reviewed test families: direct structs, local-copy flow, branch/block flow, arrays, packed fields, atomics, RMW/cmpxchg, descriptor/cast edges where present, and bailout cases.
- `pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed for public registration and scheduler placement. Current `main` still registers `heap2local` with the description `replace GC allocations with locals`, and the no-DWARF optimization builder still gates the pass on `optimizeLevel > 1` plus GC feature availability.
- `pass.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - Reviewed for the generic `requiresNonNullableLocalFixups()` default that matters after `heap2local` rewrites reference locals.
- `type-updating.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - Reviewed as the generic nondefaultable-local repair helper surface.
- Helper headers retained from the 2026-04-22 source manifest:
  - `src/ir/local-graph.h`
  - `src/ir/parents.h`
  - `src/ir/branch-utils.h`
  - `src/ir/eh-utils.h`
  - `src/ir/bits.h`
  - `src/ir/properties.h`
  - `src/wasm-builder.h`

## Durable observations from current-main sources

- The current upstream source still teaches the same high-level contract as the earlier `version_129` dossier: nonescaping-plus-exclusive GC scalarization, array-to-synthetic-struct lowering, struct field/descriptor locals, direct reference-op folding, and mandatory validation repair.
- `pass.cpp` still exposes the public pass as `heap2local` and keeps it in the GC-only mid-function optimization cluster before `optimize-casts` and local-subtyping/coalescing/CSE neighbors.
- The current source still treats nonescape and exclusivity as separate gates. A value that never leaves the function can still be rejected when a relevant local get may read from a competing set.
- The current source still makes arrays a first-stage conversion to struct-like scalarization rather than a separate direct element-localization engine.
- The current source still requires refinalization and generic nondefaultable-local repair as part of the real pass boundary.
- No new teaching-relevant drift beyond the already-recorded 2026-04-22 caveat was found while preparing this refresh. Keep the earlier caveat: current `main` has tighter array/cmpxchg/unreachable-`ref.test` details than the tagged release, while the dedicated lit file still has no equally visible new teaching family beyond the typo cleanup noted earlier.

## Starshine source surfaces rechecked

Current exact local code locations for the active Starshine pass:

- `src/passes/heap2local.mbt:2-16`
  - descriptor and required HOT analysis (`use_def`) plus invalidation set.
- `src/passes/heap2local.mbt:18-20`
  - public summary string.
- `src/passes/optimize.mbt:201-205`
  - active hot-pass registry entry.
- `src/passes/optimize.mbt:253-257` and `src/passes/optimize.mbt:392-396`
  - `optimize` preset placements.
- `src/passes/optimize.mbt:265-269` and `src/passes/optimize.mbt:405-409`
  - `shrink` preset placements.
- `src/passes/pass_manager.mbt:8698`
  - hot-pass dispatcher case.
- `src/passes/heap2local.mbt:84-145`
  - supported struct/default/descriptor-bearing allocation recognition.
- `src/passes/heap2local.mbt:468-558`
  - struct candidate matcher: non-parameter one-write owner, direct `local.set` / `local.tee`, supported owner, compatible owner local, supported use-family collection, and nonempty use set.
- `src/passes/heap2local.mbt:562-658`
  - supported array initializer and constant-size `< 20` gate for `array.new_default`, `array.new`, and `array.new_fixed`.
- `src/passes/heap2local.mbt:660-725`
  - direct array-use matcher for constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`.
- `src/passes/heap2local.mbt:695-748`
  - array candidate matcher: non-parameter one-write owner, supported initializer, compatible owner local, and supported element uses.
- `src/passes/heap2local.mbt:1056-1159`
  - direct ref-op folds for fresh-struct `ref.eq` against null, descriptor-bearing `ref.get_desc`, and direct array `ref.test`.
- `src/passes/heap2local.mbt:1164-1216`
  - direct array candidate rewrite into element locals.
- `src/passes/heap2local.mbt:1219-1347`
  - struct candidate rewrite into field locals, with tee/block wrapper repair and detached-node cleanup bookkeeping.
- `src/passes/heap2local.mbt:1349-1376`
  - detached live-node deletion.
- `src/passes/heap2local.mbt:1379-1442`
  - public run function: module context check, use-def request, candidate scan, candidate application, direct-ref fold pass, cleanup, mutation marking.
- `src/passes/heap2local_test.mbt:86-453`
  - focused local positive and bailout tests.
- `src/passes/heap2local_primary_test.mbt:158-568`
  - broader primary suite covering Binaryen-aligned positives and current explicit bailout families.
- `src/passes/optimize_test.mbt:398-403`
  - preset neighbor lock for the mid-function GC slot.
- `src/passes/optimize_test.mbt:435-446`
  - trace/order evidence that `simplify-locals` consumes `heap2local` output in the modeled local pipeline.
- `src/passes/registry_test.mbt:2-31`, `src/passes/registry_test.mbt:102-133`, and `src/passes/registry_test.mbt:146-160`
  - active hot-pass classification, descriptor requirements, and preset roster evidence.
- `agent-todo.md:336-347`
  - active H2L slice status, parity claim, and remaining non-nullable-local/refinalization plus missing-neighbor follow-up.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
