---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/research/0052-2026-03-22-string-const-surface.md
  - ../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/module-section-map.md
  - ../wast/string-instruction-authoring.md
  - ../validate/constant-expressions.md
related:
  - ../binary/module-section-map.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../wast/string-instruction-authoring.md
  - ../validate/constant-expressions.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/ir/hot_side_tables.mbt
---

# `string.const` Surface

## Durable Conclusions

- `string.const "..."` is part of the public lib and higher-level WAST instruction surface. The broader text/typechecking contract for all currently supported string instructions now lives in [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md).
- Validation treats `string.const` as a `stringref`-producing instruction and allows it in Starshine-local constant-expression contexts such as immutable globals; the focused allow-list and portability caveats live in [`../validate/constant-expressions.md`](../validate/constant-expressions.md).
- Binary encoding emits Starshine's local `StringRefsSec` literal pool before globals and code and roundtrips `string.const` through that section.
- Decoding resolves string-literal indices back to literal bytes before later module consumers see the instruction.
- The binary value-type decoder accepts the bare `0x64` stringref shorthand when the explicit non-null-reference form cannot be completed, which lets standalone stringref result types decode instead of failing before string passes run. Tests also lock explicit nullable `0x63 0x64` and explicit non-null `0x64 0x64` stringref value-type decode/re-encode behavior.
- Source-refresh caveat: the 2026-05-13 official WebAssembly 3.0 / js-string-builtins source check did **not** find a stable core `stringrefs` section id. Treat Starshine's section id `14` as local/proposal-facing until upstream sources define it.
- IR and SSA treat `string.const` as a pure nullary value producer with a typed payload.

## Practical Rule

- Preserve literal bytes exactly through lowering, validation, and binary roundtrip; later string work depends on literal identity, not just section indices.
- Keep the local string-literal section stable and deterministic during encode.
- When documenting binary layout, link to [`../binary/module-section-map.md`](../binary/module-section-map.md) and [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) so the section-id-`14` caveat stays visible.
- Use [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md) for array-backed string new/encode helper stack shapes, storage-width checks, and WAST arbitrary/generator coverage boundaries.
- The next meaningful follow-up for this literal-pool page is `StringGathering`, not more literal-plumbing variations.

## Sources

- Archived research doc: [`../raw/research/0052-2026-03-22-string-const-surface.md`](../raw/research/0052-2026-03-22-string-const-surface.md)
- Binary section caveat and module-order refresh: [`../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md`](../raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md), [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md), [`../binary/module-section-map.md`](../binary/module-section-map.md)
- WAST string instruction companion: [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md)
- Constant-expression validator companion: [`../validate/constant-expressions.md`](../validate/constant-expressions.md)
