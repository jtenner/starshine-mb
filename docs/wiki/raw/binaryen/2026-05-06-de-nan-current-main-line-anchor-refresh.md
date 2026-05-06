# Binaryen `de-nan` current-main line-anchor refresh

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/de-nan/` dossier

## Scope

This note records the exact official Binaryen `main` source locations checked during the 2026-05-06 wiki-health pass.
It supplements the earlier 2026-05-05 current-main bridge in `docs/wiki/raw/binaryen/2026-05-05-de-nan-current-main-recheck.md` and does not change the teachable contract.

## Official sources consulted

- `src/passes/DeNaN.cpp`
- `src/passes/pass.cpp`
- `src/ir/properties.h`
- `src/ir/names.h`
- `src/wasm-builder.h`
- `src/pass.h`
- `test/lit/passes/denan.wast`

## Durable observations

- `DeNaN.cpp` still implements runtime NaN-to-zero helper instrumentation, constant NaN-to-zero rewrites, entry-parameter sanitization, `local.get` / fallthrough skip rules, helper-name collision avoidance, and nested `merge-blocks` cleanup.
- `pass.cpp` still exposes the public `denan` name.
- The helper / legality boundary files still support the same module-context story.
- The dedicated lit file still proves the instruction-shape side of the contract.
- No teaching-relevant drift was found in this line-anchor refresh.

## Uncertainty and follow-up

- This note is a source-anchor refresh, not a byte-for-byte audit of the generated binary or pretty-printed WAT output.
- The local Starshine port question remains unchanged: module-owned instrumentation still needs an explicit product choice for feature metadata parity.
