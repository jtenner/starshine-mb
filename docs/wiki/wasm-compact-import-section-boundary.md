---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - raw/wasm/2026-07-10-compact-import-section-boundary-recheck.md
  - raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/module_wast.mbt
  - ../../src/validate/validate.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - binary/module-section-map.md
  - binary/function-import-export-and-code-sections.md
  - wast/function-call-and-module-authoring.md
  - wast/resource-declaration-authoring.md
  - validate/import-export-and-external-type-matching.md
---

# WebAssembly Compact Import Section Boundary

## Overview

**Compact Import Section** is an active **Phase-3** WebAssembly proposal that makes repeated imports smaller. It changes how imports are encoded in binary and written in WAT; it does **not** add a new kind of imported object, change index spaces, or change ordinary import validation/execution semantics. The current official tracker and proposal overview are captured in [`raw/wasm/2026-07-10-compact-import-section-boundary-recheck.md`](raw/wasm/2026-07-10-compact-import-section-boundary-recheck.md).

For a beginner, a normal import repeats its module name every time:

```wat
(module
  (import "env" "log" (func))
  (import "env" "abort" (func))
  (import "env" "memory" (memory 1)))
```

The proposal lets a module name be written once for a group. It also has a more compact form when every item in the group has the same external type:

```wat
;; Group by module.
(module
  (import "env"
    ("log" (func))
    ("abort" (func))
    ("memory" (memory 1))))

;; Group by module and external type.
(module
  (import "env" (func)
    "log"
    "abort"))
```

Those forms are **not current Starshine WAST syntax**. Use the ordinary one-item form today.

## What Changes — And What Does Not

| Concern | Proposal effect | Starshine implication today |
| --- | --- | --- |
| Import semantics | None. Each group expands to the same ordered list of `(module name, item name, external type)` imports. | Existing `ImportSec(Array[Import])` is a suitable semantic target. |
| Function/table/memory/global/tag index spaces | None. Imported entries remain the prefix of their respective index spaces. | Existing validator/index rules remain the authority. |
| Binary encoding | Adds two compact import encodings that avoid repeating a module name and optionally an external type. Existing entries remain valid. | Binary decode/encode has no compact grammar or emission policy. |
| WAT syntax | Adds grouped import forms. | Parser and printer only handle the existing one-item form. |
| Validation/execution | No new rule beyond ordinary import validation. | `validate_importsec(...)` can operate after a compact form has been expanded into flat imports. |
| Byte-for-byte round trip | A flat semantic model cannot tell whether source bytes used the ordinary or a compact form. | Current Starshine cannot preserve compact grouping because it does not model it. |

The proposal uses the existing import section rather than allocating another standard section. Its compact wire forms use an empty second name and a sentinel where a conventional import carries an external-type byte: `0x7F` for a group that shares a module name and `0x7E` for a group that shares both module name and external type. Old decoders fail rather than silently interpreting these as ordinary imports. See the immutable source bridge for exact grammar links and the proposal's modified specification entry point.

## Current Starshine Boundary

### Core representation and binary codec

Starshine's semantic import is deliberately simple:

```text
ImportSec = ordered Array[Import]
Import    = (module_name, field_name, extern_type)
```

That representation is defined by [`Import`](../../src/lib/types.mbt#L218) and [`ImportSec`](../../src/lib/types.mbt#L430). It already has the right *semantic* shape for a future compact decoder: decode a group, expand it to ordinary `Import` values in source order, and keep the rest of the module pipeline unchanged.

However, the current binary codec accepts and emits only the Core flat form:

- [`Decode for Import`](../../src/binary/decode.mbt#L1935-L1948) reads two names and one `ExternType`.
- [`Decode for ExternType`](../../src/binary/decode.mbt#L2023-L2051) recognizes the current function/table/memory/global/tag headers, not compact sentinels `0x7F` and `0x7E`.
- [`Decode for ImportSec`](../../src/binary/decode.mbt#L2145-L2150) treats section `2` as a vector of those ordinary imports.
- [`Encode for ImportSec`](../../src/binary/encode.mbt#L1145-L1147) and [`Encode for Import`](../../src/binary/encode.mbt#L1149-L1161) always write the ordinary vector/triple form.

Therefore, compact-input bytes are a **proposal gap** today, not malformed ordinary import evidence and not a validator disagreement. The ordinary import section is still the correct fixture surface for current Starshine behavior.

### WAT text and validation

[`parse_import(...)`](../../src/wast/parser.mbt#L2942-L3008) requires exactly the ordinary `(import "module" "field" (descriptor))` layout. [`module_to_wast`](../../src/wast/module_wast.mbt#L876-L918) prints each `ImportField` in that same flat layout. Neither AST has a group node or remembers that consecutive imports shared a module/type.

After decoding or lowering produces flat imports, the ordinary validation path already applies: [`validate_importsec(...)`](../../src/validate/validate.mbt#L1931-L1970) validates each external type and extends the appropriate imported prefix in source order. The proposal's no-semantic-change rule means a future compact implementation should not introduce a separate validator mode or alternate index-space algorithm.

## Design and Implementation Guidance

A future port should keep three decisions separate.

1. **Decode widening.** Recognize each proposal form, expand it to the existing flat `ImportSec`, and add byte fixtures that prove source order and external types survive. The decoder must reject truncated group payloads and invalid sentinels without accidentally treating them as ordinary external types.
2. **WAT widening.** Add an explicit grouped-import AST/parser/printer policy. Do not infer a compact source group merely because adjacent flat imports share names or types; that would silently rewrite user source style.
3. **Encode policy.** Decide explicitly whether `Encode for Module` remains Core-flat, opportunistically emits compact runs, or receives source-format metadata. With today's `Array[Import]`, byte-for-byte compact-input preservation is impossible. A size-oriented canonical encoder might compact eligible runs, but that is an output-policy choice that needs size, compatibility, and Binaryen/tool evidence—not a consequence of semantic equivalence.

### Suggested tests and signoff

| Layer | Required proof |
| --- | --- |
| Binary decode | One fixture for each compact form; mixed ordinary/compact imports; grouped functions/tables/memories/globals/tags; malformed/truncated payloads; and order-sensitive imported-prefix checks. |
| Binary encode | Exact chosen output policy, including no accidental compaction of incompatible runs and documented handling of a decoded compact input. |
| WAT | Grouped positive forms, ordinary-form compatibility, malformed group diagnostics, printer policy, and source-id resolution after flattening. |
| Validation | Imported-prefix index behavior remains unchanged for calls, resource references, exports, and start targets. |
| Fuzzing | Add an explicit proposal feature gate only if generation can intentionally choose compact forms; ordinary imports must remain in portable/default profiles. |
| External tools | Classify acceptance failures as proposal/tool gaps unless a current upstream source says the feature is finished; do not call them Starshine semantic mismatches. |

## Related Boundaries

- [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) owns the shared Core/finished/active-proposal vocabulary.
- [`binary/module-section-map.md`](binary/module-section-map.md) owns standard section order and pass-level cross-section repair.
- [`binary/function-import-export-and-code-sections.md`](binary/function-import-export-and-code-sections.md) owns imported-prefix function indexing, import validation order, and rewrite obligations.
- [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md) and [`wast/resource-declaration-authoring.md`](wast/resource-declaration-authoring.md) own today's ordinary import fixture syntax.
- [`validate/import-export-and-external-type-matching.md`](validate/import-export-and-external-type-matching.md) owns current import/export type-validation and host-linking boundaries.

## Sources

- Focused current-source bridge: [`raw/wasm/2026-07-10-compact-import-section-boundary-recheck.md`](raw/wasm/2026-07-10-compact-import-section-boundary-recheck.md)
- Shared Core/proposal source bridge: [`raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md`](raw/wasm/2026-07-10-webassembly-core3-proposal-dashboard-recheck.md)
- Core import model and codec: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt)
- WAT and validation: [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt)
