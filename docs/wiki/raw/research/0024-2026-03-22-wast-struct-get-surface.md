# WAST Struct Access Surface

Status: landed higher-level WAST support for `struct.get`, `struct.get_s`, and `struct.get_u`.

## Scope

Document the next GC text-surface compatibility slice needed by `tests/spec/proposals/custom-descriptors/ref_get_desc.wast`: the higher-level parser, printer, and lowerer now model folded struct field access instructions instead of stopping at the first `struct.get`.

## Current Behavior

- Higher-level WAST now tokenizes:
  - `struct.get`
  - `struct.get_s`
  - `struct.get_u`
- The parser accepts the immediate pair:
  - struct type index
  - field index
- Folded instruction forms now lower in stack order, so nested authoring such as:
  - `(struct.get 0 0 (struct.new 0 ...))`
  becomes the expected instruction stream.
- Printing preserves the explicit field-access opcode names and immediates.
- Lowering maps the three opcodes onto:
  - `@lib.Instruction::struct_get`
  - `@lib.Instruction::struct_get_s`
  - `@lib.Instruction::struct_get_u`

## Why This Slice Matters

After the legacy GC alias slice, the mixed-runtime custom-descriptor fixture advanced to a simpler front-end failure: the higher-level WAST parser did not recognize folded `struct.get` forms even though the lib and validator layers already modeled struct field loads.

Landing the text-surface support keeps the mixed-runtime fixture moving without widening scope into unrelated GC instruction families first.

## Correctness Constraints

- The field index must remain an unsigned immediate, not a general index/id.
- Lowering must resolve the struct type immediate through the existing named-or-numeric type index path.
- Signed and unsigned packed-field accessors must preserve their distinct opcode spellings through parse and print.

## Validation

- Added lexer coverage for the three new opcodes.
- Added end-to-end parse, print, and lowering coverage in `src/wast/struct_get_surface_test.mbt`.
- Targeted red-to-green gate during landing:
  - `moon test src/wast -F '*struct access*'`
- Follow-up confirmation after the slice:
  - `moon test src/wast/spec_harness.mbt --target native -F '*mixed-runtime custom descriptor fixtures*'`
  - the fixture advanced beyond the previous `struct.get` parse stop and exposed the next unrelated gap.

## Performance Impact

- No meaningful runtime impact.
- Parser cost is one more opcode-table entry and a small immediate parse on these instructions.

## Remaining Work

- `ref_get_desc.wast` next exposed imported global parsing for parenthesized exact ref types.
- The mixed-runtime fixture still needs further lifting beyond the accessor surface.

## Open Questions

- Whether later GC text-surface compatibility work should continue as narrow fixture-driven slices or broaden into a larger “remaining GC opcodes” sweep once the custom-descriptor fixtures are green.
