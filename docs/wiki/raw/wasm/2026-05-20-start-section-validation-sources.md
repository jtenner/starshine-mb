# WebAssembly Start Section Validation Sources

- Capture date: 2026-05-20
- Source family: WebAssembly Core Specification 3.0 draft, plus Starshine repository evidence
- Primary sources:
  - WebAssembly Core Specification, `Syntax / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/syntax/modules.html>
  - WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/binary/modules.html>
  - WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/text/modules.html>
  - WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Execution / Modules — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/exec/modules.html>

## Durable takeaways

- The start component of a module is optional and names one function index. In the binary format it is standard section id `8`; in text it is spelled as a module field such as `(start $init)` or `(start 0)`.
- Start validation is deliberately small: the referenced function must exist in the full function index space, and its function type must have no parameters and no results. This rule applies equally to imported and defined functions because imports occupy the function-index prefix.
- A start declaration is an instantiation-time effect, not a callable export, extra code-body entry, or automatic root for all other validation concerns. If it names an imported function, the host function is invoked at instantiation. If it names a defined function, that target's body still lives in the ordinary code section.
- The official module-validation rule still includes the optional start function in the module `refs` set used by `ref.func` validation. Current Starshine intentionally diverges here: `start_sec` alone does not declare a `ref.func` target, and the regression test keeps that policy visible.
- The start field is a function-index carrier for module rewrites. Any pass that deletes, merges, reorders, imports, or appends functions must remap or remove `StartSec` with the same care as exports, element payloads, `ref.func`, direct calls, names, and annotations.

## Starshine reconciliation

- `src/lib/types.mbt` represents the optional start section as `Module.start_sec : StartSec?`, where `StartSec` wraps an absolute `FuncIdx`.
- `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt` parse `(start ...)` fields and resolve source ids/numeric indices through the same imported-prefix function-index environment used for calls and exports.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` decode/encode section id `8` as a function index. Start has no payload beyond that index.
- `src/validate/validate.mbt` validates starts after imports and function declarations have extended `Env.funcs`, then before exports, `ref_func_declarations`, code, and names. `validate_startsec` rejects an unknown target, any parameter, or any result and wraps failures as `ValidationIssue::StartSection` with the target `FuncIdx` attached when present.
- `src/validate/invalid_fuzzer.mbt`, `src/validate/gen_invalid.mbt`, `src/fuzz/invalid_binary.mbt`, and `src/fuzz/invalid_text.mbt` all treat invalid start targets/signatures as start-family invalid cases. The text and binary lanes include imported-start variants so the imported-prefix rule remains covered.

## Follow-up questions

- If Starshine aligns `ref.func` declaration policy with the official start-as-`refs` source, update `validate/start-section.md`, `validate/ref-func-declarations.md`, `binary/function-import-export-and-code-sections.md`, the function-call WAST page, this source bridge, and the validator regression together.
- If WAST parsing starts rejecting duplicate start fields earlier instead of lowering to one `StartSec`, record that as a text-layer policy change. The core binary/module model should still be described as one optional start section.
- If a module-remap pass grows special no-op-start deletion logic, keep the difference visible between deleting `start_sec` metadata and deleting or preserving the target function body.
