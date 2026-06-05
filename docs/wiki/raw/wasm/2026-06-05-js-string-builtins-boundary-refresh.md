# JS String Builtins Boundary Refresh

Capture date: 2026-06-05

Purpose: separate finished/Core-3.0 **JS String Builtins** / JavaScript API compile-option behavior from active Phase-1 **Reference-Typed Strings** / `stringref` instruction behavior, and map that distinction to Starshine's local string surfaces, Node runtime, and Binaryen string-lowering/lifting dossiers.

## Primary sources checked

1. WebAssembly finished proposals table: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>
   - Checked 2026-06-05.
   - Finding: `JS String Builtins` is listed as a finished proposal affecting `core, js-api` with spec version `3.0`.
   - Finding: the same table defines finished proposals as phase-4 proposals included in the latest draft specification. This makes JS String Builtins a finished/Core-3.0 and JS-API feature-status claim, not an active-proposal claim.
2. WebAssembly proposals tracker: <https://github.com/WebAssembly/proposals>
   - Checked 2026-06-05.
   - Finding: `Reference-Typed Strings` remains in Phase 1. `JS Primitive Builtins` is a separate Phase-2 active proposal, and `JS Text Encoding Builtins` is a separate Phase-1 active proposal.
   - Finding: do not use `JS String Builtins` as proof that the active `stringref` proposal, JS primitive builtins, or JS text-encoding builtins are stable or locally supported.
3. WebAssembly 3.0 + js-string-builtins draft: <https://webassembly.github.io/js-string-builtins/core/>
   - Checked 2026-06-05.
   - Finding: the draft identifies itself as `Release 3.0 + js-string-builtins (Draft 2025-06-25)` and links the JS String Builtins issue tracker. Use it as the focused draft/spec surface for builtin import rules when a page needs more detail than the finished-proposals row.
4. MDN `WebAssembly.compile()` reference: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/compile_static>
   - Checked 2026-06-05.
   - Finding: the JavaScript API accepts optional `compileOptions`; `builtins` enables JavaScript builtins in a compiled Wasm module and currently only documents `"js-string"`; `importedStringConstants` names the namespace for imported global string constants.
5. MDN WebAssembly JavaScript builtins guide: <https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/JavaScript_builtins>
   - Checked 2026-06-05.
   - Finding: builtins are imported from the reserved `wasm:` namespace, e.g. `(import "wasm:js-string" "concat" ...)`, and compile options are passed to compile, compileStreaming, instantiate, instantiateStreaming, validate, and the Module constructor.
   - Finding: builtin imports have stricter special-cased signature checks when the feature is enabled; feature detection can exploit the fact that a deliberately wrong builtin import validates without builtins but fails with builtins.
6. MDN imported global string constants guide: <https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/Imported_string_constants>
   - Checked 2026-06-05.
   - Finding: imported string constants are ordinary imported globals under the namespace named by `importedStringConstants`; the engine creates the strings from import names. This is a JS API / host compile-option behavior, not Starshine's local `StringRefsSec` literal-pool section.

## Starshine repository evidence checked

- `node/internal/runtime.js`
  - `instantiateWasmGc()` reads `starshine.wasm-gc.wasm`, calls `WebAssembly.compile(wasmBytes, { builtins: ["js-string"] })`, then calls `WebAssembly.instantiate(module, importObject, { builtins: ["js-string"] })`.
  - No `importedStringConstants` compile option is passed by the current Node runtime wrapper.
- `node/README.md`
  - Runtime requirement says Node.js 25+ with WebAssembly GC and JS string builtins.
- `src/lib/types.mbt`, `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`, and `src/validate/typecheck.mbt`
  - Starshine models and validates `string.const`, the eight array-backed `string.new_*_array` / `string.encode_*_array` helpers, `ValType::stringref()`, and local/proposal-facing `StringRefsSec` section id `14`.
  - These are still the narrow active-`stringref` proposal subset documented by `2026-06-04-stringref-proposal-current-refresh.md`, not a proof of host `wasm:js-string` builtin import handling.
- `src/passes/string_gathering.mbt`
  - Starshine has an active module pass for hoisting local `string.const` literals to immutable globals. That is local stringref/stringrefs plumbing, not JS builtin lowering.
- `docs/wiki/binaryen/passes/string-lowering/` and `docs/wiki/binaryen/passes/string-lifting/`
  - These dossiers already document Binaryen's `wasm:js-string` helper-import ABI and JSON/magic-import string-constant behavior as upstream-only or future-port surfaces in Starshine.

## Durable reconciliation

- Use **JS String Builtins** for the finished/Core-3.0 + JS API compile-option feature: `builtins: ["js-string"]`, reserved `wasm:js-string` helper imports, and optional `importedStringConstants` host-created imported globals.
- Use **Reference-Typed Strings / stringref** for the active Phase-1 proposal: `stringref`, `string.const`, the draft `stringrefs` section, and the wider string instruction family. Starshine implements only a narrow proposal-facing subset.
- Do not conflate JS String Builtins with `StringRefsSec`. `StringRefsSec` is an in-module literal pool that Starshine encodes/decodes for `string.const`; `importedStringConstants` is a host compile option that creates imported `externref` globals from import names.
- Starshine's Node wasm-gc adapter currently opts into JS string builtins with `builtins: ["js-string"]`; it does not currently use the `importedStringConstants` option.
- Future `string-lowering` / `string-lifting` work should cite this boundary when translating between local `string.const` / `stringref` values and host `wasm:js-string` builtin imports or imported global string constants.
