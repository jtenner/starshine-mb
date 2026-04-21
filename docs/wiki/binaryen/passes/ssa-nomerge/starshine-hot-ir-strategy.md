---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ./parity.md
  - ../ssa/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `ssa-nomerge` HOT-IR strategy

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `SSAify(false)` contract.

## Current local surface

Starshine exposes `ssa-nomerge` as an active hot pass with:

- descriptor name: `ssa-nomerge`
- summary text: `Untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies.`
- required HOT analyses:
  - CFG
  - local SSA
- broad invalidation after mutation:
  - CFG
  - dominance
  - liveness
  - use-def
  - effects
  - loop info
  - SSA

That summary string already reveals the biggest local-vs-upstream difference.
Upstream Binaryen `ssa-nomerge` is a **no-merge** LocalGraph rewrite.
Current Starshine `ssa-nomerge` is a **HOT-SSA roundtrip plus raw fallback** that is willing to lower overlay phis through explicit predecessor copies.

So the safe teaching headline is:

- Binaryen `ssa-nomerge` avoids materializing merge locals
- current Starshine `ssa-nomerge` may materialize predecessor-copy traffic while destroying HOT SSA back into ordinary locals

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/ssa_nomerge.mbt:2`
  - `ssa_nomerge_descriptor()` declares the public pass name, required analyses, and invalidation set
- `src/passes/ssa_nomerge.mbt:15`
  - `ssa_nomerge_summary()` owns the registry/help text
- `src/passes/ssa_nomerge.mbt:20`
  - `ssa_nomerge_has_local_writes(...)` is the cheap early gate
- `src/passes/ssa_nomerge.mbt:34`
  - `ssa_nomerge_needs_rewrite(...)` decides whether either overlay phis or concrete local-write defs make rewriting worthwhile
- `src/passes/ssa_nomerge.mbt:49`
  - `ssa_nomerge_run(...)` requires CFG + local SSA, then calls `@ir.ssa_destroy_into_hot(...)`
- `src/ir/ssa_destroy.mbt:33`
  - `HotSsaDestroyPolicy` currently exposes only `ReusePhiLocals`
- `src/ir/ssa_destroy.mbt:157`
  - `ssa_destroy_build_predecessor_copy_nodes(...)` turns scheduled copies into explicit `local.get` -> `local.set` HOT nodes
- `src/ir/ssa_destroy.mbt:455`
  - `ssa_insert_predecessor_copies(...)` inserts those copies at predecessor-block boundaries
- `src/ir/ssa_destroy.mbt:527`
  - `ssa_destroy_into_hot(...)` is the real local SSA-destruction bridge used by the pass
- `src/passes/pass_manager.mbt:5768`
  - `run_hot_pipeline_raw_append_local_read(...)` owns raw default-value materialization and alias-resolved local reads
- `src/passes/pass_manager.mbt:5915`
  - `run_hot_pipeline_raw_initialized_locals(...)` seeds raw default-local knowledge from params plus zero-init locals
- `src/passes/pass_manager.mbt:6788`
  - `run_hot_pipeline_raw_ssa_nomerge_structured(...)` owns the structured raw rewrite path
- `src/passes/pass_manager.mbt:6826`
  - `run_hot_pipeline_raw_ssa_nomerge_straight_line(...)` owns the cheap straight-line raw rewrite path
- `src/passes/pass_manager.mbt:6937`
  - `run_hot_pipeline_raw_ssa_nomerge(...)` chooses between skip, structured raw rewrite, and straight-line raw rewrite
- `src/passes/pass_manager.mbt:7836`
  - raw-pass-manager hook that selects this special-case raw implementation before ordinary lift/writeback
- `src/passes/pass_manager.mbt:8685`
  - hot-pass dispatch site for the lifted path
- `src/passes/optimize.mbt:158`
  - registry entry wiring for the public pass name
- `src/passes/optimize.mbt:246`
  - first preset slot in `optimize`
- `src/passes/optimize.mbt:258`
  - first preset slot in `shrink`
- `src/passes/optimize.mbt:379`
  - public `optimize_preset_passes(...)` definition
- `src/passes/optimize.mbt:394`
  - public `shrink_preset_passes(...)` definition
- `src/passes/ssa_nomerge_test.mbt:189`
  - predecessor-copy branch-join coverage
- `src/passes/ssa_nomerge_test.mbt:243`
  - loop-carried local lowering coverage
- `src/passes/ssa_nomerge_test.mbt:304`
  - root-loop-header no-synthetic-entry-copy coverage
- `src/passes/ssa_nomerge_test.mbt:526`
  - result-typed-`if` merge coverage
- `src/cmd/cmd_wbtest.mbt:2394`
  - debug-artifact CLI replay coverage
- `src/cmd/cmd_wbtest.mbt:2434`
  - extracted `Func 523` writeback-type-mismatch retirement check

## How the local pass works today

## 1. The main HOT path is tiny because it delegates almost everything to local SSA destruction

`ssa_nomerge_run(...)` is intentionally short.
It does this:

1. bail out if the function has no local writes
2. require CFG
3. require local SSA
4. bail out if there are neither overlay phis nor local-set/local-tee SSA defs worth rewriting
5. call `@ir.ssa_destroy_into_hot(func, cfg, ssa)`
6. mark the function mutated only if the HOT revision changed

That means the main local algorithm is **not** written in `src/passes/ssa_nomerge.mbt` itself.
The file is mostly a thin pass wrapper around the general HOT SSA destruction machinery.

## 2. The real HOT rewrite surface lives in `ssa_destroy.mbt`

The local destruction helper is the reason Starshine differs so much from Binaryen's no-merge mode.

`ssa_destroy_into_hot(...)`:

- assigns concrete locals to SSA values,
- collects phi-input copies per predecessor block,
- schedules those copies safely,
- inserts explicit predecessor copy nodes,
- and rewrites local gets/sets/tees back onto the chosen concrete locals.

That is closer in spirit to upstream Binaryen full `--ssa` destruction than to upstream `ssa-nomerge`.
The key consequence is:

- current Starshine may materialize merge traffic explicitly,
- while upstream Binaryen `ssa-nomerge` deliberately keeps merge reads on canonical original slots instead.

## 3. Overlay phis are first-class local rewrite triggers

`ssa_nomerge_needs_rewrite(...)` returns true when either:

- `ssa.phis.length() != 0`, or
- any SSA value origin came from a `LocalSetDef` or `LocalTeeDef`

So the local pass treats overlay phi presence itself as enough reason to run.
That makes sense in a HOT-SSA-based implementation, because the interesting work is often in how those phis are destroyed back into ordinary locals.

This is another point where the local strategy should not be conflated with Binaryen's no-merge rule.

## 4. The raw path is a second real strategy, not just a small optimization

`run_hot_pipeline_raw_ssa_nomerge(...)` is a real special-case implementation family.
It does not merely short-circuit into the HOT pass wrapper.

Its top-level split is:

- skip entirely if there are no writes and no default-local reads to materialize
- use a structured recursive raw rewrite when the function has structured control and the heuristic limits still allow it
- otherwise use a cheaper straight-line alias rewrite

That means local `ssa-nomerge` has **two** practical implementations today:

- lifted HOT SSA -> destroy back into HOT locals
- raw structured / straight-line local alias rewriting

Any future maintenance or parity discussion needs to say which one it is talking about.

## 5. The straight-line raw path is an alias allocator, not a CFG no-merge proof

`run_hot_pipeline_raw_ssa_nomerge_straight_line(...)` keeps arrays for:

- current alias per original local
- canonical alias per original local
- initialized-local state
- extra local types for fresh locals

Its main rule is syntactic and local:

- if a write still owns the canonical slot, has a later read, and has no later write before that use story is over, it may stay canonical
- otherwise the raw path allocates a fresh local for the write and retargets subsequent reads to that alias

This is useful, but it is much simpler than Binaryen's whole-function LocalGraph reachability story.
So the raw straight-line path should be taught as:

- a local alias rewrite heuristic that approximates the shape payoff,
- not as a source-level reproduction of upstream `SSAify(false)`.

## 6. The structured raw path preserves branch merges by writing into canonical join locals

`run_hot_pipeline_raw_ssa_nomerge_structured(...)` delegates to the recursive raw instruction rewriter.
That helper can emit the local shape the focused tests lock in:

- rewrite branch-local writes onto fresh branch-specific locals
- then insert explicit `local.get fresh -> local.set canonical-join` copies before leaving the predecessor region

That is why the local branch-join and typed-`if` tests show explicit predecessor-copy style lowering.
It is not an accident.
It is the intended local representation boundary.

## 7. Default local reads are explicitly materialized locally too

The raw helper family also materializes default local reads directly when a local has never been initialized in the relevant raw model.
That mirrors one part of upstream Binaryen's visible behavior, but the implementation route is different:

- Binaryen uses LocalGraph and `nullptr` entry sources inside `SSAify.cpp`
- Starshine raw mode uses explicit initialized-local tracking plus `run_hot_pipeline_raw_append_local_read(...)`

So the shared beginner lesson is still valid:

- default entry values may become explicit literals

But the local mechanism is repo-specific.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `ssa-nomerge` is a LocalGraph-based no-merge rewrite that refuses to materialize merge locals
- current Starshine `ssa-nomerge` is a HOT-SSA roundtrip plus raw-fallback family that **can** re-externalize phi traffic through explicit predecessor copies

That difference is visible in both the code and the tests.

So the safe local teaching headline is not:

- “Starshine already implements Binaryen `ssa-nomerge`.”

It is:

- “Starshine implements the same broad early-SSA-cleanup goal, but with a very different local representation strategy.”

## Current local tests and what they prove

The focused tests in `src/passes/ssa_nomerge_test.mbt` currently prove these local contracts:

- straight-line local writes can stay canonical on simple shapes
- repeated straight-line aliases can move onto fresh locals
- dead param writes and tees can be redirected to fresh locals
- structured param writes may remain on canonical param slots
- branch joins lower through explicit predecessor copies
- loop-carried locals lower before the backedge
- root loop headers avoid synthetic entry copies
- structured early-return and block-target branch families preserve a canonical join local story
- result-typed `if` branch merges can be rewritten through fresh branch locals plus a shared canonical join local
- reduced unreachable compare-carrier followups from the artifact slice remain valid

The CLI tests in `src/cmd/cmd_wbtest.mbt` add two higher-level proofs:

- the checked-in debug artifact still replays successfully under `--ssa-nomerge`
- the extracted `Func 523` slice no longer records the old writeback type-mismatch skip that earlier parity notes had singled out

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree hot pass,
- a HOT-SSA destruction port with explicit predecessor-copy lowering,
- plus a separate raw-fallback implementation family,
- and **not** a direct AST clone of upstream Binaryen `SSAify(false)`.

Future work on this pass should answer one question explicitly:

- are we preserving the current HOT-SSA-destruction strategy,
- or are we trying to move the local behavior closer to Binaryen's true no-merge LocalGraph contract?

Those are materially different goals, and the wiki should keep that difference explicit.