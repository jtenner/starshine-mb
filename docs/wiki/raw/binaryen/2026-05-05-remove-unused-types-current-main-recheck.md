# Binaryen `remove-unused-types` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/remove-unused-types/` dossier

## Scope

This bridge refreshes the existing `remove-unused-types` dossier against current Binaryen `main` on the same owner, scheduler, helper, and dedicated-fixture surfaces used by the earlier 2026-04-26 port-readiness bridge.
It is a no-drift recheck layered on top of the corrected 2026-04-24 source reading.

## Official primary sources rechecked

- `RemoveUnusedTypes.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedTypes.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `type-updating.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- `module-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- `remove-unused-types.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-types.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

## Source-location notes

The checked current-main surfaces still show the same teaching-important structure as the corrected `version_129` contract:

- `RemoveUnusedTypes.cpp` still gates on GC, rejects explicit open-world use, and delegates to `GlobalTypeRewriter(*module).update()` (`RemoveUnusedTypes.cpp` lines 385-432).
- `pass.cpp` still registers `remove-unused-types` as `"remove unused private GC types"` and still schedules it only inside the closed-world GC/type cluster (`pass.cpp` lines 3026-3029 and 3656-3660).
- `type-updating.h` still carries the helper-owned rewrite engine with `typeInfo`, `publicGroups`, `update()`, `getPrivatePredecessors()`, `rebuildTypes(...)`, and the `TypeMapper` composition path (`type-updating.h` lines 2049-2067 and 2207-2246).
- `module-utils.h` still exposes `HeapTypeInfo { useCount, visibility }` and `collectHeapTypeInfo(...)` as the shared discovery layer (`module-utils.h` lines 2017-2029).
- The dedicated lit file still exercises the same compact families: unused private removal, used/private retention, old-rec-group reshaping, public-boundary anchoring, and closed-world/no-GC boundaries (`remove-unused-types.wast` lines 322-367).

## Recheck result

No teaching-relevant current-`main` drift was found.
The current-main surfaces checked on 2026-05-05 still support the same durable contract taught from the corrected 2026-04-24 dossier:

- `remove-unused-types` remains a small pass wrapper around helper-owned module type rewriting.
- Public rec-group shapes still anchor the external boundary.
- Private heap types still disappear only when unused by the surviving IR.
- Surviving private types still need dependency-ordered rebuilding before the module is remapped.
- The fixture surface still teaches the same delete/retain/rebuild boundary, and it still needs the helper headers to explain why the pass is larger than the wrapper file.

## Explicit non-changes

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- a new pass-local used-type scanner in `RemoveUnusedTypes.cpp`;
- a pass-local private builder or whole-old-rec-group preservation rule;
- an open-world-safe type deletion mode;
- a scheduler move that would make the pass part of the open-world no-DWARF route.

## Uncertainties to preserve

- This is a focused source-surface recheck, not a full semantic diff across all Binaryen history after `version_129`.
- The helper-owned type rewrite still depends on broad GC/type infrastructure, so the current-main recheck does not replace the older source-correction or port-readiness notes.
- Starshine still lacks a local `remove_unused_types` owner file; the exact local status remains boundary-only registry tracking plus request rejection.
