# Binaryen `version_130` `mark-js-called` / `remove-exports` Source Read

Capture date: 2026-06-04

Purpose: expand the release-horizon note that only named `MarkJSCalled` and `RemoveExports` in the `v130` changelog into a source-backed tracker entry. This is not a full port plan; it records enough owner, registration, test, and local Starshine status evidence for the wiki to stop treating the names as unresolved release-note trivia.

## Primary URLs Checked

- Official Binaryen `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Official Binaryen `version_130` changelog source: <https://github.com/WebAssembly/binaryen/blob/version_130/CHANGELOG.md>
- Official Binaryen `version_130` pass registration source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `MarkJSCalled` owner source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MarkJSCalled.cpp>
- `RemoveExports` owner source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveExports.cpp>
- `mark-js-called` lit fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/mark-js-called.wast>
- `remove-exports` lit fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-exports.wast>
- PR 8733 (`MarkJSCalled`): <https://github.com/WebAssembly/binaryen/pull/8733>
- PR 8670 (`RemoveExports`): <https://github.com/WebAssembly/binaryen/pull/8670>

## Durable Findings

- `version_130` is the public release horizon for both names. The official changelog lists `MarkJSCalled` and `RemoveExports` in the `v130` section, and the release-horizon page already records that global fact.
- `MarkJSCalled` is a real upstream pass with its own owner file and lit fixture, not just an annotation-name mention. Its contract belongs near the `FuncAnnotationSec` / `@binaryen.js.called` surface and the `strip-toolchain-annotations` lifecycle notes. Do not treat it as a generic JS-interface legalization pass.
- `RemoveExports` is a real upstream pass with its own owner file and lit fixture. It is an ABI-visible module-export rewrite surface, so future Starshine work must route it through export-section mutation, name/metadata cleanup, and host-contract warnings rather than ordinary internal liveness pruning.
- Starshine has no local pass spelling for either name on 2026-06-04. Focused repo searches for `mark-js-called`, `MarkJSCalled`, `remove-exports`, and `RemoveExports` in `src/` found no pass implementation or registry entry.
- Starshine already has relevant prerequisites:
  - `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec` in `src/lib/types.mbt`.
  - WAST parse/lower coverage for `(@binaryen.js.called)` on function imports and definitions in `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast_tests.mbt`.
  - `Export` / `ExportSec` and `Module.export_sec` in `src/lib/types.mbt` plus the ordinary binary/WAST export surfaces documented elsewhere in the wiki.

## Wiki Consequence

Add upstream-only landing pages and tracker rows for `mark-js-called` and `remove-exports`. Keep them outside the no-DWARF / saved-`-O4z` parity queue until an implementation task proves they matter to Starshine's default optimization presets. The landing pages should cite this source read plus the official upstream URLs, and they should keep the current local status honest: both names are unknown locally, not boundary-only or removed registry entries.
