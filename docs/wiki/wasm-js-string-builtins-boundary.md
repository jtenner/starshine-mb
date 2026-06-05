---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md
  - raw/wasm/2026-06-05-esm-integration-boundary-refresh.md
  - raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md
  - strings/string-const-surface.md
  - wast/string-instruction-authoring.md
  - tooling/node-package-surface.md
  - binaryen/passes/string-lowering/index.md
  - binaryen/passes/string-lifting/index.md
  - ../../node/internal/runtime.js
  - ../../src/lib/types.mbt
  - ../../src/binary/encode.mbt
  - ../../src/binary/decode.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - strings/string-const-surface.md
  - wast/string-instruction-authoring.md
  - binary/type-table-memory-global-tag-sections.md
  - tooling/node-package-surface.md
  - wasm-esm-integration-boundary.md
  - binaryen/passes/string-gathering/index.md
  - binaryen/passes/string-lowering/index.md
  - binaryen/passes/string-lifting/index.md
---

# JS String Builtins Boundary

## Overview

Use this page when a wiki claim mentions any of these similar-looking names:

- **JS String Builtins**;
- `builtins: ["js-string"]`;
- imported helpers such as `(import "wasm:js-string" "concat" ...)`;
- `importedStringConstants`;
- `stringref`, `string.const`, or Starshine's `StringRefsSec`.

They are related string features, but they do **not** all mean the same thing. The current source bridge is [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md). It rechecked the official WebAssembly finished-proposals table, active proposals tracker, JS String Builtins draft, MDN JavaScript API pages for compile options and imported string constants, and current Starshine Node / WAST / binary / validator / pass evidence.

The durable rule is:

- **JS String Builtins** is a finished/Core-3.0 + JavaScript API feature boundary. It is about host-enabled builtin imports and compile options.
- **Reference-Typed Strings / `stringref`** is still an active Phase-1 proposal boundary. It is about `stringref`, `string.const`, a draft `stringrefs` section, and a much wider string instruction family.
- **Starshine** implements a narrow proposal-facing `stringref` subset plus Node runtime opt-in to JS string builtins; it does not implement the whole active stringref proposal, and it does not currently expose a `string-lowering` / `string-lifting` pass that translates through the JS builtin ABI.

## The Three Things People Conflate

| Surface | What it is | Current source status | Starshine status | Do not infer |
| --- | --- | --- | --- | --- |
| JS String Builtins | JavaScript API / host feature that lets Wasm import known JS string helper functions from the reserved `wasm:` namespace when compile options enable `"js-string"`; Node's Wasm ESM Integration path also enables them automatically for ESM-loaded Wasm. | Finished proposal affecting Core + JS API in WebAssembly 3.0; focused draft is `3.0 + js-string-builtins`. | The Node wasm-gc runtime calls `WebAssembly.compile(..., { builtins: ["js-string"] })` and `WebAssembly.instantiate(..., { builtins: ["js-string"] })` in [`node/internal/runtime.js`](../../node/internal/runtime.js). Current Starshine does not use source-phase or instance-phase Wasm ESM imports; route that split through [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md). | That `stringref` proposal instructions are stable Core, that Starshine rewrites modules to/from `wasm:js-string` helper imports, or that explicit Node wrapper compile options are the same evidence as Wasm ESM Integration support. |
| Imported string constants | JavaScript API compile option that chooses the namespace whose imported globals become JS strings from import names. | JS API / host behavior documented with `importedStringConstants`. | Current Node runtime does **not** pass `importedStringConstants`; Binaryen `string-lowering` / `string-lifting` dossiers document future JSON/magic-import behavior, but local Starshine has no active port. | That Starshine's `StringRefsSec` is the same mechanism. |
| Reference-Typed Strings / `stringref` | Active proposal with `stringref`, `string.const`, draft `stringrefs` section id `14`, array/memory string helpers, comparisons, views, and iterators. | Active Phase 1 as of the 2026-06-05 recheck. | Starshine supports `string.const`, eight array-backed helper instructions, `ValType::stringref()`, and local/proposal-facing `StringRefsSec` section id `14`; see [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md) and [`strings/string-const-surface.md`](strings/string-const-surface.md). | That JS String Builtins being finished makes the whole stringref proposal stable or locally complete. |

## Beginner Mental Model

Think of JS String Builtins as a **host import shortcut**. A module can import known helper functions such as `concat` from module name `wasm:js-string`, and JavaScript engines can wire those imports to builtin string operations when the caller enables the `js-string` compile option.

Think of `stringref` as a **Wasm value and instruction family**. It gives modules string-typed values and operations such as `string.const`, array-backed constructors, and encoders. Starshine's local model currently lives here: it parses and validates a small subset and uses a local/proposal-shaped `StringRefsSec` to encode literal bytes for `string.const`.

Think of `importedStringConstants` as a **host-created imported-global mechanism**. Instead of storing literal bytes in a module-local `StringRefsSec`, the module imports globals from a chosen namespace, and the JavaScript host creates JS string values from the import names.

Those three can appear in one lowering/lifting workflow, but they are different layers:

```text
Starshine-local string.const / StringRefsSec
  -> future string-lowering could rewrite to imported globals and wasm:js-string helper calls
  -> JavaScript host compiles/instantiates with builtins: ["js-string"]
  -> optional importedStringConstants creates host string constants
```

## Current Starshine Map

### Node runtime

[`node/internal/runtime.js`](../../node/internal/runtime.js) is the current local host evidence. It loads `starshine.wasm-gc.wasm`, compiles with:

```js
{ builtins: ["js-string"] }
```

and instantiates with the same builtins option. That matches the Node package runtime requirement in [`node/README.md`](../../node/README.md): Node.js 25+ with WebAssembly GC and JS string builtins.

There is no current `importedStringConstants` option in that wrapper. If future package work adds it, update this page, [`tooling/node-package-surface.md`](tooling/node-package-surface.md), the release/package docs if package behavior changes, and the Binaryen string-lowering/lifting dossiers together.

Also keep ESM Integration separate from this direct-wrapper evidence. Node documents automatic JS String Builtins enablement for ESM-loaded Wasm modules, but current Starshine does not import its internal adapter or user modules with source-phase `import source`, dynamic `import.source(...)`, or instance-phase `.wasm` namespace imports. Use [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md) whenever a string-builtins claim depends on Wasm participating in a JavaScript module graph rather than on explicit `WebAssembly.compile(...)` options.

### WAST, core, binary, and validation

The current local instruction surface belongs to the active stringref proposal subset, not to JS builtins:

- WAST registers `string.const` plus eight array-backed helpers in [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt) and parses/lowers/prints them through [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt).
- Core types model `StringConst(Bytes)`, helper opcodes, and `ValType::stringref()` in [`src/lib/types.mbt`](../../src/lib/types.mbt).
- Binary encode/decode uses local/proposal-shaped section id `14` for `StringRefsSec` plus `0xFB` string helper opcodes in [`src/binary/encode.mbt`](../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../src/binary/decode.mbt).
- Validation checks stack, array storage width, and destination mutability in [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt).

Use [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md) for stack shapes and WAST fixture guidance. Use [`strings/string-const-surface.md`](strings/string-const-surface.md) and [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md) when the question is specifically about literal-pool identity or `StringRefsSec` section ordering.

### Passes and Binaryen parity

Starshine's active [`string-gathering`](binaryen/passes/string-gathering/index.md) pass hoists repeated local `string.const` literals into immutable string globals. That is still Starshine-local stringref/stringrefs plumbing.

Binaryen's [`string-lowering`](binaryen/passes/string-lowering/index.md) and [`string-lifting`](binaryen/passes/string-lifting/index.md) are the places where the JS builtin ABI matters most:

- `string-lowering` lowers Wasm string values to externref-shaped imports, helper calls, and optional `string.consts` metadata or magic imports.
- `string-lifting` recognizes imported constants and exact `wasm:js-string` helper imports, then lifts them back to Wasm string instructions.

Those passes are still upstream-only or future-port surfaces for Starshine. A future port should recheck this JS builtins boundary before freezing helper signatures, compile-option assumptions, imported-constant namespaces, or fatal/warning policy for malformed helper imports.

## Correct Wording For Wiki Claims

Prefer these phrases:

- “JS String Builtins is a finished WebAssembly 3.0 / JS API feature; Starshine's Node wasm-gc wrapper opts into it with `builtins: ["js-string"]`.”
- “Reference-Typed Strings remains active Phase 1; Starshine implements only a narrow proposal-facing `stringref` subset.”
- “`StringRefsSec` is Starshine's local/proposal-facing in-module literal pool for `string.const`; it is not the JS API `importedStringConstants` mechanism.”
- “`wasm:js-string` helper imports belong to JS String Builtins and Binaryen string-lowering/lifting parity work, not to ordinary WAST string instruction support.”

Avoid these phrases unless the surrounding sentence is more precise:

- “Wasm strings are stable” — too broad; JS builtins are finished, but Reference-Typed Strings is active.
- “Starshine supports JS strings” — name whether you mean Node compile options, local `stringref` instructions, or future helper-import lowering.
- “Section 14 is a Core `stringrefs` section” — current Starshine mirrors an active proposal draft, but current Core WebAssembly 3.0 does not stabilize that section.
- “`importedStringConstants` is like `StringRefsSec`” — one is host/import-based, the other is in-module local/proposal binary plumbing.

## Validation And Maintenance Guidance

When touching string-related docs or code:

1. **Name the layer first:** JS API builtins, imported constants, stringref proposal, Starshine local binary section, WAST text, validator, generator, Node runtime, or Binaryen pass.
2. **Use the focused owner page:** WAST stack/storage goes to [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md); literal pools go to [`strings/string-const-surface.md`](strings/string-const-surface.md); JS builtin ABI lowering/lifting goes to the Binaryen pass dossiers.
3. **Keep source-status split visible:** finished JS String Builtins does not supersede active Reference-Typed Strings.
4. **For Node runtime changes:** update [`tooling/node-package-surface.md`](tooling/node-package-surface.md), package tests, and release docs if the published runtime requirement or compile options change.
5. **For pass work:** validate output modules, run focused Binaryen oracle fixtures for string-lowering/lifting when available, and do not remove string features or metadata before all string-typed surfaces are repaired.

## Sources

- JS String Builtins boundary refresh: [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md)
- Stringref proposal/local refresh: [`raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](raw/wasm/2026-06-04-stringref-proposal-current-refresh.md)
- Older section-id caveat: [`raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md`](raw/wasm/2026-05-13-type-table-memory-global-tag-sources.md)
- ESM Integration boundary refresh: [`raw/wasm/2026-06-05-esm-integration-boundary-refresh.md`](raw/wasm/2026-06-05-esm-integration-boundary-refresh.md), [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md)
- Focused local pages: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), [`strings/string-const-surface.md`](strings/string-const-surface.md), [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md), [`tooling/node-package-surface.md`](tooling/node-package-surface.md)
- Binaryen pass dossiers: [`binaryen/passes/string-gathering/index.md`](binaryen/passes/string-gathering/index.md), [`binaryen/passes/string-lowering/index.md`](binaryen/passes/string-lowering/index.md), [`binaryen/passes/string-lifting/index.md`](binaryen/passes/string-lifting/index.md)
- Local source anchors: [`../../node/internal/runtime.js`](../../node/internal/runtime.js), [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt)
