---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md
  - ../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
  - ../dead-code-elimination/index.md
  - ../vacuum/index.md
  - ../tracker.md
---

# Starshine `gufa-optimizing` strategy

## Current status

Starshine does **not** implement `gufa-optimizing` today.

The exact local status is:

- `src/passes/optimize.mbt` lists `gufa-optimizing` in `pass_registry_boundary_only_names()` beside `gufa` and `gufa-cast-all`.
- `src/cmd/cmd.mbt` only accepts active hot/module/preset names as explicit command pipeline steps, so `--gufa-optimizing` is rejected as an unknown CLI pass flag today.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` has a second guard that rejects boundary-only entries as not implemented if a lower-level caller tries to expand them.
- `src/passes/pass_manager.mbt` has no `gufa-optimizing` dispatch case.
- No dedicated `src/passes/gufa*.mbt` owner file exists.
- `agent-todo.md` has no active `gufa`, `gufa-optimizing`, or `gufa-cast-all` implementation slice.

So the current Starshine strategy is a **boundary-status and future-port map**, not a claim of parity with Binaryen.

## Why Starshine cannot treat this as a HOT peephole

Binaryen's pass is whole-program:

1. build a module-wide `ContentOracle`,
2. use it to rewrite expressions inside functions,
3. refinalize changed functions,
4. repair EH nested pops,
5. then run nested local cleanup on only the functions changed by GUFA.

That means a faithful Starshine port would need module-level value/type evidence before it can use the existing HOT cleanup passes. A direct HOT-only peephole would miss the defining oracle step and would only imitate the cleanup residue, not the pass.

## Exact Starshine code map

| Local surface | Current role for this pass |
| --- | --- |
| `src/passes/optimize.mbt` | Boundary-only registry entry for `gufa-optimizing`; lower-level expansion rejects boundary-only names with an honest not-implemented message. |
| `src/cmd/cmd.mbt` | Command pass parsing admits only hot/module/preset names, so explicit CLI requests are rejected before dispatch. |
| `src/passes/pass_manager.mbt` | Active HOT dispatcher; contains no GUFA-family case, but does contain the local `dead-code-elimination` and `vacuum` cases a future nested cleanup runner would compose. |
| `src/passes/dead_code_elimination.mbt` | Existing local DCE implementation, useful as the future first cleanup pass but not currently invoked by a GUFA sibling. |
| `src/ir/effects.mbt` | Existing function-local effect-mask model; useful for preserving side effects, but not a replacement for Binaryen's whole-program `ContentOracle`. |
| `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` | Older pass-port map that classifies `gufa-optimizing` with whole-module or layout transforms. |
| `agent-todo.md` | No active implementation slice found, so there is no current owner for the port. |

## Future port shape

A future faithful port should probably be a module pass or a module-plus-HOT hybrid:

1. add a real `gufa` / `gufa-optimizing` module analysis owner instead of placing the proof in a local peephole;
2. build a Starshine equivalent of Binaryen's `ContentOracle` over functions, globals, call edges, and reference-typed flows;
3. share the analysis and first-phase rewrite engine with plain `gufa`;
4. track per-function mutation;
5. refinalize or otherwise revalidate the changed function before cleanup;
6. preserve any EH / stack-switching repair point required by Starshine's IR and validator;
7. run local `dead-code-elimination` then `vacuum` only on changed functions;
8. keep fresh-cast insertion out of this pass and leave it to the `gufa-cast-all` sibling.

## What a future port must not do

Do **not** implement `gufa-optimizing` as:

- ordinary constant propagation,
- a global version of `precompute`,
- a generic `dce` + `vacuum` preset,
- a cast-insertion pass,
- a cleanup pass that runs on every function whether GUFA changed it or not.

Those would all erase the source-backed split between the GUFA proof engine and the optimizing sibling's cleanup contract.

## Validation plan for a future port

A useful first validation ladder would be:

1. accept the public pass name only after it has a real owner and dispatch case;
2. add reduced tests mirroring Binaryen's `gufa-optimizing.wast` contrast: plain GUFA residue versus optimizing cleanup;
3. prove that effectful calls are preserved as `drop (call ...)` when the result value is replaced by a known constant;
4. prove unchanged functions do not run the nested cleanup path;
5. prove `gufa-optimizing` does not add the fresh casts expected only from `gufa-cast-all`;
6. run pass-targeted Binaryen parity fuzzing once the family has enough oracle coverage.

## Current local conclusion

Starshine should keep `gufa-optimizing` as boundary-only until the whole-program GUFA oracle exists. The existing local `dead-code-elimination` and `vacuum` passes are useful future building blocks, but they are not the pass by themselves.
