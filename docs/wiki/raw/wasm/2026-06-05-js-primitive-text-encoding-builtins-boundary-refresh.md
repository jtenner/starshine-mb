# JS Primitive And Text Encoding Builtins Boundary Refresh

- Capture date: 2026-06-05
- Source family: WebAssembly active-proposal tracker, JS Primitive Builtins proposal, JS Text Encoding Builtins proposal, existing JS String Builtins boundary, and current Starshine Node/WAST/string evidence

## Primary sources checked

1. WebAssembly proposals tracker, checked 2026-06-05: <https://github.com/WebAssembly/proposals>
   - `JS Primitive Builtins` is listed under Phase 2.
   - `JS Text Encoding Builtins` is listed under Phase 1.
   - Both rows are active proposals, not finished/Core rows.
2. JS Primitive Builtins proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/js-primitive-builtins/blob/main/proposals/js-primitive-builtins/Overview.md>
   - The proposal extends the JS builtin mechanism beyond strings to JS primitive values.
   - The proposed namespaces include `wasm:js-number`, `wasm:js-boolean`, `wasm:js-undefined`, `wasm:js-symbol`, and `wasm:js-bigint`, with a small extension set for `wasm:js-string` numeric-to-string conversions.
   - It still contains open design questions, such as exact externref/anyref routing and symbol-equality policy, so local docs should not freeze it as a stable ABI.
3. JS Text Encoding Builtins proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/js-text-encoding-builtins/blob/main/proposals/js-text-encoding-builtins/Overview.md>
   - The proposal adds `wasm:text-encoding` builtins for UTF-8 encode/decode between JavaScript strings and Wasm storage.
   - It covers GC-array and linear-memory forms, including decode, measure, and encode-into operations.
   - It explicitly points back to Reference-Typed Strings for WTF-16 user strings and notes an unresolved naming convention discussion for the `wasm:text-encoding` namespace.
4. Existing JS String Builtins boundary refresh: [`2026-06-05-js-string-builtins-boundary-refresh.md`](2026-06-05-js-string-builtins-boundary-refresh.md)
   - JS String Builtins is the finished/Core-3.0 + JavaScript API feature already used by Starshine's Node wasm-gc runtime via `builtins: ["js-string"]`.
   - That finished status does not carry over to JS Primitive Builtins or JS Text Encoding Builtins.

## Starshine repository evidence checked

- `node/internal/runtime.js` passes `builtins: ["js-string"]` to `WebAssembly.compile(...)` and `WebAssembly.instantiate(...)`, but repository search found no current `js-primitive`, `js-number`, `js-boolean`, `js-bigint`, `wasm:text-encoding`, `decodeStringFromUTF8*`, `measureStringAsUTF8`, or `encodeStringIntoUTF8*` runtime support.
- `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, and `src/validate/typecheck.mbt` model Starshine's current narrow Reference-Typed Strings subset: `string.const` plus array-backed `string.new_*_array` and `string.encode_*_array` helpers.
- That local stringref surface is not JS Text Encoding Builtins support: Starshine string helpers produce or consume `stringref`, not host `externref` JS strings from the proposed `wasm:text-encoding` namespace.
- Repository search found no current feature gate, validator route, WAST keyword, binary opcode, Node compile option, helper-import synthesis, or Binaryen-pass local port for either JS Primitive Builtins or JS Text Encoding Builtins.

## Durable conclusions

1. **JS Primitive Builtins and JS Text Encoding Builtins need their own active-proposal routing.** Do not hide them in the finished JS String Builtins page or in the active stringref subset.
2. **Starshine has no local support for these two proposals today.** The current Node wrapper opts into only `js-string`; the current WAST/core/binary/validator string helpers are stringref-proposal/local instructions, not reserved `wasm:` JS builtin imports.
3. **JS Text Encoding Builtins and Starshine `string.encode_utf8_array` are easy to confuse but different.** The proposal's builtins operate across host JS strings, GC arrays, or linear memory through `externref`-facing JavaScript builtin imports. Starshine's current `string.encode_utf8_array` consumes a `stringref` and a mutable GC array inside the Wasm instruction surface.
4. **Future Node/package work should treat builtins as host API surface first.** Adding these proposals would require explicit compile-option policy, import-object / helper-import handling, runtime tests, package docs, and feature-status routing before any WAST, binary, validator, or pass page claims local support.
5. **Future pass work must cite exact proposal and local layers.** A Binaryen string-lowering/lifting extension that recognizes `wasm:text-encoding` or JS primitive namespaces would still be upstream-oracle evidence until Starshine has matching parser/runtime/pass behavior.

## Follow-ups

- Add a focused living boundary page so string and Node-package readers can route JS Primitive Builtins and JS Text Encoding Builtins without bloating the JS String Builtins page.
- Refresh `wasm-feature-status-and-proposal-boundaries.md`, `wasm-js-string-builtins-boundary.md`, and `wast/string-instruction-authoring.md` so adjacent pages point at the new boundary.
- If the proposals move phases, change helper namespaces, or publish stable JS API compile-option names beyond `js-string`, update the boundary and Node package surface together.
