# `remove-relaxed-simd` port-readiness follow-up

_Date:_ 2026-04-26  
_Status:_ archived research note; durable conclusions filed into `docs/wiki/binaryen/passes/remove-relaxed-simd/`

## Question

The existing `remove-relaxed-simd` dossier had correct overview, Binaryen strategy, WAT shapes, and Starshine status pages, but it still left future implementers to infer the first safe Starshine slice and the exact validation ladder from several pages.

This follow-up asks: what should the pass wiki say so a developer can go from Binaryen's trap-replacement strategy to a safe local implementation plan without confusing it with deterministic SIMD lowering or feature-section stripping?

## Sources checked

- Official Binaryen current-main `RemoveRelaxedSIMD.cpp`, `pass.cpp`, and `remove-relaxed-simd.wast` via `docs/wiki/raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`.
- Existing source-correction manifest: `docs/wiki/raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`.
- Existing original manifest: `docs/wiki/raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`.
- Existing living pages under `docs/wiki/binaryen/passes/remove-relaxed-simd/`.
- Local Starshine surfaces: `src/passes/optimize.mbt`, `src/wast/types.mbt`, `src/wast/keywords.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`, `src/validate/typecheck.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, and `src/lib/show.mbt`.

## Findings

1. Binaryen current `main` still teaches the same important contract as the corrected 2026-04-25 dossier: relaxed SIMD operations become traps, child effects are preserved by localization, functions are refinalized, ordinary SIMD is out of scope, and no feature-section cleanup was visible in the reviewed owner file.
2. The Starshine registry still does not reserve `remove-relaxed-simd`; requests should be documented as unknown rather than boundary-only or removed.
3. Starshine already has enough relaxed SIMD representation to write reduced tests: WAT parsing, library instructions, binary encode/decode, validation, HOT lift, and HOT lower all have relaxed SIMD surfaces.
4. The missing local pass primitive is not parsing or encoding. It is a safe expression replacement that can preserve side-effecting children before a trapping replacement in typed `v128` contexts.
5. The Binaryen-vs-Starshine dot-product spelling split deserves a pre-port decision because Binaryen fixtures use `i16x8.dot_i8x16_i7x16_s` / `i32x4.dot_i8x16_i7x16_add_s`, while current Starshine keywords and printer use `relaxed_dot` spellings, with the printer also omitting some underscores.

## Filed-back durable changes

- Added `docs/wiki/raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/remove-relaxed-simd/starshine-port-readiness-and-validation.md`.
- Refreshed the `remove-relaxed-simd` overview, Binaryen strategy, implementation/test-map, WAT-shape catalog, and Starshine strategy pages with the new port-readiness link and validation ladder.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Remaining uncertainty

- Feature metadata cleanup is still not source-confirmed for this pass. Keep it separate from expression rewriting until a primary source proves otherwise.
- The future local landing zone may be HOT-level or library-IR-level. HOT has the convenient `Simd` payload surface, but preserving arbitrary child effects before a typed trap still needs a concrete local design.
- This pass remains outside the no-DWARF / saved-`-O4z` queue, so implementation priority should remain explicit rather than implied by the deeper dossier.
