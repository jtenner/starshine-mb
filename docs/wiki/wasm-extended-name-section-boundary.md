---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md
  - raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md
  - raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md
  - raw/wasm/2026-05-20-name-section-label-subsection-correction.md
  - raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/validate.mbt
  - ../../src/fuzz/metamorphic.mbt
related:
  - binary/custom-and-name-sections.md
  - wast/identifier-name-and-annotation-authoring.md
  - wasm-feature-status-and-proposal-boundaries.md
  - validate/local-spec-divergence-ledger.md
  - fuzzing/generator-coverage-ledger.md
---

# Wasm Extended Name Section Boundary

## Overview

The **WebAssembly name section** is debug metadata carried in a custom section named `name`. It helps tools print readable module, function, local, type, field, and tag names, but it does not decide validation semantics: validation still uses numeric indices and typed operands. The current Core 3.0 custom/name appendix documents subsection ids `0` module, `1` function, `2` local, `4` type, `10` field, and `11` tag.

The active **Extended Name Section** proposal adds the missing debug-name maps many tools want for other index spaces: `3` label names, `5` table names, `6` memory names, `7` global names, `8` element segment names, and `9` data segment names. The current primary-source bridge is [`raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md`](raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md), which rechecked the WebAssembly proposals tracker, proposal overview, Core 3.0 appendix, feature dashboard evidence tier, and Starshine source locations.

Starshine already has structured support for exactly those extra ids. That is useful, but the wording matters: until the proposal is finished and incorporated into Core, document Starshine as having **proposal-facing/local structured metadata support** for ids `3` and `5..9`, not finished/Core Extended Name Section support.

## Beginner Model

A wasm binary can contain many custom sections. Most custom sections are opaque bytes that tools may ignore. The `name` custom section is special because tools agree on a structured payload:

```text
custom section id 0
  name string: "name"
  payload:
    subsection 0: module name
    subsection 1: function name map
    subsection 2: local name map
    ...
```

A name map says "index `N` has debug name `x`". It does **not** create a new import, function, table, memory, or local. For example, a function-name entry can make diagnostics print `main`, but a `call` instruction still targets a numeric function index after text lowering.

The extended proposal fills in the same debug-name idea for resource spaces that Core 3.0 does not currently list in the name-section appendix. A table name helps a printer or debugger show `table $tab`; it does not change table typing, limits, element segments, or `call_indirect` validity.

## Subsection Matrix

| Subsection id | Name map | Current Core 3.0 appendix | Extended Name Section proposal | Current Starshine behavior |
| --- | --- | --- | --- | --- |
| `0` | module name | Listed | Inherited baseline | `NameSec.module_name` decoded/encoded/validated. |
| `1` | function names | Listed | Inherited baseline | `NameSec.func_names`; WAST function/import ids can lower into this map. |
| `2` | local names | Listed | Inherited baseline | `NameSec.local_names`; passes that rewrite locals must repair or clear these maps. |
| `3` | label names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.label_names`; validated against Starshine's function-wide structured-control label count. |
| `4` | type names | Listed | Inherited baseline | `NameSec.type_names`. |
| `5` | table names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.table_names`; used by structured metadata and print-selector paths. |
| `6` | memory names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.memory_names`. |
| `7` | global names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.global_names`; module passes that remap globals must repair it. |
| `8` | element segment names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.elem_names`. |
| `9` | data segment names | Not listed in current Core 3.0 appendix | Added by proposal | `NameSec.data_names`. |
| `10` | field names | Listed | Inherited baseline | `NameSec.field_names`; checked against struct fields. |
| `11` | tag names | Listed | Inherited baseline | `NameSec.tag_names`. |

## Starshine Implementation Map

Starshine's in-memory metadata carrier is [`NameSec`](../../src/lib/types.mbt), separate from ordinary opaque custom sections:

- [`Module.custom_secs`](../../src/lib/types.mbt) stores non-`name` custom sections.
- [`Module.name_sec`](../../src/lib/types.mbt) stores parsed structured name maps.
- [`Module.raw_name_sec_payload`](../../src/lib/types.mbt) preserves original name-section bytes only while no structured rewrite has invalidated them.

The binary codec and validator then enforce a local structured contract:

1. [`Decode for NameSec`](../../src/binary/decode.mbt) accepts subsection ids `0..11`, including the extended/proposal-facing ids `3` and `5..9`; it rejects unknown ids and out-of-order subsections.
2. [`Encode for NameSec`](../../src/binary/encode.mbt) emits the same maps when Starshine serializes a structured name section instead of reusing `raw_name_sec_payload`.
3. [`validate_name_sec(...)`](../../src/validate/validate.mbt) checks map indices against the corresponding Starshine index spaces. This is stricter than Core's general "custom sections can be ignored" posture because Starshine intentionally gives structured name metadata a typed local representation.
4. [`src/fuzz/metamorphic.mbt`](../../src/fuzz/metamorphic.mbt), valid generators, and invalid-binary tests cover structured name-section additions and corruptions.

This means a Starshine-emitted module can contain name subsections that are active-proposal/local metadata from the standards point of view. That is not a semantic mismatch by itself, but external tools with strict Core-only name-section parsers may treat ids `3` and `5..9` differently.

## Label Names Are Not Branch Label Operands

The proposal's label-name subsection uses a function-wide label index space based on structured control instructions. Starshine's current validation mirrors that idea locally: [`validate_name_sec_total_labels(...)`](../../src/validate/validate.mbt) counts block, loop, if, and try-style structured labels inside one function before checking `NameSec.label_names` entries.

Do not confuse that metadata index with branch depths or source `$label` resolution:

```wat
(block $outer
  (loop $inner
    br 1))
```

The branch operand `1` means "break to the enclosing label one level out" in the instruction's scoped control stack. A label-name subsection entry is instead metadata for a numbered structured-control occurrence in a function. A pass that rewrites control structure must preserve validation and branch targets first; if it also preserves label-name metadata, it must update or clear the metadata map separately.

## Operational Guidance

Use this boundary when changing or reviewing name-section behavior:

- **Core/finished claims:** cite the Core 3.0 custom/name appendix for ids `0`, `1`, `2`, `4`, `10`, and `11`.
- **Extended ids:** cite the Extended Name Section proposal and this page for ids `3` and `5..9`.
- **Starshine local behavior:** cite `NameSec`, binary decode/encode, `validate_name_sec(...)`, generator/fuzz tests, and pass-specific remap tests.
- **WAST source identifiers:** keep `$id` resolution on [`wast/identifier-name-and-annotation-authoring.md`](wast/identifier-name-and-annotation-authoring.md); only selected lowered names become `NameSec` maps today.
- **Custom-section placement:** keep ordinary custom-section ordering and raw-payload preservation details on [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md).

Future strict-mode or feature-gate work should explicitly decide what to do with ids `3` and `5..9`: accept as local compatibility metadata, preserve raw but avoid structured emission, reject under a strict Core profile, or gate behind an Extended Name Section feature flag. Do not silently change this behavior in a pass or printer.

## Edge Cases And Invariants

- **Metadata is non-semantic.** Name maps may improve diagnostics and printing, but they do not change module validity except through Starshine's local structured metadata checks.
- **Starshine emits extended/local maps today.** Treat this as a known local compatibility behavior, not accidental finished-proposal support.
- **Subsection ids stay ordered.** Decode rejects out-of-order structured name subsections; encode must keep increasing ids.
- **Raw payload preservation ends after structured rewrite.** If a pass calls `with_name_sec(...)` or otherwise rewrites names, the old `raw_name_sec_payload` must not be reused.
- **Passes that remap index spaces own metadata repair.** Function, local, table, memory, global, tag, element, data, field, and control-label rewrites can make the wasm instruction layer valid while making structured names stale.
- **Feature dashboards are not proof.** Browser/runtime support tables can guide engine repros, but they do not replace proposal, Core, Starshine source, or exact external-validator command evidence.

## Sources

- Current Extended Name Section bridge: [`raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md`](raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md)
- Feature-dashboard evidence boundary: [`raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md`](raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md)
- Custom/name current refresh: [`raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md`](raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md)
- Earlier Core-vs-local corrections: [`raw/wasm/2026-05-20-name-section-label-subsection-correction.md`](raw/wasm/2026-05-20-name-section-label-subsection-correction.md), [`raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md`](raw/wasm/2026-05-20-custom-name-section-subsection-refresh.md)
- Starshine representation and codec: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/lib/module.mbt`](../../src/lib/module.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt)
- Starshine validation and fuzz evidence: [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt), [`../../src/fuzz/metamorphic.mbt`](../../src/fuzz/metamorphic.mbt), [`../../src/fuzz/invalid_binary_wbtest.mbt`](../../src/fuzz/invalid_binary_wbtest.mbt), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md)
- Related living pages: [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md), [`wast/identifier-name-and-annotation-authoring.md`](wast/identifier-name-and-annotation-authoring.md), [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), [`validate/local-spec-divergence-ledger.md`](validate/local-spec-divergence-ledger.md)
