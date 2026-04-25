# Binaryen `rse` source-correction capture

_Capture date:_ 2026-04-25  
_Status:_ immutable primary-source correction for the `docs/wiki/binaryen/passes/rse/` dossier

## Scope

This file captures a focused re-read of Binaryen's official `version_129` sources plus current-`main` spot checks for `rse` / `redundant-set-elimination`.
It supersedes the algorithm-size claims in the older 2026-04-22 `rse` source capture where those claims describe `LocalGraph`, liveness, CFG predecessor merges, copied-local inheritance, same-block read rewriting, or dead overwritten-set deletion as part of the `version_129` pass itself.

Use the living dossier pages for the corrected explanation:

- `docs/wiki/binaryen/passes/rse/index.md`
- `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
- `docs/wiki/binaryen/passes/rse/wat-shapes.md`
- `docs/wiki/binaryen/passes/rse/starshine-strategy.md`

## Primary sources consulted

### Official Binaryen source files

- `RedundantSetElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Helper headers actually used by `RedundantSetElimination.cpp` in `version_129`
  - `src/ir/numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `src/wasm-type.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h>

### Official Binaryen test files

- `rse_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.wast>
- `rse_all-features.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.txt>
- `rse-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/rse-gc.wast>

## Corrected durable observations

- `version_129` `RedundantSetElimination.cpp` is a small `PostWalker` over `LocalGet` and `LocalSet`, not a `LocalGraph` / liveness / CFG dataflow pass.
- The only pass-local state is a vector of last-seen value numbers, one slot per local.
- `visitLocalGet` looks up the current value number for the local, decides whether the known value's type is a subtype of the `local.get` type, and asks the value-numbering engine to reuse the more precise known type when safe.
- `visitLocalSet` computes the value number for the set's value. If that number equals the remembered number for the target local, the set is redundant:
  - for plain `local.set`, Binaryen replaces the set shell with the RHS value and then wraps it in `drop` when the RHS has a value type;
  - for `local.tee`, Binaryen replaces the tee with the RHS value;
  - otherwise Binaryen remembers the new value number for the local.
- `clearLocal(local)` invalidates one local's remembered value number when the walker sees control-flow or local-state barriers that make the single straight-line fact unsafe.
- `clearAllLocals()` invalidates all remembered local facts for broad non-linear boundaries; the current implementation deliberately treats many `break`, `call`, `try`, `loop`, `if`, memory, table, GC, atomic, pop, and continuation shapes conservatively rather than computing predecessor merges.
- The pass does **not** delete an overwritten local write merely because a later write overwrites it. It removes repeated writes of the same value and relies on `vacuum` to clean the resulting `drop` debris.
- The pass does **not** use `LocalGraph`, liveness, copied-local inheritance, same-block read rewriting, or exact-vs-merged predecessor lattices in `version_129`.
- The dedicated GC lit file still matters, but specifically for the local-get type-refinement path, not for heap-store or field-write elimination.
- A focused current-`main` spot check on 2026-04-25 found no teaching-relevant drift from the corrected `version_129` contract above.

## Supersession note

This capture does not discard the older `docs/wiki/raw/binaryen/2026-04-22-rse-primary-sources.md` file as provenance.
It supersedes only that file's algorithm interpretation where the older capture and pages over-attributed dataflow behavior to the pass.
The older source URLs remain useful as a record of what was reviewed, but the corrected living pages should cite this capture for the source contract.
