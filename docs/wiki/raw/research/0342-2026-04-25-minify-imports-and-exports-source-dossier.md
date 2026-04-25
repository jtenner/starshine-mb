# `minify-imports-and-exports` primary sources and Starshine follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into living wiki pages; superseded by `0343-2026-04-25-minify-imports-source-correction.md` for the `WasmBinaryBuilder::getSymbolMap(...)` attribution

## Question

The pass wiki's main queues are dossier-covered, but Binaryen still exposes public whole-module passes outside Starshine's registry.
This run picked `minify-imports-and-exports` because it is a real Binaryen transformation whose name sounds harmless yet changes externally visible import/export strings.
The goal was to answer:

- what does Binaryen's `minify-imports-and-exports` actually rename?
- how does the sibling `minify-imports-and-exports-and-modules` differ?
- what module shapes should future Starshine readers test?
- what exact local code locations explain Starshine's current non-implementation status?

## Sources checked

Primary online sources:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `MinifyImportsAndExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `wasm-binary.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.h>
- Binaryen `minify-imports-and-exports-and-modules.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
- Binaryen `minify-imports-and-exports-and-modules.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
- Current-main spot checks for `MinifyImportsAndExports.cpp` and `pass.cpp` on 2026-04-25.

Local repository surfaces:

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/binary/decode.mbt`
- `src/binary/encode.mbt`
- `src/wast/lower_to_lib.mbt`

## Findings

- Binaryen `version_129` exposes `minify-imports-and-exports` as a public pass and the sibling `minify-imports-and-exports-and-modules` as a second public pass.
- The implementation owner is `MinifyImportsAndExports.cpp` for both names. The sibling behavior is selected by the `minifyModules` constructor flag.
- Superseded on 2026-04-25 by [`0343-2026-04-25-minify-imports-source-correction.md`](0343-2026-04-25-minify-imports-source-correction.md): the reviewed `version_129` owner uses `Names::MinifiedNameGenerator` plus used-name avoidance in `MinifyImportsAndExports.cpp`, not `WasmBinaryBuilder::getSymbolMap(...)`, to produce the import/export/module maps.
- The plain pass rewrites import base names and export names. The sibling also rewrites import module names.
- This is not a body rewrite: function instructions, local indices, function indices, type indices, and export target indices are not supposed to change.
- The pass is externally visible. Linking by exact `(module, base)` import names and host/export lookup by exact export strings must use the renamed surface.
- The official lit surface directly proves the module-name sibling; the plain pass's no-module-name contract is source-backed through the flag and registry help text.
- Starshine currently treats `minify-imports-and-exports` and the sibling as unknown pass names. They are absent from active, boundary-only, and removed registries, absent from the module-pass dispatcher, and have no owner file or backlog slice.
- Starshine's `Import`, `Export`, `ImportSec`, `ExportSec`, binary decoder/encoder, and WAT lowering surfaces already preserve enough names for a future module pass to mutate them, but no Binaryen-compatible name-map generation exists today.

## Wiki changes made from these findings

Created a new living dossier:

- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/starshine-strategy.md`

Created a raw source manifest:

- `docs/wiki/raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md`

Updated catalogs and chronology:

- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up questions

- Before implementation, re-read `Names::MinifiedNameGenerator` and the used-name collection rules in the exact upstream revision targeted for parity and write tests for short-name ordering, reserved/invalid-name avoidance, and collision behavior.
- Decide whether Starshine should track the pass as boundary-only, removed, active, or still unknown. The current dossier intentionally records unknown-pass status rather than silently reserving the names.
- If implemented, add host-facing compatibility documentation: minifying external names is a product/packaging choice, not a semantics-preserving change for hosts that expect stable names.
