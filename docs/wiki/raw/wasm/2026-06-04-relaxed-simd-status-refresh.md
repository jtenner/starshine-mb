# Relaxed SIMD status refresh

_Capture date:_ 2026-06-04  
_Status:_ immutable primary-source bridge for [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md) and [`../../wast/simd-authoring.md`](../../wast/simd-authoring.md), updating the status-routing layer for the already-filed relaxed-SIMD spelling/arity source bridge [`2026-05-20-wast-relaxed-simd-spellings.md`](2026-05-20-wast-relaxed-simd-spellings.md).

## Scope

This refresh checks whether relaxed SIMD should be routed as a Core WebAssembly / finished-proposal feature, an active proposal, a Starshine-local extension, or a Binaryen-only surface. It does not replace the SIMD authoring guide or Binaryen `remove-relaxed-simd` dossier; it only fixes the cross-wiki status vocabulary so future docs do not call relaxed SIMD a generic proposal gap.

## Primary external sources checked

- WebAssembly finished-proposals table, checked 2026-06-04: <https://webassembly.org/features/>. It lists **Relaxed SIMD** as a finished proposal in the Core 3.0 set.
- Official WebAssembly Core 3.0 text instruction page, checked 2026-06-04: <https://webassembly.github.io/spec/core/text/instructions.html>. Relaxed SIMD spellings live in the ordinary vector instruction grammar rather than behind a module declaration or custom section.
- Official WebAssembly Core 3.0 binary instruction page, checked 2026-06-04: <https://webassembly.github.io/spec/core/binary/instructions.html>. Relaxed SIMD uses the SIMD `0xFD` prefix space; Starshine's codec maps the relaxed subopcode range `256..275`.
- Official WebAssembly Core 3.0 validation instruction page, checked 2026-06-04: <https://webassembly.github.io/spec/core/valid/instructions.html>. Relaxed vector instructions use ordinary stack typing; there is no separate validation phase or feature-section requirement.
- WebAssembly relaxed-SIMD proposal overview, checked 2026-06-04: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>. It remains useful rationale for the relaxed semantics and the host-dependent / implementation-defined result choices.
- WebAssembly proposals repository and process pages, checked 2026-06-04: <https://github.com/WebAssembly/proposals> and <https://github.com/WebAssembly/meetings/blob/main/process/phases.md>. Use these only for proposal-status vocabulary; the finished-proposals/Core pages above are the stronger status source for relaxed SIMD.

## Starshine repository evidence checked

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) recognizes relaxed SIMD WAST spellings, including Starshine's current `relaxed_dot` dot-product spellings.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) classifies relaxed FMA and lane-select forms as ternary SIMD instructions and the remaining no-immediate relaxed forms as relaxed SIMD instructions.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers all current relaxed SIMD text opcodes to core `Instruction` variants and includes focused WAST-to-core coverage.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) stack-types relaxed SIMD through `v128` unary, binary, and ternary helpers, with focused tests for each local relaxed operation.
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) and [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) map the relaxed operations to SIMD subopcodes `256..275` under `0xFD`; [`../../../../src/binary/tests.mbt`](../../../../src/binary/tests.mbt) has exact byte roundtrip coverage.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) treats relaxed SIMD as a local `GenValidProposalFeature`/profile toggle. Default portable and Binaryen-oracle-portable profiles keep it off, while `binaryen-oracle-relaxed-simd` and `relaxed-simd` profiles deliberately enable it.
- [`../../binaryen/passes/remove-relaxed-simd/index.md`](../../binaryen/passes/remove-relaxed-simd/index.md) remains the optimizer-pass boundary: Binaryen can remove relaxed SIMD by trapping relaxed operations, but that pass behavior is distinct from authoring or validating relaxed SIMD instructions.

## Reconciled takeaways

- Relaxed SIMD should be described as **Core 3.0 / finished-proposal instruction syntax**, not as an active proposal gap, when the claim is about official text/binary/validation presence.
- The proposal overview remains the best rationale source for why relaxed operations may choose from bounded implementation-defined results. Keep citing it when explaining nondeterminism or why Binaryen's `remove-relaxed-simd` pass traps instead of choosing a deterministic replacement.
- Starshine currently has WAST keyword/parser/lowerer/printer, core instruction, binary codec, validator, tests, and explicit generator-profile support for the local relaxed SIMD surface.
- Do not infer default portability from local support. Starshine's generator keeps relaxed SIMD outside default portable/Binaryen-oracle-portable profiles, and external validator adapters may still classify relaxed-SIMD disagreement through feature-support or proposal-gap buckets depending on the tool configuration.
- Keep the existing Starshine/Binaryen dot-product spelling caveat visible: Starshine's WAST spellings currently include `relaxed_dot` for the dot-product pair, while the proposal and Binaryen sources use names without that text prefix.

## Consumability rule

Use this file with [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md) when deciding how to phrase relaxed-SIMD status, with [`../../wast/simd-authoring.md`](../../wast/simd-authoring.md) for authoring/validation details, with [`../../fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md) for generator-profile gates, and with [`../../binaryen/passes/remove-relaxed-simd/index.md`](../../binaryen/passes/remove-relaxed-simd/index.md) for Binaryen pass-oracle behavior.
