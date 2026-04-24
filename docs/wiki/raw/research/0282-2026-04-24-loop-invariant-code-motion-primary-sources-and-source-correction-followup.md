# 0282 - `loop-invariant-code-motion` primary sources and source correction follow-up

Date: 2026-04-24

## Question

Refresh the `loop-invariant-code-motion` / upstream `licm` dossier so it has:

- an immutable primary-source manifest,
- a dedicated Starshine status / port-strategy page,
- and corrected Binaryen strategy wording where the earlier 2026-04-21 pages overread the implementation as generic temp-local value hoisting.

## Sources reviewed

Local repo sources:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/`
- `docs/wiki/raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/0065-2026-03-24-ir2-execution-plan.md`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `agent-todo.md`

Primary online Binaryen sources:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen releases index: <https://github.com/WebAssembly/binaryen/releases>
- `version_129` `LoopInvariantCodeMotion.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- current `main` `LoopInvariantCodeMotion.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
- `version_129` and current `main` `pass.cpp`
- `version_129` and current `main` `pass.h`
- `version_129` and current `main` `effects.h`
- `version_129` and current `main` `find_all.h`
- `version_129` and current `main` `local-graph.h`
- `version_129` and current `main` `wasm-builder.h`
- `version_129` and current `main` `test/lit/passes/licm.wast`

## Correction from the older dossier

The older 2026-04-21 living pages and research note repeatedly described Binaryen LICM as:

- creating a fresh helper local for a value expression,
- inserting `local.set temp, expr` before the loop,
- and replacing the in-loop expression with `local.get temp`.

That is too broad for reviewed Binaryen `version_129`.
The source-backed correction is:

- `interestingToMove(...)` only considers expressions whose type is `none` and then applies a narrow set of additional exclusions.
- `visitLoop(...)` walks the loop's unconditional entrance statements and stops scanning when it sees control-transfer effects.
- When a statement moves, Binaryen stores the same statement pointer in a `moved` list, replaces the old loop-body slot with `nop`, and later emits a block whose prelude contains the moved statements followed by the original loop.
- `LazyLocalGraph` is used to reject local reads that depend on local sets inside the loop; `FindAll<LocalSet>` counts are used to reject moving one set when another set to the same local still remains inside the loop.
- Therefore the real contract is whole none-typed entrance-statement motion, not arbitrary value-expression caching through fresh temps.

This note intentionally does not rewrite `0173`; that older note remains historical evidence of the previous overread. The living pages now cite this follow-up and the raw primary-source manifest as the corrected interpretation.

## Current local status

Starshine still has no active LICM implementation.
The exact current local status is:

- `src/passes/optimize.mbt` keeps `loop-invariant-code-motion` in `pass_registry_removed_names()`.
- `run_hot_pipeline(...)` rejects removed names with an error that says the pass is removed from the active hot pipeline registry.
- `src/passes/registry_test.mbt` tests the generic removed-name rejection path via `de-nan`, but does not add a LICM-specific behavior test.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` and `docs/0065-2026-03-24-ir2-execution-plan.md` both keep LICM beside `local-subtyping` in Batch 3 dataflow-sensitive work.
- `agent-todo.md` still has no dedicated `loop-invariant-code-motion` or `licm` backlog slice.
- The pass remains outside the documented no-DWARF default optimize path and outside the saved generated-artifact `-O4z` skipped-pass queue.

## Future porting implications

A future Starshine LICM port should not start from a generic value-cache design.
The source-backed first landing shape should be closer to Binaryen's real movement surface:

1. identify loops and their unconditional entry statements in HOT / IR2,
2. summarize loop body effects and local writes,
3. reject control-transfer, exception/global/mutable-state, and local dependency hazards,
4. move only eligible none-result statements to a pre-loop prelude,
5. leave `nop` placeholders or otherwise preserve region layout safely,
6. run cleanup passes afterward if the prelude / `nop` traffic exposes simple cleanup opportunities.

Open design questions for a future implementation:

- Whether HOT control-region ownership can express Binaryen's pre-loop block emission directly or whether the pass should wait for a stronger IR2 loop/preheader abstraction.
- Whether Starshine should first require `flatten`-like predecessor work, because Binaryen itself notes that flattening can expose more independent none-typed statements to move.
- How much of Binaryen's `LazyLocalGraph` dependency proof should be ported directly versus rebuilt on top of Starshine's `use_def` / local SSA helpers.

## Durable conclusions

- `loop-invariant-code-motion` remains a justified living dossier target because the local removed registry and older pass-port maps still name it.
- The upstream public spelling remains `licm`; docs should keep the local/upstream naming split explicit.
- Reviewed Binaryen `version_129` LICM is not the temp-local expression-cache pass the previous living pages described.
- The corrected Binaryen contract is conservative whole-statement preheader motion over none-typed unconditional-loop-entry expressions, with effect and local-dependency guards.
- Current Starshine has no owner file and no active backlog slice; its durable local status is removed-name preservation plus honest request rejection.

## Follow-up wiki changes made

- Added `docs/wiki/raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-strategy.md`.
- Refreshed the existing LICM landing, Binaryen strategy, implementation/test-map, proof-boundary, and WAT-shape pages.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md`.
