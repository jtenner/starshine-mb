# Binaryen `signext-lowering` current-main line-anchor refresh

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/signext-lowering/` dossier

## Scope

This note records the exact official Binaryen `main` source locations checked during the 2026-05-06 wiki-health pass.
It supplements the earlier 2026-05-05 current-main bridge in `docs/wiki/raw/binaryen/2026-05-05-signext-lowering-current-main-recheck.md` and does not change the teachable contract.

## Official sources consulted

- `SignExtLowering.cpp`  
  URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp#L437-L540>  
  Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignExtLowering.cpp>
- `pass.cpp`  
  URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L3110-L3116>  
  Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Dedicated lit test `signext-lowering.wast`  
  URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast#L374-L493>  
  Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signext-lowering.wast>

## Durable observations

- `SignExtLowering.cpp` still lowers the five same-width sign-extension opcodes to same-width `shl` + signed `shr_s` pairs.
- `pass.cpp` still exposes the public `signext-lowering` name.
- The dedicated lit file still proves the instruction-shape side of the contract.
- No teaching-relevant drift was found in this line-anchor refresh.

## Uncertainty and follow-up

- This note is a source-anchor refresh, not a byte-for-byte audit of the generated binary or pretty-printed WAT output.
- The local Starshine port question remains unchanged: instruction lowering is straightforward, but feature-metadata parity still needs an explicit product choice.
