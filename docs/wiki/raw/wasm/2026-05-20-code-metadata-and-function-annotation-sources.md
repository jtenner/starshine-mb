# WebAssembly Code Metadata And Starshine Function Annotation Source Refresh

- Capture date: 2026-05-20
- Source family: WebAssembly custom/code metadata proposal surfaces plus Starshine repository evidence
- Primary sources:
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (current as checked on 2026-05-20)`: <https://webassembly.github.io/spec/core/appendix/custom>
  - WebAssembly Code Metadata specification overview, binary format, and text format (current as checked on 2026-05-20): <https://webassembly.github.io/spec/metadata/code/>, <https://webassembly.github.io/spec/metadata/code/binary.html>, and <https://webassembly.github.io/spec/metadata/code/text.html>
  - WebAssembly `branch-hinting` proposal overview, `proposals/branch-hinting/Overview.md` (current as checked on 2026-05-20): <https://github.com/WebAssembly/branch-hinting/blob/main/proposals/branch-hinting/Overview.md>
  - Binaryen `version_129` inline-hints tests and annotation sources already captured by [`../binaryen/2026-04-23-inlining-primary-sources.md`](../binaryen/2026-04-23-inlining-primary-sources.md) and [`../binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md`](../binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md).

## Durable takeaways

- The core custom-section appendix documents text-format custom-section annotations as a placement-aware way to describe custom section payloads. This is broader than Starshine's current `(@...)` function-annotation parser lane.
- The WebAssembly code-metadata proposal defines a typed metadata model for attaching metadata to code locations. Binary code metadata lives in custom sections named `metadata.code.T`, keyed by function index and instruction byte offset; text code metadata appears as `(@metadata.code.T ...)` immediately before the instruction it annotates.
- The widely referenced keys include inline hints such as `metadata.code.inline` and branch hints such as `metadata.code.branch_hint`; branch hints are the branch-hinting proposal's concrete motivating payload. The branch-hint format is attached only to `if` and `br_if` instructions and encodes likely/unlikely as a one-byte payload in the current spec/proposal text.
- Binaryen uses this annotation vocabulary in real WAT/lit surfaces: inline hints roundtrip as `@metadata.code.inline`, branch hints are visible in pass fixture shapes, and `strip-toolchain-annotations` deliberately removes Binaryen/toolchain annotation families while preserving `metadata.code.inline`.
- Starshine currently has a **function/import-only** WAST annotation surface: the lexer recognizes `(@...)`, the parser only attaches accumulated annotations to defined functions and function imports, and lowering stores them in `Module.func_annotation_sec` as `FuncAnnotationAssoc(FuncIdx, Array[FuncAnnotation])`.
- Starshine does **not** currently model Binaryen's full expression-level `codeAnnotations`: there is no binary encode/decode support for `FuncAnnotationSec`, no expression-annotation map, and no local `metadata.code.branch_hint` parser/lowerer surface beyond preserving the text name if it appears in a legal function/import annotation.
- Starshine's no-inline policy is intentionally local: `no-inline`, `no-full-inline`, and `no-partial-inline` add internal `starshine.no-full-inline` / `starshine.no-partial-inline` function annotations, while `metadata.code.inline` remains metadata and is not the direct inliner policy switch.

## Starshine code map

- [`src/wast/lexer.mbt`](../../../../src/wast/lexer.mbt) recognizes annotation opener tokens.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses `Annotation` records and restricts attachment to `FuncField` and func imports.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints supported function/import annotations back to WAST.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers function/import annotations into `FuncAnnotationSec` keyed by absolute `FuncIdx`.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) owns `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) have no `FuncAnnotationSec` support today; binary roundtrip only preserves opaque custom sections and the structured name section.
- [`src/passes/no_inline.mbt`](../../../../src/passes/no_inline.mbt), [`src/passes/inlining.mbt`](../../../../src/passes/inlining.mbt), [`src/passes/duplicate_function_elimination.mbt`](../../../../src/passes/duplicate_function_elimination.mbt), [`src/passes/duplicate_import_elimination.mbt`](../../../../src/passes/duplicate_import_elimination.mbt), and [`src/passes/remove_unused_module_elements.mbt`](../../../../src/passes/remove_unused_module_elements.mbt) are the main current pass users or remappers.

## Follow-up questions

- If Starshine wants Binaryen parity for branch hints or expression inline hints, should it first add a general expression-level annotation map, a narrower branch-hint model, or opaque code-metadata custom-section preservation?
- Should a future binary codec preserve `FuncAnnotationSec` through the official code-metadata/custom-section payload, or keep it as an in-memory/WAST-only Starshine policy lane?
- Should Starshine validate `FuncAnnotationSec` entry indices the way it validates structured name-section entries, or continue treating the section as pass-owned metadata with local pass tests as the guardrail?
