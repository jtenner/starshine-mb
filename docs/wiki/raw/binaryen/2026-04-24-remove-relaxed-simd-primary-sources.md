# Binaryen `remove-relaxed-simd` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-relaxed-simd/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `remove-relaxed-simd` dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/remove-relaxed-simd/index.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-strategy.md`

## Provenance

### Official release and changelog pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.
- Binaryen `CHANGELOG.md`
  - `version_129` tag: <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/CHANGELOG.md>
  - Key reviewed surface: `version_126` lists `--remove-relaxed-simd` as an added pass.

### Official Binaryen source files consulted

- `RemoveRelaxedSIMD.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveRelaxedSIMD.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveRelaxedSIMD.cpp>
  - Key reviewed locations:
    - file header explaining that relaxed SIMD has nondeterminism and the pass removes those instructions by replacing them with `unreachable`.
    - `UnreachableRewriter::rewrite(...)`, which uses `ChildLocalizer` and returns a `block` ending in `unreachable`.
    - `visitUnary`, `visitBinary`, and `visitSIMDTernary`, which enumerate the relaxed SIMD opcodes handled by the pass.
    - `doWalkFunction(...)`, which skips functions when the module feature set does not include relaxed SIMD, walks otherwise, and refinalizes changed functions.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed location: public registration for `remove-relaxed-simd`, described as replacing relaxed SIMD instructions with `unreachable`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: pass constructor declaration for `createRemoveRelaxedSIMDPass()`.
- `child-localizer.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/child-localizer.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/child-localizer.h>
  - Key reviewed surface: helper used by the pass to preserve the effects of child expressions when the parent expression is replaced.

### Official Binaryen tests consulted

- `remove-relaxed-simd.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-relaxed-simd.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-relaxed-simd.wast>
  - Key reviewed surface: direct before/after proof that relaxed SIMD expressions become `unreachable`, with ordinary non-relaxed SIMD expressions preserved for contrast.

### Related primary-source context

- WebAssembly relaxed SIMD proposal overview
  - URL: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
  - Key reviewed surface: the proposal frames relaxed SIMD as permitting implementation-defined choices while still restricting results to a bounded set.
- WebAssembly relaxed SIMD specification repository
  - URL: <https://github.com/WebAssembly/relaxed-simd>
  - Key reviewed surface: proposal home for the instruction family that Binaryen's pass removes.

## Durable observations from the captured sources

- `remove-relaxed-simd` is a real public Binaryen pass in `version_129`; the changelog says it was added by `version_126`.
- The pass is a function-parallel AST rewrite, not a profitability optimizer.
- The pass rewrites relaxed SIMD operations to a `block` ending in `unreachable`, rather than choosing deterministic non-relaxed SIMD equivalents.
- `ChildLocalizer` is part of the correctness story: child expressions are handled before the replacement trap so side effects are not silently erased.
- The reviewed implementation covers relaxed unary, binary, and ternary SIMD op families. It does not touch ordinary deterministic SIMD instructions.
- The pass skips work when the module feature set does not include relaxed SIMD.
- Changed functions are refinalized after rewriting.
- The reviewed current-`main` source and lit filename still present the same teaching-level contract as `version_129`.
- No local Starshine registry entry for `remove-relaxed-simd` was found in this repo on 2026-04-24, although Starshine already parses, lowers, validates, encodes, decodes, and HOT-lifts relaxed SIMD instructions.

## Uncertainty and caveats

- This capture records the source-level trap-replacement strategy. It does not prove whether Binaryen also clears a module-level relaxed-SIMD feature flag after removing all relaxed SIMD instructions; that should be source-confirmed before a Starshine port promises feature-section cleanup.
- The official lit file is strong evidence for representative relaxed opcode rewrites and non-relaxed preservation, but the full opcode coverage is more directly supported by the source visitor enumeration than by isolated one-test-per-op assertions.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
