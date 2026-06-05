# Extended Name Section Boundary Refresh

- Capture date: 2026-06-05
- Source family: WebAssembly active proposal tracker, Extended Name Section proposal, Core 3.0 custom/name section appendix, and Starshine repository evidence
- Reason for capture: Starshine already accepts and emits name-section maps for labels, tables, memories, globals, element segments, and data segments. Those ids match the active Extended Name Section proposal, but they are not part of the current Core 3.0 name-section appendix. Living pages need to route that overlap as proposal-facing/local metadata rather than ordinary Core support.

## Primary sources checked

1. WebAssembly proposals tracker, checked 2026-06-05: <https://github.com/WebAssembly/proposals>
2. Extended Name Section proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/extended-name-section/blob/main/proposals/extended-name-section/Overview.md>
3. WebAssembly Core 3.0 custom/name section appendix, checked 2026-06-05: <https://webassembly.github.io/spec/core/appendix/custom>
4. WebAssembly feature-status dashboard, checked 2026-06-05 for implementation-status tier only: <https://webassembly.org/features/>

## Starshine repository evidence checked

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `NameSec` with official Core 3.0-style maps plus `label_names`, `table_names`, `memory_names`, `global_names`, `elem_names`, and `data_names`.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) decodes name subsection ids through `11`, including `3` and `5..9`, and rejects unknown ids / out-of-order subsections.
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) serializes the same structured maps when `raw_name_sec_payload` is not reused.
- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates structured name maps against Starshine's local index spaces, including the extended/local maps.
- [`../../../../src/fuzz/metamorphic.mbt`](../../../../src/fuzz/metamorphic.mbt) can add module, function, local, label, type, table, memory, global, data, element, tag, and field name-section maps as metamorphic metadata transforms.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt), [`../../../../src/validate/gen_invalid.mbt`](../../../../src/validate/gen_invalid.mbt), and [`../../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../../src/fuzz/invalid_binary_wbtest.mbt) provide generator and invalid-lane coverage for name/custom-section metadata.

## Durable takeaways

- The active proposals tracker currently lists **Extended Name Section** in Phase 2, with proposed spec text available. Treat that phase as standards-process routing, not finished/Core evidence.
- Current Core 3.0's name section is a custom section named `name` and currently lists subsection ids `0` module, `1` function, `2` local, `4` type, `10` field, and `11` tag. Core also says custom sections/annotations do not affect WebAssembly semantics and may be ignored by implementations.
- The Extended Name Section proposal adds exactly the ids Starshine has been documenting as local richer metadata: `3` label names, `5` table names, `6` memory names, `7` global names, `8` element segment names, and `9` data segment names.
- The proposal's label-name subsection uses a **function-wide label index space** ordered by structured-control-instruction occurrence. That is different from the scoped control-label indices used by branch operands.
- Starshine's current support is best described as **proposal-facing structured metadata support for subsection ids `3` and `5..9`**, not full finished/Core support. It accepts, validates, emits, fuzzes, and can remap these maps, but their official standardization status is still active-proposal Phase 2.
- Starshine does not currently implement a feature gate that distinguishes Core name subsections from extended proposal subsections. If future strict-Core or feature-gated modes are added, they must decide whether to reject, preserve raw, or separately gate ids `3` and `5..9`.
- The feature dashboard can show implementation availability, but it does not replace the proposal tracker, Core appendix, or local source evidence.

## Supersession and uncertainty

- This note sharpens, rather than deletes, the earlier 2026-05-20 corrections that called ids `3` and `5..9` Starshine-local. The new distinction is that those ids are also the current Extended Name Section proposal payload, so future docs should say "proposal-facing/local" instead of implying they have no standards-process home.
- Current Starshine emits these maps without a proposal feature bit. That is a deliberate compatibility/local metadata behavior until a future strict mode or proposal-gate design says otherwise.
- Recheck the active proposal tracker and proposal overview before changing decode/encode behavior or claiming finished/Core status for ids `3` and `5..9`.
