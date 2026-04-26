# Binaryen `dealign` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable current-main and Starshine-port-readiness manifest for the `docs/wiki/binaryen/passes/dealign/` dossier

This manifest extends the earlier [`2026-04-24-dealign-primary-sources.md`](2026-04-24-dealign-primary-sources.md) source correction. Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/dealign/index.md`
- `docs/wiki/binaryen/passes/dealign/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dealign/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dealign/align-one-rewrite-surface-and-alignment-lowering-split.md`
- `docs/wiki/binaryen/passes/dealign/wat-shapes.md`
- `docs/wiki/binaryen/passes/dealign/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dealign/starshine-port-readiness-and-validation.md`

## Online primary sources reviewed

- Binaryen current `main` `src/passes/DeAlign.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
- Binaryen `version_129` `src/passes/DeAlign.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- Binaryen current `main` `test/lit/passes/dealign.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>
- Binaryen `version_129` `test/lit/passes/dealign.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- Binaryen current `main` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen `version_129` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>

## Current-main findings

The 2026-04-26 current-main recheck found no teaching-relevant drift from the 2026-04-24 corrected `version_129` contract:

- `dealign` remains a public pass registered from `pass.cpp`.
- The owner remains `src/passes/DeAlign.cpp`.
- The pass remains a tiny function-parallel `WalkerPass<PostWalker<DeAlign>>`.
- The reviewed implementation still covers `Load`, `Store`, and `SIMDLoad` visitors.
- Each visitor still assigns the alignment metadata field to `1`.
- No reviewed source adds a `SIMDStore`, atomic, bulk-memory, table, or GC visitor.
- The dedicated lit fixture remains narrow: it directly demonstrates scalar `i32.load` and `i32.store` alignment normalization, while broader scalar families and `SIMDLoad` remain source-confirmed rather than fixture-isolated.

## Starshine port-readiness findings

A Starshine port would be small only if it stays faithful to Binaryen's exact surface. The local read-along anchors as of 2026-04-26 are:

- `src/passes/optimize.mbt:127-153`: boundary-only and removed pass registries still omit `dealign`.
- `src/passes/optimize.mbt:446-466`: absent names fail through the generic `unknown pass flag` path.
- `src/wast/parser.mbt:1323-1342`: text `offset=` / `align=` memarg parsing preserves alignment bytes before lowering.
- `src/wast/lower_to_lib.mbt:207-229`: text alignment bytes are converted to exponent-form `@lib.MemArg` values.
- `src/lib/types.mbt:8191-8193`: `@lib.MemArg` stores alignment as the exponent-form first field.
- `src/lib/show.mbt:788-790`: WAT printing exposes that exponent-form alignment, so a local pass must update the IR memarg before print/compare.
- `src/validate/typecheck.mbt:1543-1568`: memarg validation enforces alignment bounds; setting align exponent to `0` (`align=1`) is always within this checked upper bound for ordinary nonzero-width memory accesses.

## Uncertainties and boundaries

- This recheck did not prove Starshine currently has a HOT instruction variant for every Binaryen `Load`, `Store`, and `SIMDLoad` shape. A local implementation should start from the library IR memarg representation unless a HOT audit confirms complete alignment preservation.
- The dedicated Binaryen lit file still does not visibly isolate `SIMDLoad`. Treat `SIMDLoad` as source-confirmed, not lit-proven.
- Do not add `SIMDStore`, atomics, or bulk-memory behavior locally unless a new Binaryen source review shows upstream added those visitors or the Starshine port intentionally documents a divergence.

## Supersession

This manifest does not supersede [`2026-04-24-dealign-primary-sources.md`](2026-04-24-dealign-primary-sources.md); it deepens it with a current-main freshness check and concrete local port-readiness anchors. The older research note `docs/wiki/raw/research/0221-2026-04-21-dealign-binaryen-research.md` remains superseded for the no-memory-bailout, `SIMDStore`, helper-branch, and broad-lit-coverage claims recorded there.
