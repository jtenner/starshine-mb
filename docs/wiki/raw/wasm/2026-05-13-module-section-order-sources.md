# WebAssembly Module Section Order Sources (2026-05-13)

## Scope

Primary-source snapshot for the Starshine wiki page [`../../binary/module-section-map.md`](../../binary/module-section-map.md). This note captures the durable facts needed to relate official WebAssembly 3.0 module ordering, custom-section placement, abstract syntax/index spaces, and Starshine's local binary encode/decode/validation order.

## Sources Checked

1. WebAssembly Core Specification 3.0, binary modules: <https://webassembly.github.io/spec/core/binary/modules.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). This is the canonical source for magic/version bytes, standard section sequence, custom-section gaps, data-count-before-code, code/data placement, and section ids through tag/data-count.
2. WebAssembly Core Specification 3.0, syntax modules: <https://webassembly.github.io/spec/core/syntax/modules.html> (searched/opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). This is the canonical source for abstract module components, imported-prefix index spaces, start/export/data/element descriptions, and the fact that imports precede local definitions in each same-kind index space.
3. WebAssembly Core Specification 3.0, validation modules: <https://webassembly.github.io/spec/core/valid/modules.html> (opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). This is the canonical source for closed-module validation context construction, import/export module type classification, export-name disjointness, and the broad validation dependency order.
4. WebAssembly Core Specification 3.0, custom sections and annotations appendix: <https://webassembly.github.io/spec/core/appendix/custom> (opened 2026-05-13; page release shown by the site as 2026-05-12 in the opened view). This is the source for current text-format custom-section placement annotations and for the caveat that source-level custom-section placement can be more detailed than Starshine's current `custom_secs` representation preserves.

## Durable Takeaways

- A binary module starts with the fixed magic bytes `00 61 73 6d` and version bytes `01 00 00 00`.
- Standard binary sections are ordered by section family, not by text declaration order: type, import, function, table, memory, tag, global, export, start, element, data count, code, data. Custom sections may appear in gaps around those standard sections.
- Section ids are not strictly the same as the on-wire order once post-MVP additions are included: tag is id `13` but appears before global, and data-count is id `12` but appears before code/data.
- The abstract module model groups imports with local definitions in the relevant index spaces. For functions, tables, memories, globals, and tags, imported entries come before locally defined entries.
- Validation constructs a module context from the module itself rather than requiring an external validation environment; Starshine's `validate_module_impl` mirrors this idea with an explicit environment-building sequence.
- Custom-section placement annotations can express before/after placement around known sections. Starshine currently decodes custom sections from every standard gap but encodes non-`name` `custom_secs` before standard sections and emits the structured `name` section at the tail after data.

## Local Starshine Evidence To Pair With This Snapshot

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt): `Module` fields and section wrapper types.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt): whole-module decode order, custom-section gap scanning, `name`-section split, and local `stringrefs` section handling.
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt): whole-module canonical encode order, custom-section normalization, local `stringrefs` collection, and tail `name` section emission.
- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt): validation dependency order, data-count cross-checks, code-section checks, and name-section validation.
- [`../../../../src/binary/tests.mbt`](../../../../src/binary/tests.mbt): binary round-trip and malformed-section coverage.

## Caveats

- This snapshot intentionally does not treat Starshine's local `StringRefsSec` id `14` as a stable core WebAssembly section. See [`../../binary/type-table-memory-global-tag-sections.md`](../../binary/type-table-memory-global-tag-sections.md) for the current caveat.
- The official binary grammar allows custom sections in many gaps, and the appendix documents text placement annotations. Starshine preserves non-`name` custom payloads but not exact original placement.
