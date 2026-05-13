---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-custom-and-name-section-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/lib/module.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/validate/gen_invalid_tests.mbt
  - ../../../src/fuzz/invalid_binary_wbtest.mbt
related:
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/fuzz-hardening.md
  - ../binaryen/passes/reorder-locals/index.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - ../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md
---

# Binary Custom And Name Sections

## Overview

WebAssembly custom sections are section-id-`0` records that carry a UTF-8 name plus uninterpreted bytes. The core spec treats them as semantically ignored metadata that may appear at any custom-section gap in a binary module. The standardized name section is a special custom section named `name` with ordered subsections for module, function, local, label, type, table, memory, global, element, data, field, and tag names.

Starshine deliberately does **not** keep arbitrary custom sections and the `name` section in one opaque bucket. The in-memory module shape in [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt) splits metadata into:

- `Module.custom_secs : Array[CustomSec]` for non-`name` custom sections;
- `Module.name_sec : NameSec?` for a parsed structured name section; and
- `Module.raw_name_sec_payload : Bytes?` for preserving the original decoded name payload when no structured rewrite has invalidated it.

This gives validators and mutating passes a typed view of debug names while still preserving unknown custom payloads. The tradeoff is that Starshine normalizes section placement on encode: non-`name` custom sections are emitted before standard sections, and the `name` custom section is emitted after the data section.

## Binary Shapes

### Ordinary custom section

```text
section id = 0
section size = u32 byte length of payload
payload = name:string + raw payload bytes
```

Starshine stores this as [`CustomSec(Name, Bytes)`](../../../src/lib/types.mbt). Decode keeps the payload bytes after the custom-section name; encode reconstructs the section wrapper in [`src/binary/encode.mbt`](../../../src/binary/encode.mbt).

### Structured name section

```text
section id = 0
section name = "name"
payload = name subsections in strictly increasing subsection-id order
```

The official WebAssembly 3.0 source snapshot in [`../raw/wasm/2026-05-13-custom-and-name-section-sources.md`](../raw/wasm/2026-05-13-custom-and-name-section-sources.md) lists the standardized subsection ids as `0` module, `1` function, `2` local, `3` label, `4` type, `5` table, `6` memory, `7` global, `8` element, `9` data, `10` field, and `11` tag. Starshine's `NameSec` mirrors that span directly.

## Decode / Encode Flow

| Stage | Starshine behavior | Evidence |
| --- | --- | --- |
| Decode custom gaps | [`decode_custom_sections_with_detail(...)`](../../../src/binary/decode.mbt) consumes custom sections before each standard section and at the tail. Non-`name` sections become `CustomSec`; the first `name` section becomes `NameSec` plus `raw_name_sec_payload`; a second `name` section is a decode error. | `src/binary/decode.mbt`, `src/binary/tests.mbt` malformed custom and name-section tests. |
| Decode name payload | [`Decode for NameSec`](../../../src/binary/decode.mbt) enforces strictly increasing subsection ids and rejects unknown subsection ids. | `InvalidNameSubsectionOrder`, `InvalidNameSubsectionId` in `src/binary/decode.mbt`. |
| Encode custom sections | [`Encode for Module`](../../../src/binary/encode.mbt) emits `custom_secs` first and rejects `CustomSec` entries named `name`. | `RawNameCustomSectionUnsupported` in `src/binary/encode.mbt`. |
| Encode name section | If `raw_name_sec_payload` is present, encode reuses that payload; otherwise it serializes structured `NameSec` subsections. | `encode_raw_name_sec_payload_as_custom_section(...)`, `encode_name_sec_as_custom_section(...)`. |
| Structured rewrite | [`Module::with_name_sec(...)`](../../../src/lib/module.mbt) and [`Module::without_name_sec(...)`](../../../src/lib/module.mbt) clear the raw payload so stale byte-level names are not re-emitted after structured changes. | `src/lib/module.mbt`. |

## Validation Contract

[`validate_name_sec(...)`](../../../src/validate/validate.mbt) makes name-section metadata locally useful instead of treating it as inert bytes:

- raw `CustomSec("name", ...)` entries are rejected; use `Module.name_sec`;
- function, type, table, memory, global, element, data, and tag names must point at existing indices;
- local and label names must point at an existing function and an in-range local or label inside that function;
- field names must point at an existing struct type and an in-range field;
- name validation failures report the `NameSectionFamily` through invalid-generation tests in [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt) and binary invalid tests in [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt).

This is stricter than the core semantic rule that custom sections are ignored. The stricter local rule is intentional because Starshine uses structured names for diagnostics, pretty output, and pass-maintained index maps.

## Pass And Tooling Implications

### Index-rewriting passes

Passes that remove or reorder index spaces must rewrite or clear affected name maps:

- [`reorder-locals`](../binaryen/passes/reorder-locals/index.md) rewrites local-name maps for changed functions and clears `raw_name_sec_payload`; its tests assert the raw payload is gone after structured local renumbering.
- [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md) rewrites retained table, memory, global, tag, function, element, and data name maps as module entities are pruned or remapped.
- `duplicate-function-elimination`, `reorder-globals`, and `string-gathering` tests also exercise the rule that stale function/global names must not survive an index-changing module pass unchanged.

### Opaque custom sections

Most passes should preserve `custom_secs` unless they specifically own a metadata policy. The clearest future exception is `strip-target-features`: the port-readiness page explicitly distinguishes deleting only `target_features` custom sections from generic custom-section stripping. Do not use that pass as a reason to drop `producers`, unknown third-party custom sections, or the structured `name` section.

### Fuzzing and invalid repros

The generator coverage ledger tracks `NameCustomSections` so valid-generator coverage includes both a structured `name` section and a non-`name` custom section. The invalid lanes separately cover malformed custom-section names, duplicate/invalid name subsections, and out-of-range structured name-map entries. When adding a new metadata surface, update [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) and [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) instead of hiding the behavior in pass-only tests.

## Edge Cases And Invariants

- **Placement is not preserved.** Decode accepts custom sections at every spec-allowed gap, but encode currently emits all non-`name` custom sections before standard sections. If exact placement matters, add a placement-bearing representation rather than relying on `custom_secs` order alone.
- **Only one `name` section is accepted.** Duplicate `name` custom sections are rejected during module decode.
- **Raw name payload reuse is conditional.** Preserve it only when no pass or API call has structurally rewritten names or referenced index spaces.
- **The `0` through `11` subsection span is source-backed.** Do not add new subsection ids without refreshing the primary-source snapshot and extending decode/encode/validation tests together.
- **Name maps are not uniqueness maps for strings.** Indices must be unique and ordered; name strings themselves may repeat.

## Sources

- Primary-source snapshot: [`../raw/wasm/2026-05-13-custom-and-name-section-sources.md`](../raw/wasm/2026-05-13-custom-and-name-section-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/module.mbt`](../../../src/lib/module.mbt)
- Decode and encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation and invalid generation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt), [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt)
- Related docs: [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md`](../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md)
