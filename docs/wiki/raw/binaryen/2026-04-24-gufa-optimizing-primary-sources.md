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
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast
related:
  - ../research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
  - ../research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/gufa-optimizing/index.md
---

# Binaryen `gufa-optimizing` primary-source capture

Captured: 2026-04-24

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GUFA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - Key reviewed locations: file comment describing GUFA and its optimizing variant, `GUFAPass` construction flags, `GUFAOptimizer` state, rewrite visitors, `visitFunction`, `ReFinalize`, `EHUtils::handleBlockNestedPops`, the `optimizing` gate, nested `PassRunner` setup, `runner.add("dce")`, `runner.add("vacuum")`, `runOnFunction`, and the public factory `createGUFAOptimizingPass()`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: registration of public pass names `gufa`, `gufa-cast-all`, and `gufa-optimizing`; the `gufa-optimizing` description frames it as GUFA plus local optimizations in modified functions.
- `src/ir/possible-contents.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - Key reviewed location: `ContentOracle` and `PossibleContents`, the shared whole-program value/type oracle used by all GUFA siblings.
- `test/lit/passes/gufa-optimizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - Key reviewed location: side-by-side `--gufa` versus `--gufa-optimizing` expectations that isolate the cleanup difference.
- `test/lit/passes/gufa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - Key reviewed location: broader shared-GUFA rewrite proofs that the optimizing sibling inherits.
- `test/lit/passes/gufa-cast-all.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - Key reviewed location: sibling contrast proving cast insertion is not the optimizing sibling's contract.

## Durable facts captured

- `gufa-optimizing` is a public Binaryen pass name, but it is not a separate inference algorithm. It is the shared `GUFA.cpp` engine instantiated as `optimizing = true` and `castAll = false`.
- The shared engine builds a module-wide `ContentOracle`, rewrites each function from the same possible-content facts as plain `gufa`, and tracks whether the function changed.
- The inherited rewrite families include materializable single-value replacement, impossible-site `unreachable`, `ref.eq` simplification, `ref.test` simplification, and existing `ref.cast` refinement.
- After a changed function is rewritten, Binaryen refinalizes it and repairs EH nested pops before any optimizing-only cleanup.
- The optimizing-only behavior is the changed-function nested cleanup pass list: `dce` first, then `vacuum`, run with a nested `PassRunner` on that same function.
- Unchanged functions do not run the nested cleanup, and `gufa-optimizing` does not insert the fresh casts owned by `gufa-cast-all`.
- The dedicated lit file proves the public sibling difference by showing plain `gufa` can leave block/drop residue while `gufa-optimizing` cleans it to an effect-preserving call drop plus the known constant.

## Current-`main` drift note

A 2026-04-24 spot check of `main` on the reviewed owner-file, registration, oracle, and dedicated lit-test surfaces did not surface teaching-relevant drift from the `version_129` contract captured here. The wiki should continue using `version_129` as the stable source oracle until a later source review finds a material change in one of these surfaces.

## Uncertainty and contradiction notes

- The existing local wiki already described the cleanup rerun accurately from the 2026-04-21 research note, but it did not have an immutable raw primary-source manifest or a Starshine status bridge. This capture closes the provenance gap rather than superseding the sibling's core mechanics.
- The reviewed sources do not show `gufa-optimizing` in Binaryen's default no-DWARF `-O` / `-Os` path. Keep it documented as an upstream/public registry sibling and local boundary-only future-port surface, not as a current default-pipeline parity blocker.
- A future source review should re-check current `main` before implementing because this capture intentionally spot-checked only the teaching-relevant owner/registration/test surfaces, not every helper in the possible-contents lattice.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` lists `gufa-optimizing` in `pass_registry_boundary_only_names()` beside `gufa` and `gufa-cast-all`.
- `src/cmd/cmd.mbt` only admits active hot/module/preset pass flags for explicit command pipeline steps, so a command-line `--gufa-optimizing` request is rejected before it can run.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` also rejects boundary-only names with a not-implemented message if they are requested through lower-level pass expansion.
- `src/passes/pass_manager.mbt` has dispatch cases for active HOT passes including local `dead-code-elimination` and `vacuum`, but it has no `gufa`, `gufa-optimizing`, or `gufa-cast-all` case and no nested pass-runner equivalent for this family.
- No dedicated `src/passes/gufa*.mbt` owner file, module dispatcher, active preset slot, or `agent-todo.md` backlog slice was found in the 2026-04-24 local recheck.
