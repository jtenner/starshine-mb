# Binaryen `signext-lowering` Implementation/Test Map Source Correction

- **Captured:** 2026-04-25
- **Pass:** `signext-lowering`
- **Scope:** focused implementation/test-map source capture plus one correction to the earlier 2026-04-25 `signext-lowering` dossier wording.
- **Status:** immutable raw-source manifest and correction note. Keep living conclusions in `docs/wiki/binaryen/passes/signext-lowering/`.

## Primary upstream sources

### Binaryen `version_129`

- Release tag: <https://github.com/WebAssembly/binaryen/tree/version_129>
- Pass implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignExtLowering.cpp>
- Pass registration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Pass factory declaration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signext-lowering.wast>

### Current-main spot check

- Pass implementation on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp>
- Pass registration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Pass factory declaration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Dedicated lit test on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast>

The 2026-04-25 current-main recheck found no teaching-relevant drift from the reviewed `version_129` contract.

## Source-backed implementation map

`SignExtLowering.cpp` owns the whole transform. The source surface is intentionally small:

- pass class and function-parallel walker setup;
- `visitUnary(Unary*)` match over exactly five sign-extension unary operators;
- `builder.makeBinary(...)` construction of `shl` plus arithmetic `shr_s` pairs;
- `replaceCurrent(...)` to replace the original unary root while reusing the original child expression once;
- a module-level feature update that disables `FeatureSet::SignExt` after the per-function walk.

`pass.cpp` and `passes.h` only expose the public pass name/factory. The pass has no separate helper file, no control-flow analysis, no use-def analysis, no local-graph dependency, no effect analysis, and no profitability model.

## Test-surface correction

The earlier raw manifest said the dedicated lit test proves opcode lowering and feature removal. This run narrows that wording:

- `test/lit/passes/signext-lowering.wast` directly checks all five opcode-to-shift-pair output families.
- The implementation source directly proves the `FeatureSet::SignExt` clearing side effect.
- The reviewed lit file does **not** explicitly assert a target-feature custom-section or printed feature-annotation delta. Treat feature clearing as source-proven, not independently lit-proven by that file.

This correction does not change the pass contract; it only makes the evidence level explicit.

## Starshine local source map checked

The local code search for this follow-up confirmed:

- `src/passes/optimize.mbt` has no `signext-lowering` registry entry, and the boundary-only / removed lists omit the name.
- `src/passes/pass_manager.mbt` has no dispatcher case for `signext-lowering`.
- Existing prerequisite instruction surfaces remain present: `src/wast/types.mbt`, `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/lib/types.mbt`, `src/binary/encode.mbt`, `src/validate/typecheck.mbt`, `src/ir/hot_lift.mbt`, and `src/passes/pick_load_signs.mbt`.
- `src/lib/show.mbt` still prints sign-extension mnemonics without the WAT underscores, which remains a future local test-hygiene caveat rather than a Binaryen-pass behavior claim.

## Uncertainties and caveats

- This capture still does not establish the historical Binaryen introduction release for `signext-lowering`.
- Starshine still lacks a Binaryen-identical `FeatureSet::SignExt` model. A faithful local port must decide whether feature clearing maps to target-feature custom-section rewriting, an explicit feature model, or a documented instruction-only divergence.
