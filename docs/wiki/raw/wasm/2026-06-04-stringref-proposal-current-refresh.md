# Stringref Proposal Current Refresh

Capture date: 2026-06-04

Purpose: refresh Starshine's WAST/core/binary/validator string-instruction wiki pages against current primary WebAssembly sources and local repository evidence, especially the array helper operand wording and the status of the local `StringRefsSec` / section-id-`14` binary surface.

## Primary sources checked

1. WebAssembly proposals tracker, `Reference-Typed Strings` row: <https://github.com/WebAssembly/proposals>
   - Checked 2026-06-04.
   - Finding: `Reference-Typed Strings` is currently listed under Phase 1 (`Feature Proposal`). This makes it useful primary proposal evidence, not a stable Core WebAssembly 3.0 contract.
2. WebAssembly stringref proposal overview: <https://github.com/WebAssembly/stringref/blob/main/proposals/stringref/Overview.md>
   - Checked 2026-06-04.
   - Finding: the proposal defines `stringref`, `string.const`, memory-backed string new/encode helpers, GC-array-backed string new/encode helpers, additional measurement/equality/view/iterator helpers, and a `stringrefs ::= section_14(0x00 vec(vec(u8)))` binary section.
   - Finding: the GC-array construction helpers use `start` and **exclusive `end`** operands, not `start` plus length: `string.new_utf8_array`, `string.new_lossy_utf8_array`, and `string.new_wtf8_array` require an `array i8`; `string.new_wtf16_array` requires an `array i16`.
   - Finding: the GC-array encoding helpers use `stringref`, mutable array, and `start`: UTF-8 / lossy UTF-8 / WTF-8 use `array (mut i8)`, while WTF-16 uses `array (mut i16)`.
   - Finding: proposal opcode assignments match Starshine's implemented local subset for the array helpers: `0xfb 0xb0` through `0xfb 0xb7`, with `string.const` at `0xfb 0x82` and the draft `stringrefs` section at section id `14`.
3. Current WebAssembly Core 3.0 instruction syntax page dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/instructions.html>
   - Checked 2026-06-04.
   - Finding: no `stringref` or `string.*` instruction surface appears in current Core 3.0 instruction syntax.
4. Current WebAssembly Core 3.0 binary instruction page dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/instructions.html>
   - Checked 2026-06-04.
   - Finding: the core `0xfb` table covers GC/aggregate instructions in current Core 3.0 but does not include `string.*` instructions or `stringrefs` section semantics.

## Starshine repository evidence checked

- `src/wast/keywords.mbt` registers `string.const`, `string.new_utf8_array`, `string.new_wtf16_array`, `string.encode_utf8_array`, `string.encode_wtf16_array`, `string.new_lossy_utf8_array`, `string.new_wtf8_array`, `string.encode_lossy_utf8_array`, and `string.encode_wtf8_array`.
- `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast.mbt` parse, lower, and print those supported spellings. The WAST layer does not carry a textual type immediate on string array helpers; validation derives the array storage proof from the operand reference type.
- `src/lib/types.mbt` models `StringConst(Bytes)`, the eight supported array-backed string helpers, `ValType::stringref()`, and the abstract string heap type.
- `src/binary/encode.mbt` emits `StringRefsSec` as local section id `14`, collects deterministic `string.const` payloads through `encode_module_stringrefs(...)`, encodes `string.const` as `0xfb 0x82`, and encodes array helpers as `0xfb 0xb0` through `0xfb 0xb7`.
- `src/binary/decode.mbt` decodes local section id `14`, installs the string literal pool context, decodes `0xfb 0x82` back to literal bytes, and decodes `0xfb 0xb0` through `0xfb 0xb7` to the eight supported array helpers.
- `src/validate/typecheck.mbt` validates `string.const` as producing `stringref`, validates array-backed constructors with two `i32` operands plus a packed `i8` / `i16` array reference, and validates encoders with `stringref`, mutable packed array, and `i32` start.
- `src/wast/arbitrary.mbt` classifies string helpers as GC-like/reference-surface facts when encountered, but the living WAST page remains correct that the arbitrary text generator should not be cited as dedicated emission coverage unless a generation path is shown.

## Durable reconciliation

- Starshine intentionally implements a narrow **proposal-facing** stringref subset: `string.const` plus the eight GC-array-backed string helper operations. The subset is source-backed by the active stringref proposal and local code, but it is not stable Core WebAssembly 3.0.
- Update docs to say current Core 3.0 lacks the string instruction surface, while the active Phase-1 stringref proposal does define section id `14` and the `0xfb 0x82` / `0xfb 0xb0..0xb7` opcode assignments that Starshine mirrors locally.
- Update array-construction guidance from `start + length` to `start + exclusive end`. Existing examples with `start = 0` and the second operand equal to the desired length remain valid examples, but the prose should call that second operand `end`, not `length`.
- Keep wider stringref proposal operations (`string.measure_*`, memory-backed `string.new_*` / `string.encode_*`, `string.concat`, `string.eq`, `string.is_usv_sequence`, string views, iterators, and `stringview_*`) documented as unsupported locally until Starshine grows matching AST, binary, validator, WAST, generator, and tests.
