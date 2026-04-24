# Binaryen `dealign` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dealign/` dossier

## Scope

This file captures the primary online sources rechecked for the 2026-04-24 `dealign` refresh. It is provenance-heavy by design; use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/dealign/index.md`
- `docs/wiki/binaryen/passes/dealign/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dealign/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dealign/align-one-rewrite-surface-and-alignment-lowering-split.md`
- `docs/wiki/binaryen/passes/dealign/wat-shapes.md`
- `docs/wiki/binaryen/passes/dealign/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release timestamp as **2026-04-01 14:31**.

### Official source files consulted

- `src/passes/DeAlign.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

### Official test files consulted

- `test/lit/passes/dealign.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>

## Durable observations from the captured sources

- The official `version_129` release page remained the reviewed release anchor on 2026-04-24 and showed release timestamp **2026-04-01 14:31**.
- `pass.cpp` registers the public `dealign` pass with the description that it forces loads and stores to alignment `1`.
- The real implementation is smaller and more direct than the old local dossier claimed: `DeAlign` is a `WalkerPass<PostWalker<DeAlign>>`, marks itself function-parallel, and defines only three visitors in the reviewed source: `visitLoad`, `visitStore`, and `visitSIMDLoad`.
- Each visitor unconditionally assigns the node alignment field to `1`. There is no helper that first checks `align > 1`; already-`align=1` nodes are semantically unchanged because assigning `1` to `1` is a no-op, not because the implementation branches.
- The reviewed source has no `module->memory.exists()` guard, no explicit `ModuleUtils::iterDefinedFunctions(...)` wrapper, and no `visitSIMDStore` method. Those were stale overreads in the earlier 2026-04-21 local dossier text.
- The dedicated `dealign.wast` file directly proves scalar `i32.load` and `i32.store` rewriting for default, explicit `align=1`, and explicit `align=2` cases. It does not visibly isolate `i64`, `f32`, `f64`, SIMD, atomics, or bulk-memory families.
- A narrow current-`main` spot check on `DeAlign.cpp` and `dealign.wast` did not surface teaching-relevant drift from the tagged `version_129` behavior listed above.

## Consumability rule

Future wiki pages should cite this manifest together with the living `dealign` pages when they need the corrected source-backed contract. Treat `docs/wiki/raw/research/0221-2026-04-21-dealign-binaryen-research.md` as historical and superseded for mechanics where it mentions an early no-memory bailout, a `SIMDStore` visitor, a helper `align > 1` branch, or broad scalar type proof coverage.
