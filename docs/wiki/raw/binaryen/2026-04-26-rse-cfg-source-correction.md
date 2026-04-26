# Binaryen `rse` CFG source-correction capture

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source correction for the `docs/wiki/binaryen/passes/rse/` dossier

## Scope

This file captures a focused re-read of official Binaryen `version_129` and current-`main` primary sources for `rse` / `redundant-set-elimination`.
It supersedes the 2026-04-25 correction file where that file says the pass is only a straight-line `PostWalker` with one current value per local and no CFG predecessor merge.

The corrected finding is narrower in some ways and broader in one important way:

- `rse` is still locals-only and still not a generic dead-store, memory-store, global-store, or heap-field-store eliminator.
- But `version_129` does build a `CFGWalker` basic-block graph, flows per-local value numbers through blocks, merges predecessor values, and then optimizes sets/gets inside each block from the computed start state.
- The implementation explicitly uses `ValueNumbering`, block merge value numbers, fallthrough extraction for set RHS values, and a deterministic map from value number to refined reference-typed local indexes.

## Primary sources consulted

### Official Binaryen source files

- `RedundantSetElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RedundantSetElimination.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Helper headers used by the pass family:
  - `src/ir/numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `src/cfg/cfg-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/cfg-traversal.h>
  - `src/wasm/wasm-type.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h>

### Official Binaryen test files

- `test/passes/rse_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/rse_all-features.wast>
- `test/passes/rse_all-features.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- `test/lit/passes/rse-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/rse-gc.wast>

## Corrected durable observations

- `RedundantSetElimination.cpp` declares the pass as a `WalkerPass` over `CFGWalker<RedundantSetElimination, Visitor<LocalGet, LocalSet>, Info>` rather than as a plain `PostWalker`.
- `Info` stores `start` and `end` `LocalValues` arrays for each basic block plus the `LocalGet` / `LocalSet` expression pointers collected from that block.
- `doWalkFunction` performs three phases: create the CFG, call `flowValues(func)`, and then call `optimize(func)`. `ReFinalize` runs only if the optimization phase changes a type-sensitive local-get/tee shape.
- `flowValues` initializes entry-block locals from params, zeroable locals, and nonzeroable locals; then it uses a `UniqueDeferredQueue` fixed point over basic blocks.
- For a single predecessor, a block copies the predecessor end values. For multiple predecessors, each local either keeps the agreeing value, ignores still-unseen predecessors, or receives a block-specific merge value number when real predecessor values differ.
- Binaryen deliberately accepts some false positives around merge creation to keep convergence simple and source-documented; the proof depends on value numbers at block ends not decreasing.
- While flowing a block, `LocalSet` RHS values are normalized through `Properties::getFallthrough(...)`; a `local.get` RHS copies the current value number of the referenced local, while other expressions use `ValueNumbering`.
- `optimize` starts each block from its computed `start` values, builds a deterministic `valueToLocals` map for reference-typed locals, and scans that block's collected gets/sets in order.
- A `LocalSet` / `local.tee` is removed only when the new RHS value number equals the current value number for the target local. Otherwise the target local's current value is updated.
- A `LocalGet` may be retargeted to another local with the same value number and a strict subtype of the get's declared local type. That retargeting can work across branches because `flowValues` already computed merged start values for the block.
- Plain `local.set` removal preserves RHS evaluation by converting the shell to a `drop`. `local.tee` removal replaces the tee with its value and marks `refinalize` when the replacement value type is more specific than the tee type.
- The pass remains outside `LocalGraph` and liveness; it does not prove arbitrary overwritten writes dead. It only removes same-value writes and retargets some equivalent `local.get`s to more refined locals.
- A focused current-`main` spot check on 2026-04-26 found no teaching-relevant drift from this corrected `version_129` contract. The current source keeps the same CFG, flow, optimize, same-value removal, refined-local retargeting, and conditional refinalization structure.

## Supersession note

This capture supersedes the algorithm interpretation in:

- `docs/wiki/raw/binaryen/2026-04-25-rse-source-correction.md`
- `docs/wiki/raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md`

It partially restores the earlier 2026-04-22 statement that CFG predecessor merge tracking exists, while keeping the later correction that `rse` is not a `LocalGraph` / liveness / broad overwritten-write eliminator.
