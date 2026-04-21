---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md
  - ../string-gathering/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./json-and-magic-imports.md
  - ../string-gathering/index.md
  - ../../../strings/string-const-surface.md
  - ../tracker.md
---

# `string-lowering`

## Role

- `string-lowering` is an upstream-only Binaryen module / boundary pass.
- It is currently **unimplemented** in Starshine.
- It is a real public pass in Binaryen `version_129`, but it is **not** part of the ordinary no-DWARF default optimize path tracked in this repo.
- Its job is to take wasm-string-using modules and lower the supported string surface into imports, `externref`-based types, and optional custom-section metadata.

## Why this dossier exists

The tracker no longer had an obvious `wiki status = none` candidate in the ordinary parity queue, but the existing `string-gathering` folder still had a real teaching gap around its larger sibling.

Without a dedicated `string-lowering` folder, it was too easy to blur together three different ideas:

- `string-gathering`
- `string-lowering`
- `string-lifting`

This dossier exists to make the actual `version_129` split explicit.

## Why it matters

Even though `string-lowering` is not in the repo's current no-DWARF optimize path, it still matters because:

- Binaryen exposes it as a real public pass name.
- `StringLowering.cpp` makes `string-gathering` just the first phase of it.
- It changes ABI-visible types, imports, globals, custom sections, and feature flags.
- The existing string docs in this repo repeatedly mention it as the next layer beyond literal gathering.

There is **no dedicated `string-lowering` slice** in the current `agent-todo.md`; this folder is therefore tracker expansion for an upstream-only teaching gap, not a direct implementation handoff.

## Beginner summary

A good beginner model is:

1. gather every `string.const` into canonical globals first,
2. turn string types into `externref`-shaped types,
3. replace defining string globals with imports,
4. lower supported string instructions into imported helper calls,
5. refinalize,
6. then disable the Strings feature.

That is much more accurate than saying either:

- "it only hoists string constants", or
- "it lowers every string proposal instruction".

## Current durable takeaways

- `string-lowering` literally subclasses and runs `StringGathering` first.
- The pass is whole-module, not function-local.
- The default mode stores string payloads in a `string.consts` JSON custom section and imports globals from module `"string.const"` with numbered bases.
- The magic-import variants try to encode well-formed strings directly as import names instead.
- Invalid / non-usable strings still fall back to JSON in plain magic-import mode.
- The assert variant makes those invalid strings fatal.
- Binaryen lowers `HeapType::string` to `HeapType::ext`, preserving nullability.
- Public singleton-rec-group function types are handled specially before `TypeMapper`; the file has an explicit TODO for broader public-type cases.
- The supported op surface in `version_129` is narrow and explicit, not universal. Some `string.new*` and `string.encode*` variants still hit upstream `TODO` / `WASM_UNREACHABLE` paths.
- After lowering, Binaryen runs `ReFinalize()` and disables `FeatureSet::Strings`.
- A direct source check found no visible drift in `main/src/passes/StringLowering.cpp` on the checked surfaces.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: scheduler facts, phase-by-phase algorithm, type rewrite contract, helper import surface, and current negative boundaries.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for `StringLowering.cpp`, `pass.cpp`, `string-gathering.wast`, `string-lowering.wast`, and `string-lowering.js`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT catalog covering gathered literals, externref signatures, helper-call rewrites, unsupported-family boundaries, and preserved shapes.
- [`./json-and-magic-imports.md`](./json-and-magic-imports.md)
  Focused guide to the most non-obvious part of the pass: numbered `string.const` imports vs magic imports, custom-section JSON encoding, invalid-string fallback, and assert-mode failure.

## Current maintenance rule

- Treat this folder as the canonical home for future `string-lowering` research.
- Keep it explicitly marked as **upstream-only** unless Starshine grows a real module pass for this surface.
- Keep the split from `string-gathering` and `string-lifting` explicit in future edits.

## Sources

- [`../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md`](../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md)
- [`../string-gathering/index.md`](../string-gathering/index.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
- Current `main` drift check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
