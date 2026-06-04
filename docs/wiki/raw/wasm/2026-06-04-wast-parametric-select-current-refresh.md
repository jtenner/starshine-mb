# WAST Parametric Select Current-Source Refresh (2026-06-04)

## Purpose

This current-source refresh rechecks the living WAST parametric-instruction guide after the official WebAssembly Core Specification pages advanced from the 2026-05-14 draft snapshot to WebAssembly 3.0 dated 2026-06-03. It focuses on the durable portability split around `select`: ordinary single-value `drop` / `select`, annotated reference select, unannotated numeric/vector select, and Starshine's locally supported vector-valued typed-select plumbing.

## Primary external sources checked

- WebAssembly Core Specification, `Syntax / Instructions` — WebAssembly 3.0 (page title dated 2026-06-03): <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Rechecked the parametric instruction grammar. The abstract syntax still spells `select` as an optional value-type sequence and immediately explains that a missing annotation restricts operands to numeric or vector types, while the note still frames multi-value select as future-facing.
- WebAssembly Core Specification, `Text Format / Instructions` — WebAssembly 3.0 (page title dated 2026-06-03): <https://webassembly.github.io/spec/core/text/instructions.html>
  - Rechecked the text grammar. The text form still accepts `select` with an optional `(result ...)` sequence, which is why WAST syntax can visually carry more than one result type even though validation remains single-choice today.
- WebAssembly Core Specification, `Binary Format / Instructions` — WebAssembly 3.0 (page title dated 2026-06-03): <https://webassembly.github.io/spec/core/binary/instructions.html>
  - Rechecked the opcode split: `0x1A` decodes `drop`, `0x1B` decodes untyped `select`, and `0x1C` decodes typed `select` followed by a `list(valtype)` immediate.
- WebAssembly Core Specification, `Validation / Instructions` — WebAssembly 3.0 (page title dated 2026-06-03): <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked the validation rule. Annotated `select` is still valid only when the optional value-type sequence has the form of one value type `t`; unannotated `select` still requires the result type to match a numeric or vector supertype; the note still says future WebAssembly may allow more than one value per choice.
- WebAssembly Core Specification, `Execution / Instructions` — WebAssembly 3.0 (page title dated 2026-06-03): <https://webassembly.github.io/spec/core/exec/instructions.html>
  - Rechecked runtime behavior: `drop` pops one value, and `select` pops the `i32` condition, then the second and first candidate values, and pushes the first candidate for nonzero conditions or the second for zero.

## Local Starshine sources checked

- `src/wast/parser.mbt`
  - `Select(Array[ValueType]?)` and the parser's typed-select lookahead still store a whole optional result vector; parser tests still cover untyped and single-result typed select.
- `src/wast/lower_to_lib.mbt`
  - `wt_select_types(...)` still maps every WAST typed-select annotation into core `ValType`s before constructing `Instruction::select(...)`.
- `src/wast/module_wast.mbt`
  - The printer still emits `select (result ...)` by iterating the full annotation vector.
- `src/lib/types.mbt`
  - The core instruction remains `Select(Array[ValType]?)`, preserving a vector-valued typed-select annotation.
- `src/binary/decode.mbt` and `src/binary/encode.mbt`
  - The binary codec still mirrors the official opcode split and round-trips `0x1C` as a vector-valued value-type list.
- `src/validate/typecheck.mbt`
  - `typecheck_select_typed(...)` validates every annotated type, pops two copies of the full annotation vector after the `i32` condition, then pushes that vector back.
  - `typecheck_select_untyped(...)` still requires only mutual `Match::matches(...)` between the two operands in reachable code, with no separate local check that the inferred type is numeric or vector.
- `src/validate/gen_valid.mbt` and `src/wast/arbitrary.mbt`
  - Generator coverage remains intentionally conservative: `gen_valid` tracks typed-select core-control coverage, while arbitrary WAST still serves parser/printer surface coverage rather than a full conformance oracle.

## Durable conclusions

1. The May 20 portability caveat is still current on June 4: official text and binary grammar expose a vector-looking typed-select annotation, but official validation remains single-choice and explicitly leaves multi-value select to possible future WebAssembly.
2. Starshine's vector-valued `Select(Some(ts))` plumbing is useful local regression coverage across parser, core IR, binary codec, printer, and validator, but it should not be cited as portable WebAssembly conformance evidence.
3. Starshine's untyped-select validator is still wider than the official unannotated rule for reference-like values, because it checks mutual type matching but does not enforce numeric/vector-only inference. Treat accepted untyped reference select as local behavior unless a future validator change deliberately aligns it with the spec restriction.
4. Wiki and fixture guidance should keep three profiles separate: portable untyped numeric/vector select, portable single-result typed select for references or exact types, and Starshine-local multi-value typed select regression fixtures.
