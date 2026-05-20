# WebAssembly Custom And Name Section Subsection Refresh

- Capture date: 2026-05-20
- Source family: WebAssembly Core Specification 3.0 draft plus Starshine repository evidence
- Primary sources:
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (current as checked on 2026-05-20)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (current as checked on 2026-05-20)`: <https://webassembly.github.io/spec/core/appendix/custom>
- Corrects and supersedes the name-subsection takeaways in [`2026-05-13-custom-and-name-section-sources.md`](2026-05-13-custom-and-name-section-sources.md), which overclaimed that table, memory, global, element, and data name subsections are currently official WebAssembly 3.0 subsections.

## Durable takeaways

- Custom sections are binary section id `0`. They carry a UTF-8 name plus uninterpreted bytes, can appear at custom-section gaps around standard sections, and are semantically ignored by core WebAssembly.
- The dedicated `name` section is itself a custom section named `name`. The current custom-section appendix says it should appear at most once and after the data section, but it is still metadata rather than a semantic module section.
- The current WebAssembly 3.0 custom-section appendix defines the standard name-section subsection families as module `0`, function `1`, local `2`, label `3`, type `4`, field `10`, and tag `11`.
- The current appendix page checked on 2026-05-20 does **not** list table `5`, memory `6`, global `7`, element `8`, or data `9` name subsections as official WebAssembly 3.0 name-section families. Treat those Starshine maps as local compatibility / richer-metadata support until a refreshed primary source says otherwise.
- Name maps still use ordered unique indices; names are human-readable metadata and do not supply validation semantics for operands.
- Because core WebAssembly treats custom sections as metadata, do not cite Starshine's name-section decoding or validation failures as official semantic invalidity. They are local toolchain policy for a structured debug-metadata model.

## Starshine implications

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) currently models `NameSec` with the official current families plus local table, memory, global, element, and data name maps.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) accepts and decodes subsection ids `0` through `11` and rejects any other id as `InvalidNameSubsectionId`. This is broader than the current official name-section grammar for ids `5` through `9`, but narrower than a fully ignore-unknown custom-section policy.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) serializes local subsection ids `5` through `9` when the corresponding Starshine maps are present, so emitted modules can contain Starshine-local name-section metadata.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates the local extra name maps against table, memory, global, element, and data index spaces. This is useful for Starshine diagnostics and pass repair checks, but it is stricter than the official core rule that custom sections are ignored.
- The prior 2026-05-13 raw snapshot should remain immutable as historical input, but live pages should cite this refresh when distinguishing official name-section subsections from Starshine-local metadata.

## Follow-up questions

- Decide whether Starshine wants to keep accepting/emitting table, memory, global, element, and data name subsections as a deliberate compatibility extension, gate them behind a format option, or preserve them only through raw payload roundtrip.
- If Starshine wants closer spec behavior, consider decoding unknown or local name subsections as raw custom payload instead of rejecting the whole module.
- If a future WebAssembly source standardizes ids `5` through `9`, refresh this note and remove the local-extension caveat from the live pages.
