# `minify-imports` source correction and Starshine follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into living wiki pages

## Question

The previous `minify-imports-and-exports` dossier covered the ABI-visible import/export name-minification family, but a follow-up source read found two gaps:

- Binaryen also exposes a separate public `minify-imports` pass.
- The existing dossier incorrectly taught the mutating `minify-imports-and-exports` family as `WasmBinaryBuilder::getSymbolMap(...)`-driven. In `version_129`, the owner file itself uses `Names::MinifiedNameGenerator` plus used-name avoidance.

This run answered:

- what does `minify-imports` do and not do?
- how is it different from `minify-imports-and-exports` and `minify-imports-and-exports-and-modules`?
- what exact local Starshine surfaces explain the current unknown-pass status?
- which existing wiki claims needed stale-reference cleanup?

## Sources checked

Primary online sources:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `MinifyImports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImports.cpp>
- Binaryen `MinifyImportsAndExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `wasm-module-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-module-utils.h>
- Binaryen `support/name.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/name.h>
- Binaryen `minify-imports-and-exports-and-modules.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
- Binaryen `minify-imports-and-exports-and-modules.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
- Current-main spot checks for `MinifyImports.cpp`, `MinifyImportsAndExports.cpp`, and `pass.cpp` on 2026-04-25.

Local repository surfaces:

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/binary/decode.mbt`
- `src/binary/encode.mbt`
- `src/wast/lower_to_lib.mbt`

## Findings

- `minify-imports` is a separate public Binaryen pass, not an alias for `minify-imports-and-exports`.
- `minify-imports` reports `modifiesBinaryenIR() == false` and emits a mapping, shaped as `old:new`, to stdout.
- `minify-imports` walks only imported functions via `ModuleUtils::iterImportedFunctions(...)`; it does not rename import declarations in memory and does not include imported globals, memories, tables, tags, export names, or import module names.
- `minify-imports-and-exports` remains the mutating pass for import base names plus export names.
- `minify-imports-and-exports-and-modules` remains the mutating sibling that also rewrites import module names.
- The mutating family uses `Names::MinifiedNameGenerator` directly in `MinifyImportsAndExports.cpp`, together with used-name avoidance. The earlier `WasmBinaryBuilder::getSymbolMap(...)` attribution is stale/incorrect for Binaryen `version_129`.
- The official lit pair directly exercises `minify-imports-and-exports-and-modules`. This run did not find a dedicated `minify-imports` lit pair; the plain map-emitting pass is source-confirmed by owner, registry, and factory sources.
- Starshine currently treats all three minify pass names as unknown: no active, boundary-only, or removed registry entry; no module dispatcher case; no owner file; no backlog slice.

## Wiki changes made from these findings

Created a new living dossier:

- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`

Created a raw source-correction manifest:

- `docs/wiki/raw/binaryen/2026-04-25-minify-imports-family-source-correction.md`

Refreshed existing pages:

- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up questions

- If Starshine ever implements `minify-imports`, should it print to stdout like Binaryen or expose the map through a structured API in addition to CLI output?
- Should the local registry reserve all three names as boundary-only even before implementation, or continue treating them as unknown until a concrete port is planned?
- If the mutating family is ported later, add tests that keep `minify-imports` map emission separate from actual import/export declaration mutation.
