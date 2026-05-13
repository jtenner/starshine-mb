# WebAssembly Custom And Name Section Source Snapshot

- Capture date: 2026-05-13
- Source family: WebAssembly Core Specification 3.0 draft
- Primary sources:
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (2026-05-12)`: <https://webassembly.github.io/spec/core/appendix/custom>

## Durable takeaways

- A binary module starts with magic/version bytes and then standard sections in prescribed order, with zero or more custom sections allowed before each standard section and after the last standard section.
- Custom sections use section id `0`. Their payload is a UTF-8 `name` followed by uninterpreted bytes, and they are meant for debugging information or third-party extensions. WebAssembly semantics ignore them.
- The current dedicated name section is itself a custom section whose name string is `name`. The spec says it should appear at most once and after the data section.
- Official WebAssembly 3.0 name-section subsections are: module name `0`, function names `1`, local names `2`, label names `3`, type names `4`, table names `5`, memory names `6`, global names `7`, element segment names `8`, data segment names `9`, field names `10`, and tag names `11`. Each subsection may occur at most once and must be ordered by increasing id.
- Official name maps require unique, increasing indices inside the map; names are UTF-8 and need not be unique.
- Text `@custom` annotations preserve custom-section payloads and include explicit placement directives, but Starshine's current WAT path does not use this page as evidence for any `@custom` text surface.

## Starshine implications

- Starshine's binary decoder can recognize custom sections at every spec-allowed gap, but its structured `Module` model stores only `Array[CustomSec]`, `NameSec?`, and `raw_name_sec_payload?`, not original custom-section placement. The encoder therefore normalizes non-`name` custom sections before standard sections and emits the name section at the end.
- Starshine intentionally treats a custom section named `name` specially: decode parses it into `Module.name_sec` plus `raw_name_sec_payload`, validation rejects raw `CustomSec("name", ...)`, and encode rejects `custom_secs` entries named `name`.
- Starshine's `NameSec` map matches the official WebAssembly 3.0 subsection id span `0` through `11`, including label, table, memory, global, element, data, field, and tag names.
- Mutating passes that change function, local, global, table, element, data, or tag indices must either rewrite the corresponding structured `NameSec` maps or clear stale names. Preserving `raw_name_sec_payload` after structured index rewrites is unsafe because the raw payload may still refer to old indices.

## Follow-up questions

- If Starshine needs byte-for-byte custom-section placement preservation, add an explicit placement-bearing custom-section model instead of overloading `Module.custom_secs`.
- If future specs add new name subsections, refresh this source snapshot before accepting new subsection ids in `Decode for NameSec`.
