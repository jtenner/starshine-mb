# Tail-Call Core 3.0 Component-Date Recheck

- Capture date: 2026-07-10
- Source family: current official WebAssembly Core 3.0 instruction pages plus Starshine WAST/core/binary/validator/IR source surfaces
- Status: immutable primary-source bridge. This refresh supersedes the **current-source-date and no-semantic-drift role** of [`2026-06-04-tail-call-current-refresh.md`](2026-06-04-tail-call-current-refresh.md); that earlier capture remains the detailed original source map.

## Primary sources checked

1. WebAssembly Core Specification, [Syntax / Instructions](https://webassembly.github.io/spec/core/syntax/instructions.html), checked 2026-07-10 — document date `2026-07-10`.
2. WebAssembly Core Specification, [Text Format / Instructions](https://webassembly.github.io/spec/core/text/instructions.html), checked 2026-07-10 — document date `2026-07-10`.
3. WebAssembly Core Specification, [Validation / Instructions](https://webassembly.github.io/spec/core/valid/instructions.html), checked 2026-07-10 — document date `2026-07-10`.
4. WebAssembly Core Specification, [Execution / Instructions](https://webassembly.github.io/spec/core/exec/instructions.html), checked 2026-07-10 — document date `2026-07-10`.
5. WebAssembly Core Specification, [Binary Format / Instructions](https://webassembly.github.io/spec/core/binary/instructions.html), checked 2026-07-10 — document date `2026-07-09`.
6. Historical [WebAssembly tail-call proposal](https://github.com/WebAssembly/tail-call) — rationale only; the Core pages above are the current syntax, binary, validation, and execution authority.

## Durable takeaways

- The current Core pages still define the three tail-call instructions: `return_call`, `return_call_indirect`, and `return_call_ref`. No spelling, immediate-order, or validation-rule replacement was found relative to the 2026-06-04 capture.
- Tail calls retain the call-plus-return contract: they consume normal callee inputs, require callee results compatible with the enclosing function result type, and make the following local continuation unreachable. `return_call_indirect` continues to carry type then table indices in binary form; `return_call_ref` continues to carry a function type index.
- Core page dates are **component-specific**, not one release-wide date. As checked here, syntax/text/validation/execution show `2026-07-10`, while the binary-instructions page shows `2026-07-09`. Living pages must cite the particular source page or say “current Core 3.0 pages,” rather than claiming every Core page has one common date.
- This recheck confirms standards semantics only. It neither expands Starshine support nor proves whole-feature support from any one local layer.

## Starshine evidence checked

- WAST keywords and parser: [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers all three spellings; [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses direct, default-table indirect, and type-use reference forms.
- Core and binary model: [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) carries distinct variants; [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) retain `0x12`, `0x13`, and `0x15`, with type index before table index for `return_call_indirect`.
- Validation: [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) checks exact local return-result equality through `require_return_results(...)`, then calls `set_unreachable()` for all three forms. Its indirect path still pops an `i32` table element index, so table64 tail-call fixtures remain a local validation-gap boundary.
- HOT/CFG: [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) marks the three forms call-like, side-effecting, possibly trapping, exceptionally succeeding, and terminating; [`../../../../src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt) emits their normal `ReturnEdge` to the synthetic exit.

## Supersession and limits

- [`2026-06-04-tail-call-current-refresh.md`](2026-06-04-tail-call-current-refresh.md) is superseded only for its blanket `2026-06-03` current-Core date phrasing. Its detailed source and Starshine evidence remain useful historical provenance.
- This note does not revalidate proposal status tables, browser support, Binaryen behavior, or every Starshine WAST/validator edge case. Use [`../../wast/tail-call-authoring.md`](../../wast/tail-call-authoring.md) for the maintained cross-layer contract and its linked focused pages for those claims.
