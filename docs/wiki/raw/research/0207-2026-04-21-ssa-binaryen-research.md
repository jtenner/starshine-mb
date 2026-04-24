# 0207 - 2026-04-21 - Binaryen `ssa` research

## Supersession note

- 2026-04-24: [`0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md`](0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md) and [`../binaryen/2026-04-24-ssa-primary-sources.md`](../binaryen/2026-04-24-ssa-primary-sources.md) supersede this note for immutable raw-source provenance and exact Starshine local-status mapping. The source-mechanics reading below remains useful historical context.

## Scope

- Research the upstream Binaryen public pass `ssa` on `version_129`.
- Add a living dossier because the tracker no longer has obvious `none` targets, while the repo already has a deep `ssa-nomerge` folder that repeatedly references full `ssa` behavior without giving that sibling a canonical home.
- Keep the distinction explicit: `ssa` and `ssa-nomerge` are the same owning implementation file with a different `allowMerges` policy, but that one flag changes the most important beginner-facing behavior.

## Why this expansion is justified

- `ssa` is a real public Binaryen pass registered in `src/passes/pass.cpp`.
- The local repo already teaches `ssa-nomerge` as an implemented pass and repeatedly explains its behavior by contrasting it with full `ssa`.
- Without a dedicated `ssa` folder, those contrasts stay scattered across the `ssa-nomerge` pages and can make full-`ssa` merge-local behavior feel like a side note instead of a real sibling contract.
- This is therefore a good tracker expansion even though `ssa` is not currently named in the local Starshine pass registry: it is an upstream-only public pass whose exact behavior is already needed to teach a nearby implemented pass correctly.

## Initial local-repo scan

Re-read before choosing the pass:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing `docs/wiki/binaryen/passes/ssa-nomerge/` pages

Result:

- The tracker explicitly says the old obvious gaps are mostly closed.
- `ssa` has no dedicated living folder today.
- `agent-todo.md` has no dedicated `ssa` implementation slice; only `ssa-nomerge` appears through pipeline and perf notes.

## Primary upstream sources consulted

- Binaryen `version_129` `src/passes/SSAify.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/passes.h`
- Binaryen `version_129` `src/ir/local-graph.h`
- Binaryen `version_129` `src/ir/LocalGraph.cpp`
- Binaryen `version_129` `src/ir/ReFinalize.cpp`
- Binaryen `version_129` `test/lit/passes/ssa.wast`
- Binaryen `version_129` `test/gtest/local-graph.cpp`
- existing local `ssa-nomerge` dossier for neighboring context only

Freshness check:

- `SSAify.cpp` on current upstream `main` matches `version_129` exactly.
- `test/lit/passes/ssa.wast` on current upstream `main` matches `version_129` exactly.
- `test/passes/ssa-nomerge_enable-simd.wast` on current upstream `main` also still matches `version_129`, which keeps the sibling comparison stable.

## Main findings

## 1. `ssa` and `ssa-nomerge` are one implementation with one policy flag

`SSAify.cpp` defines one pass struct:

- `SSAify(bool allowMerges)`

And two constructors:

- `createSSAifyPass()` -> `SSAify(true)`
- `createSSAifyNoMergePass()` -> `SSAify(false)`

So the most important structural fact is:

- full `ssa` is not a separate codebase
- it is the same LocalGraph-driven pass as `ssa-nomerge`, but with merge handling enabled

## 2. The pass is not "proper phi SSA" in the IR

The source comment is explicit:

- Binaryen does not add real phi instructions to the AST here
- instead, when control-flow joins require multiple inputs, it creates a fresh merge local and writes each incoming value into that local

So the practical model is:

- SSA-like single-assignment locals
- represented with ordinary locals, tees, and entry prepends
- not an explicit phi node

## 3. Function order is small and exact

For each function, `runOnFunction(...)` does:

1. build `LocalGraph`
2. `computeSetInfluences()`
3. `computeSSAIndexes()`
4. `createNewIndexes(graph)`
5. `computeGetsAndPhis(graph)`
6. `addPrepends()`
7. `ReFinalize()` only when needed

That means the pass is a small whole-function local-dataflow rewrite, not a general CFG restructuring pass.

## 4. Full `ssa` renames non-SSA sets and also materializes merge locals

Like `ssa-nomerge`, full `ssa` first gives eligible non-SSA sets fresh local indexes.

The crucial extra behavior appears in `computeGetsAndPhis(...)` when a `local.get` has more than one reaching set:

- allocate a fresh merge local
- retarget the `local.get` to that merge local
- for each explicit incoming `local.set`, wrap the value in `local.tee mergeLocal ...`
- for each implicit parameter input, prepend an entry `local.set mergeLocal (local.get oldParam)`
- for implicit zero/default local entry values, do nothing because the new local already has the correct default value

That is the central difference from `ssa-nomerge`.

## 5. Parameter-entry and local-default entry are treated differently on purpose

The `nullptr` source in LocalGraph means either:

- parameter entry value
- default zero/null entry value for a non-param local

Full `ssa` handles them differently at merges:

- param entry requires a prepended copy into the merge local
- defaultable local entry requires no prepend, because a fresh local starts at the correct default value already
- nondefaultable local entry is left alone when there is nothing sound to materialize

This is one of the easiest details to lose if the pass is taught only as "phi lowering."

## 6. The directly shipped `ssa.wast` file is narrower than the source behavior

The dedicated lit file directly proves three things:

- non-nullable parameter overwrites create new locals so each local has one assignment
- replacing a ref-typed default local read with a more refined null/default can force narrow `ReFinalize`
- tuple local default replacement works too

But the lit file does **not** directly isolate the branch-merge tee / entry-prepend story.

That merge-local behavior is still strongly source-backed because it is explicit in `SSAify.cpp` and depends on LocalGraph contracts that have their own gtests, but the living dossier should say clearly:

- merge-local examples are source-derived from the owning implementation, not directly spelled out in the tiny shipped `ssa.wast`

## 7. `ssa` is public, but not part of the default no-DWARF optimize path here

`pass.cpp` registers both `ssa` and `ssa-nomerge`, but the default function pipeline adds only `ssa-nomerge` in the early no-DWARF slot.

So the practical scheduler conclusion is:

- `ssa` is an explicit/manual upstream pass
- `ssa-nomerge` is the production preset sibling Binaryen prefers in this optimizer path because it avoids the extra merge copies

That difference matters for beginner expectations.

## 8. LocalGraph precision caveats still apply

The pass relies on `LocalGraph` / `LocalGraphFlower`, whose comments and implementation make two relevant constraints explicit:

- analysis may overestimate in unreachable code
- `nullptr` tracks implicit entry values

So the pass is whole-function and CFG-aware, but not a debugger-grade exact symbolic executor.

## Important teaching corrections

## Correction A: `ssa` is not just "more aggressive renaming"

The real extra contract is:

- fresh merge locals
- incoming `local.tee` rewriting on explicit predecessor sets
- function-entry prepends for parameter inputs

## Correction B: `ssa` is not a generic propagation or copy-elimination pass

It only rewrites local traffic into SSA-like form.
It does not itself remove the fresh locals it introduces.
That cleanup story belongs to later passes.

## Correction C: `ssa` is not a default-pipeline staple in this repo's main Binaryen parity path

The default no-DWARF `-O` / `-Os` path uses `ssa-nomerge`, not full `ssa`.
So the new dossier should be framed as:

- upstream public sibling knowledge that helps teach the implemented `ssa-nomerge` pass correctly
- not as a hidden missing step in the current parity queue

## Suggested living pages

- `docs/wiki/binaryen/passes/ssa/index.md`
- `docs/wiki/binaryen/passes/ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/ssa/merge-locals-entry-prepends-and-default-values.md`
- `docs/wiki/binaryen/passes/ssa/wat-shapes.md`

## Tracker/index impacts

Because this is a justified upstream-only expansion:

- add `ssa` to the tracker's upstream-only section with an explicit note that it is not currently in the local registry but is worth tracking because the deep `ssa-nomerge` dossier repeatedly depends on the distinction
- add the new folder to `docs/wiki/binaryen/passes/index.md`
- add the new living page(s) to `docs/wiki/index.md`
- append a `docs/wiki/log.md` entry

## Validation / doc-quality plan

- Keep the dossier explicit about which families are directly tested in `ssa.wast` versus which ones are source-derived from `SSAify.cpp` + LocalGraph helper contracts.
- Keep the sibling split from `ssa-nomerge` visible on every page so beginner readers do not import no-merge rules into full `ssa`.
- Keep the absence of a dedicated `agent-todo.md` slice explicit so future implementation work is not implied.

## Durable conclusion

`ssa` deserves its own folder.

The pass is a real upstream public sibling of `ssa-nomerge`, the two variants share one owning implementation file, and the exact difference between them is important enough to be its own documented topic:

- full `ssa` creates merge locals and predecessor/entry copies
- `ssa-nomerge` deliberately refuses those rewrites

Without a dedicated `ssa` dossier, that distinction stays scattered and easy to mis-teach.