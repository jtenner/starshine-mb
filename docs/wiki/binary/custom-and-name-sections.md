---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../raw/wasm/2026-05-20-name-section-label-subsection-correction.md
  - ../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md
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
  - module-section-map.md
  - function-import-export-and-code-sections.md
  - data-element-and-datacount-sections.md
  - type-table-memory-global-tag-sections.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/module-validation-phases.md
  - ../validate/fuzz-hardening.md
  - ../wast/identifier-name-and-annotation-authoring.md
  - ../wast/code-metadata-and-function-annotations.md
  - ../binaryen/passes/reorder-locals/index.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - ../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md
---

# Binary Custom And Name Sections

## Overview

For the whole-module placement and ordering map that ties custom metadata to the standard sections, start with [`module-section-map.md`](module-section-map.md). For the text-authoring side of `$` identifiers and function-name lowering, see [`../wast/identifier-name-and-annotation-authoring.md`](../wast/identifier-name-and-annotation-authoring.md); for Starshine's narrow function/import `(@...)` lane and the split from WebAssembly/Binaryen code metadata, see [`../wast/code-metadata-and-function-annotations.md`](../wast/code-metadata-and-function-annotations.md). WebAssembly custom sections are section-id-`0` records that carry a UTF-8 name plus uninterpreted bytes. The core spec treats them as semantically ignored metadata that may appear at custom-section gaps in a binary module.

The standardized name section is a special custom section named `name`, but the official-versus-local boundary matters. The 2026-05-20 primary-source refresh in [`../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md`](../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md) corrected the earlier 2026-05-13 snapshot by removing table, memory, global, element, and data from the current official set. The later same-day correction in [`../raw/wasm/2026-05-20-name-section-label-subsection-correction.md`](../raw/wasm/2026-05-20-name-section-label-subsection-correction.md) narrows the official set one step further: the current WebAssembly 3.0 page checked during this run documents module, function, local, type, field, and tag name subsections, while Starshine additionally accepts, validates, and can emit label, table, memory, global, element, and data name maps as local richer metadata.

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

The corrected current-source read in [`../raw/wasm/2026-05-20-name-section-label-subsection-correction.md`](../raw/wasm/2026-05-20-name-section-label-subsection-correction.md) lists the current standardized subsection ids as `0` module, `1` function, `2` local, `4` type, `10` field, and `11` tag. Starshine's `NameSec` also carries local subsection ids `3` label, `5` table, `6` memory, `7` global, `8` element, and `9` data; treat those as Starshine-local compatibility/richer-metadata support until a newer primary source standardizes them.

## Decode / Encode Flow

| Stage | Starshine behavior | Evidence |
| --- | --- | --- |
| Decode custom gaps | [`decode_custom_sections_with_detail(...)`](../../../src/binary/decode.mbt) consumes custom sections before each standard section and at the tail. Non-`name` sections become `CustomSec`; the first `name` section becomes `NameSec` plus `raw_name_sec_payload`; a second `name` section is a decode error. | `src/binary/decode.mbt`, `src/binary/tests.mbt` malformed custom and name-section tests. |
| Decode name payload | [`Decode for NameSec`](../../../src/binary/decode.mbt) enforces strictly increasing subsection ids and rejects ids outside `0..11`. Ids `3` and `5..9` are Starshine-local name maps, not current official WebAssembly 3.0 name subsections. | `InvalidNameSubsectionOrder`, `InvalidNameSubsectionId` in `src/binary/decode.mbt`; source correction in `raw/wasm/2026-05-20-name-section-label-subsection-correction.md`. |
| Encode custom sections | [`Encode for Module`](../../../src/binary/encode.mbt) emits `custom_secs` first and rejects `CustomSec` entries named `name`. | `RawNameCustomSectionUnsupported` in `src/binary/encode.mbt`. |
| Encode name section | If `raw_name_sec_payload` is present, encode reuses that payload; otherwise it serializes structured `NameSec` subsections. | `encode_raw_name_sec_payload_as_custom_section(...)`, `encode_name_sec_as_custom_section(...)`. |
| Structured rewrite | [`Module::with_name_sec(...)`](../../../src/lib/module.mbt) and [`Module::without_name_sec(...)`](../../../src/lib/module.mbt) clear the raw payload so stale byte-level names are not re-emitted after structured changes. | `src/lib/module.mbt`. |

## Validation Contract

[`validate_name_sec(...)`](../../../src/validate/validate.mbt) makes name-section metadata locally useful instead of treating it as inert bytes; it runs in the final `namesec` phase documented by [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md):

- raw `CustomSec("name", ...)` entries are rejected; use `Module.name_sec`;
- function, type, tag, and the local Starshine label, table, memory, global, element, and data name maps must point at existing indices;
- local names are official in the current checked source; label names and Starshine-local label names must point at an existing function and an in-range local or label inside that function;
- field names must point at an existing struct type and an in-range field;
- name validation failures report the `NameSectionFamily` through invalid-generation tests in [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt) and binary invalid tests in [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt).

This is stricter than the core semantic rule that custom sections are ignored, and the label/table/memory/global/element/data families are broader than the current official name-section grammar. The stricter local rule is intentional because Starshine uses structured names for diagnostics, pretty output, fuzz coverage, and pass-maintained index maps. Do not cite these local failures as official WebAssembly semantic invalidity.

## Pass And Tooling Implications

### Index-rewriting passes

Passes that remove or reorder index spaces must rewrite or clear affected name maps:

- [`reorder-locals`](../binaryen/passes/reorder-locals/index.md) rewrites local-name maps for changed functions and clears `raw_name_sec_payload`; its tests assert the raw payload is gone after structured local renumbering.
- [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md) rewrites retained table, memory, global, tag, function, element, and data name maps as module entities are pruned or remapped.
- `duplicate-function-elimination`, `reorder-globals`, and `string-gathering` tests also exercise the rule that stale function/global names must not survive an index-changing module pass unchanged.

### Opaque custom sections

Most passes should preserve `custom_secs` unless they specifically own a metadata policy. The clearest future exception is `strip-target-features`: the port-readiness page explicitly distinguishes deleting only `target_features` custom sections from generic custom-section stripping. Do not use that pass as a reason to drop `producers`, unknown third-party custom sections, or the structured `name` section.

### Fuzzing and invalid repros

The generator coverage ledger tracks `NameCustomSections` so valid-generator coverage includes both a structured `name` section and a non-`name` custom section. Current coverage-forced modules may include Starshine-local label/table/memory/global/element/data name maps in addition to the official module/function/local/type/field/tag families. The invalid lanes separately cover malformed custom-section names, malformed and overlong UTF-8 custom-section name byte sequences, malformed and overwide custom-section name-length ULEBs, malformed and overwide name-subsection size ULEBs, invalid and out-of-order name-subsection id bytes, duplicate/invalid name subsections, invalid UTF-8 inside module names plus function, local, type, table, memory, global, element, data, field, label, and tag name maps, malformed and overwide name-section string-length ULEBs for those same name payloads, malformed and overwide function-name map count ULEBs, malformed and overwide nested local-name count ULEBs, malformed and overwide type-name map count ULEBs, malformed and overwide table-name map count ULEBs, malformed and overwide memory-name map count ULEBs, malformed and overwide global-name map count ULEBs, malformed and overwide element-name map count ULEBs, and out-of-range structured name-map entries. When adding a new metadata surface, update [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) and [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) instead of hiding the behavior in pass-only tests.

## Edge Cases And Invariants

- **Placement is not preserved.** Decode accepts custom sections at every spec-allowed gap, but encode currently emits all non-`name` custom sections before standard sections. If exact placement matters, add a placement-bearing representation rather than relying on `custom_secs` order alone.
- **Only one `name` section is accepted.** Duplicate `name` custom sections are rejected during module decode.
- **Raw name payload reuse is conditional.** Preserve it only when no pass or API call has structurally rewritten names or referenced index spaces.
- **The official subsection set is smaller than Starshine's local map.** Current primary sources standardize `0`, `1`, `2`, `4`, `10`, and `11`; Starshine-local id `3` covers label names and ids `5` through `9` cover table, memory, global, element, and data names. Do not add new subsection ids or remove the local-extension caveat without refreshing primary sources and extending decode/encode/validation tests together.
- **Name maps are not uniqueness maps for strings.** Indices must be unique and ordered; name strings themselves may repeat. `[FUZ]1020G1` classifies ordering and count corruption as binary-invalid rather than AST-invalid work: serialized counts are byte framing, and out-of-order `NameMap` / `IndirectNameMap` arrays trip `InvalidNameMapOrder` in `src/binary/decode.mbt` / `src/binary/encode.mbt` before yielding a decode-accepted validation specimen. `[FUZ]1020G1` classifies ordering/count failures as binary/codec-invalid rather than AST-invalid: `NameMap` and `IndirectNameMap` arrays can be built in memory, but encode rejects non-increasing indices with `InvalidNameMapOrder`, decode rejects malformed ordered/count payloads before validation, and `validate_name_sec(...)` owns only structured index-space bounds once the codec has accepted the map shape.
- **WAST identifiers are a separate authoring layer.** Starshine currently promotes WAST function/import identifiers into `NameSec.func_names`, but local/type/table/memory/global/tag/element/data identifiers remain source-resolution aids unless a dedicated lowering path creates the corresponding structured name map.
- **Function annotations are not binary name sections.** `FuncAnnotationSec` is a Starshine WAST/in-memory metadata lane today; the binary codec does not encode or decode it. Route code-metadata, inline-hint, branch-hint, and no-inline-marker details through [`../wast/code-metadata-and-function-annotations.md`](../wast/code-metadata-and-function-annotations.md).
- **Function names depend on absolute function-index stability.** See [`function-import-export-and-code-sections.md`](function-import-export-and-code-sections.md) for the imported-prefix `FuncIdx` model that function name maps describe.
- **Type/table/memory/global/tag names depend on imported-prefix or definition-order stability.** See [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) for the shared type and module resource index-space contract.
- **Element/data names depend on segment-index stability.** See [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md) for the canonical segment model that those name maps describe.

## Sources

- Label-subsection correction: [`../raw/wasm/2026-05-20-name-section-label-subsection-correction.md`](../raw/wasm/2026-05-20-name-section-label-subsection-correction.md)
- Earlier table/memory/global/element/data correction, now superseded for the label-subsection detail: [`../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md`](../raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md)
- Earlier superseded source snapshot: [`../raw/wasm/2026-05-13-custom-and-name-section-sources.md`](../raw/wasm/2026-05-13-custom-and-name-section-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/module.mbt`](../../../src/lib/module.mbt)
- Decode and encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation and invalid generation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt), [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md)
- Related docs: [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md`](../binaryen/passes/strip-target-features/starshine-port-readiness-and-validation.md)
