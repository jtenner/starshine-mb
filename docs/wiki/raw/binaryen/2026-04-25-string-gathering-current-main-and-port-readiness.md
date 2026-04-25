# Binaryen `string-gathering` current-main and port-readiness source bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main and Starshine-port-readiness source bridge for the `docs/wiki/binaryen/passes/string-gathering/` dossier

## Scope

This file captures the focused primary online sources checked on 2026-04-25 while deepening the existing `string-gathering` dossier from a useful source dossier to a port-readiness guide.

The existing `version_129` source manifest in `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md` remains the tagged oracle. This bridge answers narrower maintenance questions:

- has current Binaryen `main` changed the teaching-important `string-gathering` contract since the 2026-04-23 source capture?
- which source-backed surfaces should a future Starshine port validate first?
- which local Starshine code surfaces are prerequisites rather than an implementation?

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/string-gathering/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md`
- `docs/wiki/binaryen/passes/string-gathering/wat-shapes.md`
- `docs/wiki/binaryen/passes/string-gathering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md`

## Primary source URLs checked

### Official Binaryen current `main`

- `StringLowering.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `string-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/string-utils.h>
- `string-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/string-utils.cpp>
- `module-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `wasm-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-traversal.h>

### Official Binaryen current `main` tests

- `string-gathering.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-gathering.wast>
- Neighboring string/global interaction test retained as context:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>

### Baseline tag retained for comparison

- Existing baseline manifest: `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md`
- Representative tagged URLs remain:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>

## Recheck result

No teaching-relevant current-`main` drift was found for the existing dossier.

The current `main` surfaces checked on 2026-04-25 still support the same durable contract taught from `version_129`:

- `string-gathering` remains a real public pass whose implementation lives inside `StringLowering.cpp`, not a dedicated `StringGathering.cpp` file.
- The standalone `StringGathering` structure remains the first phase that full `StringLowering` builds on.
- The pass still scans exact `StringConst` expression slots and later rewrites those slots, rather than building a general string-use graph.
- The pass still combines parallel defined-function scanning with a separate module-code walk.
- Reusable canonical globals remain strict: defined, immutable, exact non-null string type, and direct `string.const` initializer.
- First reusable global in module order remains the canonical representative for a literal.
- Fresh defining globals still use the shared string-global naming helpers.
- The pass still performs only a validity-first global reorder so defining string globals can precede rewritten users; final global layout remains the job of `reorder-globals`.
- The dedicated `string-gathering.wast` test still directly covers repeated literals, reusable immutable globals, non-reuse for nullable/mutable globals, first-match behavior, nested global initializer rewrites, and validity repair.

## Explicit non-changes to preserve in the living pages

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- full `string-lowering` as part of the standalone `string-gathering` pass;
- deletion of duplicate string globals as a root-removal pass;
- final global-cost ordering inside `string-gathering`;
- rewriting arbitrary `global.get` users;
- reusing mutable, imported, nullable, or nested-initializer globals as canonical defining globals;
- a dedicated refinalization or nested cleanup rerun owned by `StringGathering`;
- a local Starshine implementation in this repository.

## Starshine port-readiness findings from local source review

The local review did not change implementation status: Starshine still has no `src/passes/string_gathering.mbt` owner file and still does not list `string-gathering` in `src/passes/optimize.mbt`'s boundary-only or removed registry arrays.

It did confirm the useful prerequisite map:

- `src/passes/optimize.mbt:127-151` is the current registry gap: other boundary-only and removed pass names are tracked there, but `string-gathering` is absent.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:34-35` still records the late tail as `... remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`.
- `agent-todo.md:563-577` still tracks the `SG` backlog slice around string collection/canonicalization and feature-gated artifact parity.
- `src/binary/encode.mbt:72-103` and `src/binary/encode.mbt:1578-1645` preserve deterministic string literal identity for binary encoding.
- `src/binary/decode.mbt:148-171` and `src/binary/decode.mbt:3078-3082` preserve string literal identity while decoding `string.const`.
- `src/wast/lower_to_lib.mbt:2389` and `src/wast/lower_to_lib.mbt:7238-7262` keep WAT `string.const` literals in the lib IR and test that the lowered fixture validates.
- `src/ir/hot_builders.mbt:285-293`, `src/ir/hot_lift.mbt:1291-1294`, and `src/ir/hot_lower.mbt:196-197` preserve string constants through HOT construction, lifting, and lowering.

Those local surfaces are prerequisites and validation anchors, not evidence that the `string-gathering` transform has landed.

## Remaining caveats

- This was a focused source-surface recheck, not a semantic diff across every Binaryen commit after `version_129`.
- The existing `version_129` manifest remains the tagged source oracle; this file is a current-main no-drift and port-readiness bridge layered on top of it.
- The Starshine registry gap is documentation-backed technical debt. This source capture records it but does not implement the pass or change registry behavior.

## Consumability rule

Cite this file when refreshing `last_reviewed`, current-main freshness wording, exact local code-map anchors, or port-readiness guidance for `string-gathering`.
Do not treat it as a replacement for the `version_129` primary-source manifest; use both together.
