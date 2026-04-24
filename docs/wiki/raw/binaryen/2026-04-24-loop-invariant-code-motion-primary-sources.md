# Binaryen `loop-invariant-code-motion` / `licm` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/loop-invariant-code-motion/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `loop-invariant-code-motion` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/loop-invariant-code-motion/index.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/effects-loops-and-hoisting-rules.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/wat-shapes.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `LoopInvariantCodeMotion.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
  - Key reviewed regions:
    - file-level pass summary and helper includes: `#L1-L52`
    - `LazyLocalGraph` setup in `doWalkFunction(...)`: `#L70-L87`
    - `visitLoop(...)` effect summaries, local-set counts, unconditional entrance walk, move legality, `nop` replacement, and pre-loop block emission: `#L89-L218`
    - `interestingToMove(...)`: `#L220-L251`
    - `hasGetDependingOnLoopSet(...)`: `#L253-L256`
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed region: public `licm` registration around `registerPass("licm", "loop invariant code motion", createLoopInvariantCodeMotionPass)`.
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>

### Official test files consulted

- `licm.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/licm.wast>
  - Key reviewed regions: `unreachable-get`, `unreachable-get-call`, `unreachable-get-store`, and `pause` examples.

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01**.
- The upstream public pass spelling is `licm`, not `loop-invariant-code-motion`; the latter is the local Starshine removed-registry name.
- The 2026-04-24 recheck corrected a stale overread in the older 2026-04-21 dossier: reviewed Binaryen `version_129` LICM does **not** create fresh temp locals for arbitrary value expressions and replace in-loop uses with `local.get`s. It moves already none-typed entrance expressions out of loops as whole statements, replaces the original in-loop statement slot with `nop`, and wraps moved statements plus the loop in a new block.
- The reviewed implementation is function-parallel, uses a per-function `LazyLocalGraph`, walks each loop's unconditional entrance surface, stops at control-transfer effects, checks global-state / exception / mutable-state / local-dependency hazards, and uses `FindAll<LocalSet>` counts to avoid moving a set when another set to the same local still remains in the loop.
- Flattening is presented as helpful but not required: it can expose smaller none-typed statements that the entrance-only mover can handle.
- A narrow 2026-04-24 current-`main` spot check on `LoopInvariantCodeMotion.cpp`, `pass.cpp`, and `licm.wast` did not surface a new teaching-relevant contract drift beyond the refreshed dossier's claims.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is still that `loop-invariant-code-motion` is a preserved **removed** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
