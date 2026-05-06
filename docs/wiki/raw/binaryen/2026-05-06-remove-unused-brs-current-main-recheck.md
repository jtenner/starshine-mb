# Binaryen `remove-unused-brs` current-main recheck

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main freshness manifest for the `remove-unused-brs` pass

## Scope

This capture rechecks the official Binaryen sources that matter to the existing `remove-unused-brs` contract.
It asks one question: does current `main` still match the version_129 teaching story?

The answer on the reviewed surfaces is yes.

## Official sources reviewed

- Binaryen `src/passes/RemoveUnusedBrs.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
  - Reviewed surfaces: the staged walk structure, `neverUnconditionalize`, `optimizeSwitch(...)`, `visitIf(...)`, `visitThrow(...)`, `optimizeLoop(...)`, `sinkBlocks(...)`, `optimizeGC(...)`, `JumpThreader`, and the late `tablify` / `selectify` / local-set cleanup tail.
- Binaryen `src/passes/pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Reviewed surfaces: public `remove-unused-brs` registration and the repeated no-DWARF scheduler placement.
- Binaryen lit surfaces
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs-gc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs-eh.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
  - `version_129`: the same files under the `version_129` tree
  - Reviewed surfaces: the core structured-control rewrites, GC BrOn cleanup, EH throw-to-branch cleanup, and the `never-unconditionalize` branch-hint guard.

## Durable observations

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains a staged structured-control optimizer, not a generic CFG optimizer.
- The `never-unconditionalize` knob is still part of the contract and still matters for branch-hint-sensitive rewrites.
- GC BrOn cleanup and EH throw-to-branch cleanup remain real upstream surfaces, not just incidental helpers.
- The already-tracked `JumpThreader` type-equality relaxation remains the only documented `main`-vs-`version_129` drift on the reviewed surface.

## Uncertainty and caveats

- This is a freshness check, not a proof that every neighboring helper file is unchanged.
- The review stays source-backed on the pass/story boundary; it does not re-audit the entire downstream Starshine parity surface.
