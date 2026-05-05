# Binaryen `signext-lowering` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/signext-lowering/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `signext-lowering` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-25-signext-lowering-primary-sources.md` and the earlier current-main bridge in `docs/wiki/raw/binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/signext-lowering/index.md`
- `docs/wiki/binaryen/passes/signext-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signext-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `SignExtLowering.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignExtLowering.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- Dedicated lit test `signext-lowering.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signext-lowering.wast>

### Tagged comparison anchor

- `SignExtLowering.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignExtLowering.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `signext-lowering.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signext-lowering.wast>

## Durable observations

- Current `main` still exposes the same tiny feature-lowering contract as `version_129`: the same five same-width sign-extension opcodes are lowered to same-width `shl` + signed `shr_s` pairs.
- The owner file still disables Binaryen's sign-extension feature after rewriting, so feature metadata remains part of the observable contract even though the instruction rewrite itself is local.
- The dedicated lit file still proves the instruction-shape side of the contract; the owner source remains the place to cite for feature-bit clearing.
- No teaching-relevant drift was found in this focused recheck.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not claim byte-for-byte historical equivalence or audit the exact `target_features` payload format.
- The local Starshine port question remains unchanged: instruction lowering is straightforward, but feature-metadata parity still needs an explicit product choice.
