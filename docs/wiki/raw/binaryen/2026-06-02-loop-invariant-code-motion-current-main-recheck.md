# Binaryen `loop-invariant-code-motion` / `licm` current-main recheck

_Date captured:_ 2026-06-02
_Status:_ immutable current-main drift check for the `docs/wiki/binaryen/passes/loop-invariant-code-motion/` dossier

## Scope

This note records a narrow current-main recheck after the earlier tagged `version_129` primary-source capture and the 2026-04-25 bridge.
The public Binaryen release horizon now reaches `version_130`, but this recheck still found no teaching-relevant drift on the reviewed surfaces.
It focuses on the exact surfaces that support the living loop-hoisting dossier:

- `src/passes/LoopInvariantCodeMotion.cpp`
- `src/passes/pass.cpp`
- `src/ir/effects.h`
- `src/ir/find_all.h`
- `src/ir/local-graph.h`
- `src/wasm-builder.h`
- `test/lit/passes/licm.wast`

## Official source URLs checked

- `LoopInvariantCodeMotion.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
- `pass.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `effects.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `find_all.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- `local-graph.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `wasm-builder.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>
- `licm.wast` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/licm.wast>

## Durable observations

- upstream public pass spelling remains `licm`;
- the main owner file remains `LoopInvariantCodeMotion.cpp`;
- the implementation remains function-parallel and loop-local rather than a module or boundary pass;
- the core analysis still builds a per-function `LazyLocalGraph` and local-set counts before rewriting;
- loop processing still scans only the unconditional entrance surface of the loop body and stops at control-transfer effects;
- candidate statements are still none-typed whole-statement moves, not arbitrary value-subexpression hoists;
- effect checks still reject global-state, exception, control-flow, trap, and mutable-state hazards;
- local-dependency checks still reject reads whose reaching sets are inside the loop and sets that have another in-loop set to the same local;
- successful moves still replace the old loop-body slot with `nop` and emit a wrapper block containing moved statements before the loop;
- the dedicated `licm.wast` test surface still teaches the same families, including unreachable-prefix cases, side-effect/store hazards, and pause/control-transfer boundaries.

## Consumability rule

Use this note together with the living dossier pages when restating the current upstream contract.
It is a freshness and reference-hygiene update, not a replacement for the tagged `version_129` manifest.
