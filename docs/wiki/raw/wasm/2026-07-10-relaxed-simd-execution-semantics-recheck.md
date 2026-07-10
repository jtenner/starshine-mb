# Relaxed SIMD execution-semantics recheck

_Capture date:_ 2026-07-10  
_Status:_ immutable primary-source bridge for [`../../wast/simd-authoring.md`](../../wast/simd-authoring.md) and the `local-cse` dossier. This capture refreshes **execution/test discipline**, not the already-settled Core-3.0 status or Starshine opcode surface.

## Question

What may a Starshine test or optimization safely infer from a relaxed-SIMD instruction being valid, well typed, and encodable?

## Primary sources checked

1. Official WebAssembly Core 3.0 text instructions, current page dated 2026-07-10: <https://webassembly.github.io/spec/core/text/instructions.html>. The relaxed instruction spellings are part of the ordinary vector-instruction grammar.
2. Official WebAssembly Core 3.0 binary instructions, current page dated 2026-07-10: <https://webassembly.github.io/spec/core/binary/instructions.html>. The family uses the ordinary SIMD `0xFD` prefix with subopcodes `256..275`.
3. Official WebAssembly Core 3.0 validation instructions, current page dated 2026-07-10: <https://webassembly.github.io/spec/core/valid/instructions.html>. The family has ordinary vector stack typing rather than a separate module declaration or validator mode.
4. WebAssembly relaxed-SIMD proposal overview, checked 2026-07-10: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>. Its execution-semantics section explains that a relaxed operation may have several allowed results and discusses a projection from relaxed operations to concrete implementations.
5. Existing status bridge [`2026-06-04-relaxed-simd-status-refresh.md`](2026-06-04-relaxed-simd-status-refresh.md). It remains the source for the Core-3.0 / finished-proposal status reconciliation.

## Starshine evidence checked

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), and [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) recognize and lower all 20 current relaxed-SIMD spellings.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) routes the family through ordinary unary, binary, and ternary `v128` stack helpers and has focused typecheck tests.
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) maps the 20 local variants to `0xFD` subopcodes `256..275`; [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) is the matching decoder.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) exposes `RelaxedSimdFeature` only when both `allow_v128` and `allow_relaxed_simd` are enabled, and names the opt-in `relaxed-simd` / `binaryen-oracle-relaxed-simd` profiles.
- [`../../../../src/passes/local_cse.mbt`](../../../../src/passes/local_cse.mbt) and [`../../../../src/passes/local_cse_test.mbt`](../../../../src/passes/local_cse_test.mbt) contain a separate Binaryen-observed repeated-root CSE slice; that behavior must not be generalized from stack typing alone.

## Reconciled conclusions

- **Stable syntax and type shape do not imply one portable exact result.** A fixture can prove accepted text, binary bytes, stack effects, or Starshine roundtripping without proving that every compliant execution engine produces identical `v128` bits for a relaxed operation.
- **Keep test assertions tiered.** Exact opcode/byte and validation tests are appropriate. Runtime-output tests should either use an input family whose allowed result is known to collapse to one value, or assert the source-defined allowed-result set. A single engine result is not a universal expected-value oracle for the relaxed family.
- **Do not infer optimizer legality solely from the ordinary `v128 -> v128` / `v128,v128 -> v128` / ternary type shapes.** The proposal overview allows host-dependent result sets but scopes them with a fixed per-environment projection. That still requires feature-specific reasoning for transformations that remove, duplicate, merge, or reorder evaluations.
- **Existing Starshine `local-cse` relaxed-root handling remains Binaryen-oracle-scoped.** It is supported by explicit Binaryen comparison/replay evidence recorded in the local-CSE dossier, not by a new claim that every conventional pure-expression transformation is justified for relaxed operations. This source capture neither overturns nor extends that proven slice.
- **Generator isolation is intentional.** The default portable profiles stay relaxed-SIMD-off, while the explicit relaxed profiles expose the surface for feature-focused validation and oracle work. That local policy is compatible with Core status: it controls reproducible test interpretation, not whether the instructions are Core syntax.

## Open interpretation boundary

The proposal overview makes execution environment part of the claim: host-dependent result sets are constrained by a fixed projection within one environment. This capture does not derive a general optimizer law from that model. Before widening an execution-sensitive Starshine optimization over relaxed SIMD, inspect the feature's current formal semantics and obtain transform-specific Binaryen/oracle evidence; do not treat a successful binary roundtrip, one runtime result, or ordinary stack typing as sufficient proof.

## Consumability

- Use [`../../wast/simd-authoring.md`](../../wast/simd-authoring.md) for authoring, binary, validation, and test guidance.
- Use [`../../fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md) for profile/floor vocabulary.
- Use [`../../binaryen/passes/local-cse/starshine-strategy.md`](../../binaryen/passes/local-cse/starshine-strategy.md) and [`../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md`](../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md) for the current, explicitly Binaryen-observed local-CSE exception.
- Use [`../../binaryen/passes/remove-relaxed-simd/index.md`](../../binaryen/passes/remove-relaxed-simd/index.md) for the different Binaryen pass that replaces relaxed operations with trapping behavior.
