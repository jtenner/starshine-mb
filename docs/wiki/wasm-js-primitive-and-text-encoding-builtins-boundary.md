---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-js-primitive-text-encoding-builtins-boundary-refresh.md
  - raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md
  - raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - wasm-js-string-builtins-boundary.md
  - wast/string-instruction-authoring.md
  - tooling/node-package-surface.md
  - ../../node/internal/runtime.js
  - ../../src/lib/types.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
related:
  - wasm-js-string-builtins-boundary.md
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/string-instruction-authoring.md
  - strings/string-const-surface.md
  - tooling/node-package-surface.md
  - wasm-esm-integration-boundary.md
  - binaryen/passes/string-lowering/index.md
  - binaryen/passes/string-lifting/index.md
---

# JS Primitive And Text Encoding Builtins Boundary

## Overview

Use this page when a wiki claim mentions **JS Primitive Builtins**, **JS Text Encoding Builtins**, `wasm:js-number`, `wasm:js-bigint`, `wasm:text-encoding`, host `TextEncoder` / `TextDecoder`-style helpers, or anything that sounds like “more JS builtins than `js-string`.”

The short rule is:

- **JS String Builtins** is already a finished/Core-3.0 + JavaScript API feature, and Starshine's current Node wasm-gc wrapper opts into it with `builtins: ["js-string"]`.
- **JS Primitive Builtins** is still an active Phase-2 proposal. It extends the JavaScript builtin-import idea to primitive JS values such as numbers, booleans, `undefined`, symbols, and BigInts.
- **JS Text Encoding Builtins** is still an active Phase-1 proposal. It proposes host builtins for UTF-8 encode/decode between JavaScript strings and Wasm storage.
- **Starshine has no documented support for JS Primitive Builtins or JS Text Encoding Builtins today.** Current local string instructions are a narrow Reference-Typed Strings / `stringref` subset, not these host-builtin proposal APIs.

The current source bridge is [`raw/wasm/2026-06-05-js-primitive-text-encoding-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-primitive-text-encoding-builtins-boundary-refresh.md). It rechecked the official WebAssembly proposals tracker, the two proposal overviews, the existing JS String Builtins boundary, and current Starshine Node/WAST/core/binary/validator evidence.

## Beginner Mental Model

Think of the three JavaScript builtin families as host-side shortcuts with different maturity:

1. **JS String Builtins** lets a Wasm module import known string helper functions from the reserved `wasm:js-string` namespace when the JavaScript host enables the `js-string` builtin option.
2. **JS Primitive Builtins** would add helper namespaces for primitive JavaScript values, such as numbers and BigInts, so Wasm could call into host-provided primitive operations through reserved imports.
3. **JS Text Encoding Builtins** would add text-encoding helper imports under `wasm:text-encoding`, so Wasm could ask the JavaScript host to encode, measure, or decode UTF-8 using JS strings and Wasm memory or GC arrays.

Those are not the same as Starshine's current in-module `stringref` instructions. For example, Starshine's `string.encode_utf8_array` consumes a Wasm `stringref` plus a mutable GC array and returns an `i32`. The JS Text Encoding proposal's UTF-8 helpers are host builtins that bridge JavaScript strings and Wasm storage through reserved imports. Similar names, different layer.

## Surface Matrix

| Surface | Standards status checked 2026-06-05 | What it means | Current Starshine status | Do not infer |
| --- | --- | --- | --- | --- |
| JS String Builtins | Finished/Core-3.0 + JavaScript API | Host-enabled `wasm:js-string` imports, `builtins: ["js-string"]`, and `importedStringConstants`. | Supported only at the Node wasm-gc wrapper layer via explicit compile/instantiate options; no local string-lowering/lifting pass is implemented. | That JS Primitive Builtins, JS Text Encoding Builtins, or the full `stringref` proposal are stable or locally supported. |
| JS Primitive Builtins | Active Phase 2 proposal | Reserved builtin namespaces such as `wasm:js-number`, `wasm:js-boolean`, `wasm:js-undefined`, `wasm:js-symbol`, and `wasm:js-bigint`, plus a small `wasm:js-string` numeric conversion extension set. | No repository evidence for runtime opt-in, helper imports, WAST/core/binary/validator support, generator gates, or pass handling. | That `externref` support or `builtins: ["js-string"]` implies primitive helper support. |
| JS Text Encoding Builtins | Active Phase 1 proposal | Reserved `wasm:text-encoding` helpers for UTF-8 decode, measure, and encode-into operations over JavaScript strings plus Wasm memory or GC arrays. | No repository evidence for `wasm:text-encoding` imports, host wrappers, WAST keywords, core instructions, binary opcodes, validator rules, generator gates, or pass handling. | That Starshine's current `string.new_*_array` / `string.encode_*_array` stringref instructions implement host text-encoding builtins. |
| Reference-Typed Strings / `stringref` | Active Phase 1 proposal | Wasm value/instruction family including `stringref`, `string.const`, a proposal string literal section, and many string operations. | Narrow local subset: `string.const`, selected array-backed new/encode helpers, `ValType::stringref()`, and local/proposal `StringRefsSec`; see [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md). | That host builtin namespaces or JavaScript compile options are present. |

## Current Starshine Map

### Node runtime

[`node/internal/runtime.js`](../../node/internal/runtime.js) is the current host-source anchor. It compiles and instantiates the internal wasm-gc artifact with:

```js
{ builtins: ["js-string"] }
```

That is only JS String Builtins evidence. Repository search found no current runtime option, import-object behavior, or helper namespace for JS Primitive Builtins or JS Text Encoding Builtins. If a future runtime slice adds these proposals, update this page, [`tooling/node-package-surface.md`](tooling/node-package-surface.md), package smoke tests, and release/runtime requirements together.

### WAST, core, binary, validation, and generator

Current Starshine string behavior belongs to the local/proposal-facing `stringref` surface:

- WAST keyword/parser/lowerer/printer support lives in [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt).
- Core instruction and value-type carriers live in [`src/lib/types.mbt`](../../src/lib/types.mbt).
- Binary encode/decode mirrors the active stringref proposal's local bytes in [`src/binary/encode.mbt`](../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../src/binary/decode.mbt).
- Static type rules live in [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt).

None of those source anchors models reserved JS primitive namespaces or `wasm:text-encoding` builtin imports. Do not widen WAST fixture guidance from `string.encode_utf8_array` to `wasm:text-encoding` without adding a separate representation and tests.

### Passes and Binaryen oracle work

Binaryen's string-lowering and string-lifting dossiers already depend on the finished `wasm:js-string` helper ABI. Future upstream or local work may mention JS primitive or text-encoding helper namespaces, but that would still need layer-specific evidence:

1. an official proposal/source recheck;
2. exact helper signatures and import namespaces;
3. Starshine runtime compile-option/import-object policy;
4. WAST/core/binary/validator/generator representation if the feature becomes a local Wasm surface;
5. pass tests showing helper imports are synthesized, recognized, preserved, or rejected deliberately.

Until then, treat any such Binaryen or proposal example as **source-oracle evidence only**, not Starshine support.

## Correct Wording For Wiki Claims

Prefer these phrases:

- “JS Primitive Builtins is active Phase 2 and has no current Starshine support.”
- “JS Text Encoding Builtins is active Phase 1 and is separate from Starshine's current `stringref` array-helper instructions.”
- “Starshine's Node wasm-gc wrapper opts into `js-string` only; it does not currently enable or model JS Primitive Builtins or JS Text Encoding Builtins.”
- “`string.encode_utf8_array` is a Wasm stringref-proposal instruction in Starshine, not a `wasm:text-encoding` host builtin import.”

Avoid these phrases unless the surrounding sentence names the exact layer:

- “Starshine supports JS builtins” — say whether you mean JS String Builtins compile options, primitive builtins, text-encoding builtins, or Binaryen helper imports.
- “Text encoding is supported because `string.encode_utf8_array` exists” — host `wasm:text-encoding` builtins and local stringref array encoders are different surfaces.
- “Primitive builtins are covered by `externref`” — a generic reference type is not support for reserved helper namespaces, compile options, or proposal helper signatures.

## Implementation And Signoff Guidance

If Starshine implements either proposal later:

1. Start at the JavaScript package/runtime boundary: compile options, import-object behavior, public API docs, package smoke tests, and runtime version requirements.
2. Decide whether the feature is only a host helper-import ABI or also a WAST/core/binary/validator surface.
3. Add exact helper namespace/signature tests before adding optimizer rewrites that synthesize or consume those imports.
4. Keep `js-string`, JS primitive, text-encoding, and `stringref` rows separate in feature-status docs and fuzzer feature gates.
5. Run module validation and Node/runtime smoke tests; run Binaryen oracle lanes only after classifying them as upstream behavior, not as the local contract.

## Sources

- Boundary refresh: [`raw/wasm/2026-06-05-js-primitive-text-encoding-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-primitive-text-encoding-builtins-boundary-refresh.md)
- JS String Builtins boundary: [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md), [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md)
- Stringref/local instruction pages: [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`strings/string-const-surface.md`](strings/string-const-surface.md), [`raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](raw/wasm/2026-06-04-stringref-proposal-current-refresh.md)
- Node/package page: [`tooling/node-package-surface.md`](tooling/node-package-surface.md), [`../../node/internal/runtime.js`](../../node/internal/runtime.js)
- Binaryen string pass dossiers: [`binaryen/passes/string-lowering/index.md`](binaryen/passes/string-lowering/index.md), [`binaryen/passes/string-lifting/index.md`](binaryen/passes/string-lifting/index.md)
