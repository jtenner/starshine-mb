# Code Metadata And Branch-Hint Status Refresh

- Capture date: 2026-06-05
- Source family: WebAssembly Core 3.0 custom annotations, code metadata, branch hinting, and Starshine WAST/function-annotation repository evidence

## Primary sources checked

1. WebAssembly Core Specification 3.0, `Custom Sections and Annotations`, dated 2026-06-03: <https://webassembly.github.io/spec/core/appendix/custom.html>
   - The page describes custom sections as payloads that do not affect the core semantics of a module.
   - The text annotation forms `(@name ...)` and `(@custom ...)` are official text-level syntax. `@name` writes names at supported binding sites; `@custom` can describe arbitrary custom sections and placement relative to other module sections.
   - The appendix now also points at code metadata and branch hinting as defined custom-section use cases.
2. WebAssembly Code Metadata specification, overview / binary / text pages: <https://webassembly.github.io/spec/metadata/code/>, <https://webassembly.github.io/spec/metadata/code/binary.html>, <https://webassembly.github.io/spec/metadata/code/text.html>
   - Code metadata is represented by custom sections named `metadata.code.<type>`.
   - Binary code metadata entries are keyed by function index and an instruction byte offset inside that function body.
   - Text code metadata appears as annotations immediately before the instruction it annotates, not before a whole function by default.
3. WebAssembly Branch Hinting specification: <https://webassembly.github.io/spec/metadata/code/branch-hinting.html>
   - Branch hints use `metadata.code.branch_hint`.
   - The hint is attached to `if` and `br_if` instruction locations and encodes branch direction as one byte.
4. WebAssembly finished-proposals table: <https://webassembly.org/features/>
   - `Branch Hinting` and `Custom Annotation Syntax` are listed as finished proposals with Core 3.0 as the specification release.
5. WebAssembly proposals tracker: <https://github.com/WebAssembly/proposals>
   - `Branch Hinting` and `Custom Annotation Syntax` are not active proposal rows in the checked tracker. `Compilation Hints` remains an active Phase-2 proposal and should not be conflated with the finished branch-hinting/custom-annotation surfaces.

## Starshine repository evidence checked

- `src/wast/parser.mbt` defines `Annotation`, parses `(@...)`, and only attaches accumulated annotations to defined functions and function imports through `attach_annotations(...)` / `parse_annotated_module_field(...)`.
- `src/wast/module_wast.mbt` prints the supported function/import annotations back before function/import fields.
- `src/wast/lower_to_lib.mbt` lowers accepted function/import annotations into `FuncAnnotationSec` entries keyed by absolute `FuncIdx`; its focused test fixture lowers `(@binaryen.js.called)`, `(@binaryen.idempotent)`, and `(@metadata.code.inline "\\00")` as function annotations.
- `src/lib/types.mbt` models `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec`.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` preserve opaque custom sections and structured `NameSec`, but there is no current `FuncAnnotationSec` binary custom-section codec and no expression-level code-metadata map.
- `src/passes/no_inline.mbt`, `src/passes/inlining.mbt`, `src/passes/duplicate_function_elimination.mbt`, `src/passes/duplicate_import_elimination.mbt`, and `src/passes/remove_unused_module_elements.mbt` are current pass-policy or remap consumers of function annotations. Repository search found no local `branch_hint` representation.

## Durable reconciliation

1. Official custom annotation syntax and branch hinting should be taught as finished/Core-3.0 metadata surfaces, not as active proposal gaps. Generic code metadata is the mechanism that carries branch hints.
2. Starshine's current `(@...)` lane remains intentionally narrower: it is a function/import annotation surface only, lowers to `FuncAnnotationSec`, and does not implement official `@name`, official placement-aware `@custom`, expression-level code metadata, `metadata.code.branch_hint`, or a binary code-metadata custom-section codec.
3. `(@metadata.code.inline "\\00")` in current Starshine WAST is a function annotation with that name and raw argument, not proof of Binaryen-style instruction-local inline metadata. Binaryen pass pages may still use upstream inline/branch-hint examples as oracle/source evidence.
4. `Compilation Hints` is a separate active proposal row. Do not use branch-hinting/Core-3.0 evidence to claim local or stable support for unrelated compilation-hint payloads.

## Follow-ups

- If Starshine implements official `@name` or `@custom`, update `wast/identifier-name-and-annotation-authoring.md`, `wast/code-metadata-and-function-annotations.md`, `binary/custom-and-name-sections.md`, the WAST text-surface gap ledger, and parser/lowerer/printer tests together.
- If Starshine implements expression-level code metadata or branch hints, add an explicit representation design, parser/lowerer/printer tests, binary codec or opaque-custom-section policy, and pass-remap tests before pass pages claim local branch-hint parity.
- Keep `Compilation Hints` routed through the feature-status page as active-proposal evidence until a focused source and local implementation slice lands.
