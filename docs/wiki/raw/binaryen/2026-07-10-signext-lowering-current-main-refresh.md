# Binaryen `signext-lowering` current-main refresh

_Capture date:_ 2026-07-10  
_Status:_ immutable primary-source refresh for the `docs/wiki/binaryen/passes/signext-lowering/` dossier

## Scope

This capture rechecks the public Binaryen `main` implementation after the older 2026-05-05/06 source bridges. It preserves the earlier evidence as historical provenance, but supersedes their living-current-main summary where it omitted the pass's entry feature gate.

Use the living dossier for the maintained explanation:

- `docs/wiki/binaryen/passes/signext-lowering/index.md`
- `docs/wiki/binaryen/passes/signext-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signext-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/signext-lowering/fuzzing.md`

## Official sources consulted

- Binaryen current `main`, [`src/passes/SignExtLowering.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp)
- Binaryen current `main`, [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
- Binaryen current `main`, [`src/passes/passes.h`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h)
- Binaryen current `main`, [`test/lit/passes/signext-lowering.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast)

## Durable observations

1. The public pass spelling remains `signext-lowering`.
2. The owner first checks `getModule()->features.hasSignExt()`. If that feature is absent, it returns without walking or rewriting functions.
3. When the feature is present, the owner remains a function-parallel unary postwalk. It replaces exactly the five same-width sign-extension instructions with same-width `shl` plus arithmetic `shr_s` pairs using counts `24`, `16`, `56`, `48`, and `32`.
4. The original child is moved once under the new `shl`; this local rewrite does not need a separate effect analysis.
5. After the enabled rewrite, the owner disables `FeatureSet::SignExt`. The dedicated lit fixture remains instruction-shape evidence, not standalone proof of target-feature-section emission or removal.

## Reconciliation and uncertainty

- The 2026-05-05/06 captures correctly described the five rewrite shapes and feature clearing, but their current-main summaries did not record the entry `hasSignExt()` gate. Treat an unconditional “all direct opcodes are lowered” statement as stale; the precise contract is feature-gated lowering.
- This was a source review, not a generated-binary or target-feature custom-section audit. Binaryen's internal `FeatureSet` behavior must not be collapsed into a claim about a particular custom-section byte layout.
- Starshine currently has no public `signext-lowering` pass and no Binaryen-identical module feature-state model. A future port must explicitly choose whether to reproduce the gate/cleanup through a structured local feature model, treat target-feature custom data as a separate module concern, or document an instruction-only divergence.
