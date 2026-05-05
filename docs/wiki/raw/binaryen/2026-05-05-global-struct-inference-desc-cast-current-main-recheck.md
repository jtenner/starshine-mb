# Binaryen `global-struct-inference-desc-cast` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/` dossier

## Scope

This bridge refreshes the existing `global-struct-inference-desc-cast` dossier against current Binaryen `main` on the same owner, scheduler, helper, and dedicated-fixture surfaces used by the earlier 2026-04-24 source correction.
It is a no-drift recheck layered on top of the corrected target-descriptor-singleton reading.

## Official primary sources rechecked

- `GlobalStructInference.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalStructInference.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `gsi-to-desc-cast.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-to-desc-cast.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi-to-desc-cast.wast>
- `gsi-desc.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-desc.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi-desc.wast>
- `gsi.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi.wast>

## Source-location notes

The checked current-main surfaces still show the same teaching-important structure as the corrected `version_129` contract:

- `GlobalStructInference.cpp` still isolates the desc-cast-specific rewrite in `visitRefCast(RefCast*)`, with the same gates for desc-cast mode, non-`unreachable` result type, descriptor existence, exact-or-no-strict-subtypes legality, and exactly-one descriptor global before emitting `ref.cast_desc_eq` (`GlobalStructInference.cpp` lines 2553-2636).
- `pass.cpp` still registers `gsi-desc-cast` as a real public pass sibling of `gsi`, with the same public summary string (`pass.cpp` lines 2567-2577).
- `gsi-to-desc-cast.wast` still proves the sibling delta directly: ordinary `--gsi` keeps the cast, `--gsi-desc-cast` can emit `ref.cast_desc_eq`, exact casts can optimize where inexact ones may not, zero/many descriptor-global cases still bail out, and nullable plus unreachable cases still behave as documented (`gsi-to-desc-cast.wast` lines 1112-1193 and 1345-1650).
- `gsi-desc.wast` still covers the shared descriptor-read machinery, including `ref.get_desc` rewrites and nested `reorder-globals-always` repair when descriptor globals are un-nested (`gsi-desc.wast` lines 830-905).

## Recheck result

No teaching-relevant current-`main` drift was found.
The current-main surfaces checked on 2026-05-05 still support the same durable contract taught from the corrected 2026-04-24 dossier:

- `gsi-desc-cast` remains a sibling of plain `gsi`, not a separate analysis family.
- The desc-cast rewrite still keys off the target descriptor singleton, not the cast input's provenance.
- The strict-subtype legality check and one-global descriptor gate still remain explicit.
- The shared descriptor-read machinery still underpins the sibling's un-nesting story.

## Explicit non-changes

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- a pass-local cast-input-origin oracle for desc-cast rewrites;
- a multi-global select fallback for `ref.cast_desc_eq`;
- a desc-cast rewrite when the target has no descriptor type;
- a scheduler move that would make `gsi-desc-cast` part of the repo's current open-world no-DWARF path.

## Uncertainties to preserve

- This is a focused source-surface recheck, not a full semantic diff across all Binaryen history after `version_129`.
- The helper-owned type and descriptor rewrite still depends on broad GC/type infrastructure, so the current-main recheck does not replace the older source-correction or port-readiness notes.
- Starshine still lacks a local `global-struct-inference-desc-cast` owner file; the exact local status remains boundary-only registry tracking plus request rejection.
