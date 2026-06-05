# WebAssembly Compilation Hints Boundary Refresh (2026-06-05)

- Source family: official WebAssembly active-proposals tracker, Compilation Hints proposal repository and overview, existing Core/code-metadata branch-hint routing, and current Starshine custom-section / function-annotation / inlining code paths.
- Capture date: 2026-06-05 (local project date).
- Reason for capture: add a focused boundary for the active Compilation Hints proposal so `metadata.code.*`, `@metadata.code.inline`, branch hints, Starshine `FuncAnnotationSec`, and local no-inline policy are not conflated with proposal support for compilation-priority, instruction-frequency, or call-target profile metadata.
- Status: immutable primary-source bridge. The living page [`../../wasm-compilation-hints-boundary.md`](../../wasm-compilation-hints-boundary.md) is canonical for current Starshine routing.

## Primary sources checked

1. WebAssembly proposals repository README, active proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals>.
2. WebAssembly Compilation Hints proposal repository, checked 2026-06-05: <https://github.com/WebAssembly/compilation-hints>.
3. Compilation Hints proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/compilation-hints/blob/main/proposals/compilation-hints/Overview.md>.
4. Existing Starshine code-metadata / branch-hint bridge: [`2026-06-05-code-metadata-branch-hint-current-refresh.md`](2026-06-05-code-metadata-branch-hint-current-refresh.md).
5. Current Starshine metadata and optimizer policy paths: [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt), [`../../../../src/passes/no_inline.mbt`](../../../../src/passes/no_inline.mbt), and [`../../../../src/passes/inlining.mbt`](../../../../src/passes/inlining.mbt).

## Current source facts

- The official proposals tracker places **Compilation Hints** in Phase 2 (`Proposed Spec Text Available`) as of the 2026-06-05 check. It is not listed as a finished proposal or stable Core 3.0 feature.
- The proposal overview frames hints as optional compiler guidance for performance decisions only; it says they do not change module functionality or behavior.
- The proposal builds on the same broad `metadata.code.*` code-metadata mechanism used by branch hints, but adds more hint families instead of standardizing one local optimizer policy.
- The binary shape described by the proposal is a family of custom sections named `metadata.code.*`. Entries are keyed by function index and carry a vector of hints. Each hint has a byte offset from the beginning of the function body (`0` for function-level hints), a hint-length field, and hint-specific values encoded with LEB128 unless the family states otherwise.
- The first-version hint families in the overview are:
  - `metadata.code.compilation_priority`: function-level priority for compile ordering plus optional optimization/hotness priority. Smaller compilation-priority values are compiled first; the special optimization value `127` denotes run-once initialization-like functions.
  - `metadata.code.instr_freq`: instruction-level relative execution-frequency hints, expected initially for `call`, `call_ref`, `call_indirect`, and `loop` locations. Special values `0` and `127` mean never/always optimize in that proposal family.
  - `metadata.code.call_targets`: instruction-level likely-target hints for `call_ref` and `call_indirect`, with function indices and percentage-like frequencies whose total may be less than or equal to `100`.
- The overview also describes human-readable text forms such as `(@metadata.code.compilation_priority (compilation 1) (optimization 10))`, `(@metadata.code.instr_freq (freq 123.45))`, and `(@metadata.code.call_targets (target $func1 0.73) ...)`, plus equivalent binary-string spellings. Those are proposal text forms, not current Starshine text support.
- Current Starshine has opaque custom-section preservation for non-`name` sections, but no first-class decoder/encoder/parser/model for the `metadata.code.compilation_priority`, `metadata.code.instr_freq`, or `metadata.code.call_targets` payload formats.
- Current Starshine WAST accepts `(@...)` only as a function/import annotation lane and lowers it into `FuncAnnotationSec` keyed by absolute function index. It preserves annotation names and raw token args but does not implement proposal code-metadata placement, byte-offset binding, structured text grammar for nested hint payloads, or binary custom-section emission for those annotations.
- Current Starshine no-inline policy uses local function annotations (`starshine.no-full-inline`, `starshine.no-partial-inline`) created by `src/passes/no_inline.mbt` and consumed by `src/passes/inlining.mbt`; it does not consume proposal `metadata.code.instr_freq`, `metadata.code.call_targets`, or compilation-priority sections.

## Starshine interpretation rules

1. Treat Compilation Hints as active Phase-2 proposal evidence only. Do not describe it as Core 3.0, finished proposal behavior, Binaryen parity, or current Starshine optimizer support.
2. Keep Compilation Hints separate from finished/Core branch hints. `metadata.code.branch_hint` is already routed as Core/code metadata, while `metadata.code.compilation_priority`, `metadata.code.instr_freq`, and `metadata.code.call_targets` remain active-proposal hint families.
3. Keep Starshine's `FuncAnnotationSec` lane separate from proposal code metadata. A current WAST annotation with the same name before a function can be carried as raw local function metadata, but that is not byte-offset, instruction-level, binary, or optimizer support for the proposal.
4. Keep local no-inline / inlining policy separate from proposal `never_opt`, `always_opt`, instruction frequencies, and call-target percentages. Starshine should not consume those hints until a focused implementation defines parsing, validation/ignore rules, pass semantics, remap behavior, and tests.
5. Preserve unknown `metadata.code.*` custom sections by default as opaque metadata unless a named metadata policy owns them. Preserving bytes is not the same as understanding or honoring the hints.
6. Any future implementation must define a placement-bearing code-metadata model, binary decode/encode for section payloads, WAST parser/printer support for structured and binary-string text spellings, function/type/index remap rules, validation or tolerant-ignore behavior, generator/fuzzer coverage, and optimizer signoff proving hints cannot change semantics.

## Durable conclusion

Add a focused living boundary page and route feature-status plus code-metadata readers through it. The wiki should teach Compilation Hints as active proposal work with no current first-class Starshine support, while keeping existing function annotations, branch hints, no-inline policy, custom-section preservation, and Binaryen pass metadata examples on their focused pages.
