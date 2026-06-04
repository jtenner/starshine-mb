# WebAssembly Custom, Name, And Text Annotation Current Refresh

- Capture date: 2026-06-04
- Source family: WebAssembly Core Specification 3.0 custom/name section appendix plus Starshine repository evidence
- Primary source:
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/appendix/custom.html>
- Repository evidence:
  - [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
  - [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
  - [`src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
  - [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)

## Durable takeaways

- The current official WebAssembly 3.0 custom appendix still treats custom sections and text annotations as metadata that do not affect core WebAssembly semantics.
- The current official name-section subsection set remains module `0`, function `1`, local `2`, type `4`, field `10`, and tag `11`. The page still does not list label/table/memory/global/element/data subsections, so Starshine ids `3` and `5..9` remain local richer metadata unless a newer primary source standardizes them.
- The official text layer now matters for wiki wording because it distinguishes:
  - `(@name "...")` name annotations, which are textual analogues of name-section entries and are allowed on module, function/import, parameter/local, type, field, and tag binding sites;
  - `(@custom "section-name" [(before|after ...)] "payload"...)` custom annotations, which represent arbitrary custom sections inside a module and can carry placement directives.
- Official `@name` can take precedence over a textual identifier for the binding's printed name. That is a different contract from Starshine's current WAST lowering, which promotes only function/import identifiers to `NameSec.func_names` and does not implement general `@name` lowering.
- Official `@custom` supports repeated custom-section annotations, arbitrary custom-section names, data-string payloads, and explicit placement relative to standard sections. Starshine's current WAST `(@...)` parser lane is not this placement-aware custom-annotation model.

## Starshine implications

- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) currently parses a leading `(@...)` form only as a local `Annotation` before a top-level module field, then `attach_annotations(...)` accepts that array only on a defined function or function import.
- Because that parser lane stores the annotation name and raw arguments without interpreting the official ids, a WAST snippet such as `(@name "debug") (func ...)` is a Starshine function annotation named `name`, not a portable name annotation that writes `NameSec.func_names`.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers function/import identifiers into `NameSec.func_names` through `wt_push_func_name(...)`, and lowers accepted function/import annotations into `FuncAnnotationSec` through `wt_func_annotations(...)`. Those paths are separate.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) / [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) preserve opaque non-`name` custom sections and structured `NameSec` payloads, but Starshine's binary encoder normalizes placement instead of preserving arbitrary official `@custom` text-placement directives.
- Wiki pages should route official `@name` / `@custom` text syntax to the custom/name-section guide and keep Starshine's function/import `(@...)` lane in the focused code-metadata/function-annotation guide.

## Supersession and uncertainty

- This refresh does not supersede the 2026-05-20 label-subsection correction; it confirms the same official subsection set against the 2026-06-03 current WebAssembly 3.0 page.
- It does refine the wording on WAST annotation pages: Starshine's local `(@...)` function-annotation parser can lex names that look like official `@name` or `@custom`, but it does not implement their official placement, name-section, or custom-section semantics.
- If Starshine later implements official text annotations, the first implementation should add parser/lowerer/printer tests for `@name` binding sites and `@custom` placement forms before living docs claim support.
