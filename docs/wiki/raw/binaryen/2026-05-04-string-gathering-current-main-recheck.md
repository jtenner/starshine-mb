# Binaryen `string-gathering` current-main recheck and Starshine maintenance bridge

_Capture date:_ 2026-05-04  
_Status:_ immutable current-main and local code-anchor recheck for the `docs/wiki/binaryen/passes/string-gathering/` dossier

## Scope

This file captures the focused primary online sources rechecked on 2026-05-04 while refreshing the `string-gathering` dossier.

The existing `version_129` source manifest in `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md` remains the tagged oracle. This bridge answers maintenance questions:

- has current Binaryen `main` changed the teaching-important `string-gathering` contract since the earlier source capture?
- which exact local Starshine code anchors should the living pages point at now?
- which local surfaces are prerequisites and validation anchors rather than a separate implementation story?

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
- `propagate-globals-globally.wast` for the neighboring string/global interaction family
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>

### Baseline tag retained for comparison

- Existing baseline manifest: `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md`
- Representative tagged URLs remain:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>

### Local code anchors rechecked

- `src/passes/string_gathering.mbt:2-3`
  - pass summary and public pass spelling
- `src/passes/string_gathering.mbt:160-166`
  - collection order comment for function bodies before module-level expressions
- `src/passes/string_gathering.mbt:573-601`
  - public module-pass entry point and rewrite assembly
- `src/passes/string_gathering_test.mbt:37-43`
  - registry lookup test
- `src/passes/string_gathering_test.mbt:48-57`
  - no-op test
- `src/passes/string_gathering_test.mbt:61-77`
  - function-body hoist test
- `src/passes/string_gathering_test.mbt:80-105`
  - dedupe and first-use order test
- `src/passes/string_gathering_test.mbt:109-138`
  - imports/global-remap test
- `src/passes/string_gathering_test.mbt:140-161`
  - export remap test
- `src/passes/string_gathering_test.mbt:164-194`
  - function-before-global scan-order test
- `src/passes/string_gathering_test.mbt:196-218`
  - nested-structured-body rewrite test
- `src/passes/string_gathering_test.mbt:220-266`
  - exported defined-global and structured-name remap test
- `src/passes/string_gathering_test.mbt:268-273`
  - stale raw-name payload clearing test
- `src/passes/optimize.mbt:259`
  - active module-pass registry entry
- `src/passes/pass_manager.mbt:8709`
  - module-pass dispatcher arm
- `src/cmd/cmd_wbtest.mbt:4170-4201`
  - CLI acceptance test for explicit `--string-gathering`

## Recheck result

No teaching-relevant current-main drift was found for the existing dossier.

The current `main` surfaces checked on 2026-05-04 still support the same durable contract taught from `version_129`:

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

## Starshine maintenance findings from local source review

The local review did not change implementation status: Starshine still has an active direct `string-gathering` module pass and still keeps the pass separate from `reorder-globals`.

It did confirm the useful anchor refresh:

- `src/passes/string_gathering.mbt:573-601` is the active module-pass entry point and rewrite assembly.
- `src/passes/optimize.mbt:259` is the active registry entry.
- `src/passes/pass_manager.mbt:8709` is the dispatcher arm.
- `src/cmd/cmd_wbtest.mbt:4170-4201` proves explicit CLI acceptance.
- `src/passes/string_gathering_test.mbt:37-273` continues to pin the direct pass behavior and safety boundaries.

Those local surfaces are implementation anchors and validation anchors, not evidence that the upstream `string-gathering` contract has changed.

## Remaining caveats

- This was a focused source-surface recheck, not a semantic diff across every Binaryen commit after `version_129`.
- The existing `version_129` manifest remains the tagged source oracle; this file is a current-main no-drift and line-anchor bridge layered on top of it.
- The Starshine registry gap is no longer current for the direct pass, but this source capture remains useful as a maintenance reference for the exact code anchors and validation surfaces.

## Consumability rule

Cite this file when refreshing `last_reviewed`, current-main freshness wording, exact local code-map anchors, or port-readiness guidance for `string-gathering`.
Do not treat it as a replacement for the `version_129` primary-source manifest; use both together.
