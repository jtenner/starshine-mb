# Binaryen `loop-invariant-code-motion` / `licm` current-main and port-readiness bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable focused source bridge for the `docs/wiki/binaryen/passes/loop-invariant-code-motion/` dossier

## Scope

This file captures the focused primary online sources checked on 2026-04-25 while deepening the Starshine port-readiness coverage for `loop-invariant-code-motion` / upstream `licm`.

The existing 2026-04-24 manifest remains the tagged `version_129` oracle. This bridge answers a narrower implementation-readiness question:

- do current Binaryen `main` sources still support the corrected none-typed loop-entry statement-motion contract, and what does that imply for the first honest Starshine slice?

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/loop-invariant-code-motion/index.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/effects-loops-and-hoisting-rules.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/wat-shapes.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-port-readiness-and-validation.md`

## Primary source URLs checked

### Official Binaryen current `main`

- `LoopInvariantCodeMotion.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `pass.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.h>
- `effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `find_all.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/find_all.h>
- `local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
- `wasm-builder.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>

### Official Binaryen current `main` tests

- `licm.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/licm.wast>

### Baseline tag retained for comparison

- Existing tagged manifest: `docs/wiki/raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`
- Representative `version_129` URLs:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>

## Recheck result

No teaching-relevant current-`main` drift was found for the existing corrected dossier.

The current `main` surfaces checked on 2026-04-25 still support the same durable contract taught from `version_129`:

- upstream public pass spelling remains `licm`;
- the main owner file remains `LoopInvariantCodeMotion.cpp`;
- the implementation remains function-parallel and loop-local rather than a whole-module boundary pass;
- the core analysis still builds local-set counts and a per-function `LazyLocalGraph` before loop rewrites;
- loop processing still scans only the unconditional entrance surface of the loop body;
- the scan still stops at control-transfer effects;
- candidate statements are still none-typed and whole-statement moves, not arbitrary value-subexpression hoists;
- effect checks still reject global-state, exception, control-flow, trap, and mutable-state hazards;
- local dependency checks still reject reads whose reaching local sets are inside the loop and sets that still have another in-loop set to the same local;
- successful moves still replace the old loop-body statement slot with `nop` and emit a wrapper block containing moved statements before the loop;
- the dedicated `licm.wast` test surface still teaches the same families: unreachable prefix cases, side-effect/store hazards, and pause/control-transfer boundaries.

## Port-readiness implications for Starshine

The current-main recheck does not change Starshine's local status:

- `src/passes/optimize.mbt:98-106` defines removed registry entries with category `Removed` and no descriptor.
- `src/passes/optimize.mbt:144-151` still lists `loop-invariant-code-motion` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt:469-472` still rejects removed names from `run_hot_pipeline_expand_passes(...)`.
- `src/passes/registry_test.mbt:171-179` still proves the generic removed-name rejection path with `de-nan`, not a LICM-specific transform.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:49-52` still places `loop-invariant-code-motion` in Batch 3 with `local-subtyping`.
- `docs/0065-2026-03-24-ir2-execution-plan.md:37-43` still says Batch 3 dataflow-sensitive passes come after Batch 2 control/cleanup work if pass migration resumes.

The focused readiness conclusion is that the first Starshine slice should stay narrower than “generic invariant expression hoisting”:

1. decide the public spelling / alias policy (`licm`, `loop-invariant-code-motion`, or both);
2. expose the pass only once the implementation has a real descriptor instead of removed-name bookkeeping;
3. start from unconditional loop-entry none-typed statement motion;
4. reuse existing HOT loop/effects/use-def/SSA overlays only where they can prove the same hazards Binaryen checks with `EffectAnalyzer`, local-set counts, and `LazyLocalGraph`;
5. add reduced tests before expanding into flattened or more nested shapes;
6. only then compare against Binaryen's `--licm` / local long-name behavior.

## Explicit non-changes to preserve

The recheck did **not** find evidence to teach any of these as current Binaryen `licm` behavior:

- synthesizing fresh temp locals for arbitrary value-producing invariant expressions;
- hoisting statements after a conditional branch, break, return, throw, or other control-transfer point in the loop-entry prefix;
- ignoring local-set dependencies because an expression looks syntactically invariant;
- hoisting store-like, trap-sensitive, exception-sensitive, or global-state-sensitive work;
- running as part of the current open-world no-DWARF default optimize tail;
- having a current Starshine owner file, descriptor, tests, alias, or backlog slice.

## Consumability rule

Cite this file when refreshing current-main freshness or Starshine implementation-readiness wording for `loop-invariant-code-motion` / `licm`.
Do not treat it as a replacement for `docs/wiki/raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`; it is a no-drift and port-readiness bridge layered on top of that manifest.
