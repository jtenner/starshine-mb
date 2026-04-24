---
kind: source-capture
status: supported
last_reviewed: 2026-04-24
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast
related:
  - ../research/0163-2026-04-21-gufa-binaryen-research.md
  - ../research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/gufa/index.md
---

# Binaryen `gufa` primary-source capture

Captured: 2026-04-24

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GUFA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - Key reviewed locations: top file comment describing Grand Unified Flow Analysis, `GUFAOptimizer` construction over a shared `ContentOracle`, `visitExpression`, `visitRefEq`, `visitRefTest`, `visitRefCast`, `visitFunction`, `addNewCasts`, `GUFAPass`, and the public factories `createGUFAPass()`, `createGUFAOptimizingPass()`, and `createGUFACastAllPass()`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: registration of public pass names `gufa`, `gufa-cast-all`, and `gufa-optimizing`; the plain `gufa` description frames it as broad whole-program optimization.
- `src/ir/possible-contents.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - Key reviewed location: `PossibleContents` and `ContentOracle`, including the closed-world assumption, `None`, `Literal`, `GlobalInfo`, `ConeType`, and `Many` result families plus intersection/subcontents/materialization queries.
- `test/lit/passes/gufa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - Key reviewed location: the plain-GUFA proof surface for unreachable inference, literal/global/function materialization, open-world/export boundaries, `ref.eq`, `ref.test`, and existing-`ref.cast` refinement.
- `test/lit/passes/gufa-optimizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - Key reviewed location: sibling contrast proving that changed-function `dce` then `vacuum` cleanup belongs to `gufa-optimizing`, not to plain `gufa`.
- `test/lit/passes/gufa-cast-all.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - Key reviewed location: sibling contrast proving that fresh `ref.cast` insertion belongs to `gufa-cast-all`, not to plain `gufa`.

## Durable facts captured

- Plain `gufa` is a public Binaryen pass name implemented by the shared `GUFA.cpp` engine instantiated as `optimizing = false` and `castAll = false`.
- The pass builds one module-wide `ContentOracle` and then rewrites each function using oracle answers. The defining proof is whole-program possible contents, not local peepholes or ordinary constant folding.
- The inherited plain rewrite families are: impossible-location `unreachable`, materializable single-value replacement, impossible `ref.eq` to `0`, impossible/guaranteed `ref.test` to `0`/`1`, and existing-`ref.cast` type refinement.
- Replacement is deliberately narrower than the oracle. Binaryen only emits replacements that it can materialize and type-check at the original site; `global.get` / `ref.func` identity knowledge can still bail out when the emitted static type is wrong.
- Generic expression rewriting skips already-unreachable, none-typed, constant, tuple-typed, and ordered-memory expressions. The memory-order guard keeps synchronization semantics out of the rewrite surface.
- Changed functions are refinalized and run through `EHUtils::handleBlockNestedPops(...)`. That repair step is part of the correctness contract even for plain `gufa`.
- Plain `gufa` neither runs the nested `dce` / `vacuum` cleanup owned by `gufa-optimizing` nor inserts the fresh casts owned by `gufa-cast-all`.

## Current-`main` drift note

A 2026-04-24 spot check of `main` on the reviewed owner-file, registration, oracle, and dedicated lit-test surfaces did not surface teaching-relevant drift from the `version_129` contract captured here. The wiki should continue using `version_129` as the stable source oracle until a later source review finds a material change in one of these surfaces.

## Uncertainty and contradiction notes

- The 2026-04-21 research note already described plain GUFA's core mechanics accurately, but it did not have an immutable raw primary-source manifest or a dedicated Starshine status bridge. This capture closes that provenance gap rather than replacing the older note.
- The sibling manifests for `gufa-optimizing` and `gufa-cast-all` intentionally overlap the same owner file. The split should stay explicit: same oracle and first-phase rewrite, different post-rewrite obligations.
- The reviewed sources do not show plain `gufa` in Binaryen's default no-DWARF `-O` / `-Os` path. Keep it documented as an upstream/public registry sibling and local boundary-only future-port surface, not as a current default-pipeline parity blocker.
- A future source review should re-check current `main` before implementation because this capture intentionally spot-checked teaching-relevant surfaces rather than every helper path in `possible-contents.h`.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` lists `gufa` in `pass_registry_boundary_only_names()` beside `gufa-optimizing` and `gufa-cast-all`.
- `src/cmd/cmd.mbt` only admits active hot/module/preset pass flags for explicit command pipeline steps, so a command-line `--gufa` request is rejected before it can run.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` also rejects boundary-only names with a not-implemented message if they are requested through lower-level pass expansion.
- `src/passes/pass_manager.mbt` has no `gufa`, `gufa-optimizing`, or `gufa-cast-all` dispatch case.
- No dedicated `src/passes/gufa*.mbt` owner file, module dispatcher, active preset slot, or `agent-todo.md` backlog slice was found in the 2026-04-24 local recheck.
