# Binaryen `mark-js-called` / `remove-exports` Behavior Refresh

Capture date: 2026-06-04

Purpose: deepen the earlier `version_130` source read from owner/test existence into the actual behavior contracts that Starshine wiki pages should teach. This refresh checked the released `version_130` sources plus current `main` copies and found no material drift for the two small pass bodies or their dedicated lit fixtures.

## Primary URLs Checked

- Binaryen `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen `version_130` changelog: <https://github.com/WebAssembly/binaryen/blob/version_130/CHANGELOG.md>
- `version_130` `MarkJSCalled.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MarkJSCalled.cpp>
- current `main` `MarkJSCalled.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MarkJSCalled.cpp>
- `version_130` `mark-js-called.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/mark-js-called.wast>
- current `main` `mark-js-called.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/mark-js-called.wast>
- `version_130` `RemoveExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveExports.cpp>
- current `main` `RemoveExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveExports.cpp>
- `version_130` `remove-exports.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-exports.wast>
- current `main` `remove-exports.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-exports.wast>
- current `main` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## Durable Findings

### `mark-js-called`

- The pass is an annotation synthesis pass for Binaryen's `@binaryen.js.called` function annotation. It does not rewrite call sites, exports, JS ABI wrappers, or function bodies directly.
- The owner file first scans the module for any intrinsic `configureAll` function. If none exists, the pass returns early.
- If a configureAll intrinsic exists, Binaryen runs a parallel function analysis over defined, non-imported functions. It scans call expressions and, when a call is recognized as `configureAll`, extracts the referred function names from the intrinsic payload and records those functions.
- After the analysis, it sets the `funcAnnotations.jsCalled` bit on each referred function. Existing `@binaryen.js.called` annotations remain unchanged. Functions not present in the configureAll payload are not newly marked.
- The owner-file comment records an important scheduling nuance: configureAll calls in the start function are already handled by Binaryen intrinsic processing, so this pass is for other configureAll uses such as exported entry points. The dedicated lit fixture still includes a start-function configureAll case and demonstrates the marking outcome.
- Current `main` keeps the same small behavior as the `version_130` release copy as of this capture.

### `remove-exports`

- The pass is parameterized: `wasm-opt --remove-exports=WILDCARD` reads the argument string, trims it, optionally expands a response file, and splits patterns by newline or comma.
- Binaryen applies its bracketing-operator expansion to the pattern list and then wildcard-matches each export name. Matching export names are collected first, then removed from the module export list.
- The pass removes export entries only. It does not delete the exported function/table/memory/global/tag definition, does not rewrite body references, and does not remap index spaces by itself.
- The dedicated lit fixture proves two key surfaces: function exports whose names match `__*` vanish while the functions remain present, and memory/table exports with the matching prefix also vanish while the memory/table definitions remain present.
- Current `main` keeps the same small behavior as the `version_130` release copy as of this capture.

## Starshine Repository Evidence Checked

- Focused `src/` searches still found no local `mark-js-called` or `remove-exports` pass spelling, registry entry, or dispatcher case.
- Existing Starshine prerequisites for `mark-js-called` remain in place: `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec` in `src/lib/types.mbt`; WAST parsing/lowering/printing tests for `(@binaryen.js.called)` in `src/wast/parser.mbt`, `src/wast/module_wast_tests.mbt`, and `src/wast/lower_to_lib.mbt`; and existing annotation-remap helpers in function-index rewriting passes.
- Existing Starshine prerequisites for a future `remove-exports` slice remain in place: `Export`, `ExportSec`, and `Module.export_sec`; binary encode/decode for export sections; WAST inline and explicit export lowering; and multiple module passes that already repair export-section references when they remap or delete definitions.

## Wiki Consequence

The living pages should no longer describe these names only as newly visible v130 surfaces. The useful contract is now precise:

- `mark-js-called` is a configureAll-driven annotation marking pass. A Starshine port needs configureAll intrinsic recognition before it can be faithful; merely preserving existing `(@binaryen.js.called)` annotations is prerequisite metadata support, not the pass.
- `remove-exports` is a parameterized export-section filter. A Starshine port can start as an explicit-pass-only export-list mutation, but any preset use would be an ABI policy decision because removing exports changes the host-visible module boundary.
