# WebAssembly Name Section Label Subsection Correction

- Capture date: 2026-05-20
- Source family: WebAssembly Core Specification 3.0 custom/name section appendix plus Starshine repository evidence
- Primary sources:
  - WebAssembly Core Specification, `Custom Sections and Annotations — WebAssembly 3.0 (current as checked on 2026-05-20)`: <https://webassembly.github.io/spec/core/appendix/custom>
  - Earlier Starshine manifest now corrected for this point: [`2026-05-20-custom-name-section-subsection-refresh.md`](2026-05-20-custom-name-section-subsection-refresh.md)

## Durable takeaways

- The current WebAssembly 3.0 custom-section appendix checked during this health pass lists standard name-section subsection ids for module `0`, function `1`, local `2`, type `4`, field `10`, and tag `11`.
- It does **not** list a standard label-name subsection id `3` on the checked current page. The earlier 2026-05-20 refresh correctly removed table/memory/global/element/data from the official set, but it still overclaimed `label` as official.
- Starshine still models, decodes, encodes, and validates `NameSec.label_names` as local structured metadata alongside table/memory/global/element/data name maps. Keep this as a local compatibility/richer-metadata surface unless a refreshed primary source standardizes it.
- The older 2026-05-13 raw snapshot remains historical input and overclaims ids `3`, `5`, `6`, `7`, `8`, and `9` as official WebAssembly 3.0 name subsections.
- Live wiki pages should treat ids `0`, `1`, `2`, `4`, `10`, and `11` as official in the current checked source, and ids `3`, `5`, `6`, `7`, `8`, and `9` as Starshine-local structured name maps.

## Starshine implications

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) owns `NameSec.label_names` in addition to local table/memory/global/element/data maps.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) accepts subsection ids `0..11`, including local id `3` for labels.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) can emit the local label-name subsection when present.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates label names against function and label bounds. This remains useful local diagnostics metadata but should not be cited as official core WebAssembly semantic invalidity.

## Follow-up questions

- Should Starshine keep label-name subsection id `3` as a long-lived compatibility extension, or preserve it only when decoded from existing modules?
- If the official custom/name appendix later reintroduces or standardizes label names, refresh this correction and reclassify id `3` from local to official.
