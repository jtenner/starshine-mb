---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../raw/research/0052-2026-03-22-string-const-surface.md
related:
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/ir/hot_side_tables.mbt
---

# `string.const` Surface

## Durable Conclusions

- `string.const "..."` is part of the public lib and higher-level WAST instruction surface.
- Validation treats `string.const` as a `stringref`-producing instruction and allows it in constant-expression contexts such as immutable globals.
- Binary encoding emits a real string-literal section before globals and code and roundtrips `string.const` through that section.
- Decoding resolves string-literal indices back to literal bytes before later module consumers see the instruction.
- IR and SSA treat `string.const` as a pure nullary value producer with a typed payload.

## Practical Rule

- Preserve literal bytes exactly through lowering, validation, and binary roundtrip; later string work depends on literal identity, not just section indices.
- Keep the string-literal section stable and deterministic during encode.
- The next meaningful follow-up is `StringGathering`, not more literal-plumbing variations.

## Sources

- Archived research doc: [`../raw/research/0052-2026-03-22-string-const-surface.md`](../raw/research/0052-2026-03-22-string-const-surface.md)
