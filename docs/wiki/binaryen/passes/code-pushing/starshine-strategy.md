---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
---

# Starshine Strategy For `code-pushing`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the concrete neighboring implementation areas the remaining port work must hook into.

## The honest current status

`code-pushing` now has an initial explicit HOT implementation in Starshine.
The owner file is `src/passes/code_pushing.mbt`.

The current implementation is deliberately a conservative subset, not a full Binaryen `CodePushing.cpp` port:

- it replaces a const-like `local.set` root immediately before a void `if` with `nop`
- it only moves a cloned `local.set` into a then/else arm when that single arm contains every read of the local
- it refuses later local reads, multiple writes, condition/else reads, non-void `if`s, and non-const/trapping values
- it is wired for direct pass execution, registry classification, hot dispatch, and CLI flag acceptance
- it is **not** scheduled in the public optimize/shrink presets yet

The remaining local strategy is parity and slot planning:

- keep the canonical no-DWARF slot documented
- keep the tuple-opt exact-slot gate honest until `simplify-locals-nostructure` exists and `code-pushing` has stronger Binaryen parity evidence
- keep the backlog slice focused on broader motion safety, segment sinking, profitability, and artifact validation
- teach the surrounding implemented and near-neighbor dossiers what this first subset does and does not promise

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner and focused tests
  - `src/passes/code_pushing.mbt`
  - `src/passes/code_pushing_test.mbt`
- active registry and exact-slot gate
  - `src/passes/optimize.mbt`
    - `pass_registry_entries()` now includes `"code-pushing"` as a hot pass
    - `tuple_optimization_exact_slot_prereqs_ready()` still requires both `code-pushing` and `simplify-locals-no-structure` to be active hot passes before tuple-opt can claim its Binaryen slot in public presets
- registry and command-surface proof
  - `src/passes/registry_test.mbt`
  - `src/cmd/cmd_wbtest.mbt`
- backlog and delivery plan
  - `agent-todo.md`
    - `CP` slice under the Binaryen no-DWARF default optimize pathway parity section
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the early slot where `code-pushing` belongs between `precompute` and `tuple-optimization`
- neighboring living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/precompute/index.md`
  - `docs/wiki/binaryen/passes/tuple-optimization/index.md`
  - `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`

That code-and-doc map lets readers jump directly from the upstream algorithm to the exact local owner file, tests, and remaining parity work.

## What Starshine currently does for this pass name

Today Starshine's behavior for `code-pushing` is active but deliberately limited.

### 1. The name is an active hot pass

`src/passes/optimize.mbt` now registers `code-pushing` as a `HotPass` rather than a removed compatibility name.
That means direct requests such as `--code-pushing` are accepted and route through the standard hot pipeline.

### 2. The implemented motion family is intentionally narrow

The first implementation handles one safe `optimizeIntoIf`-style shape:

- a root `local.set` immediately precedes a void `if`
- the set value is const-like (`const`, `ref.null`, or `ref.func`)
- the target local has exactly one write
- every read of that local is in exactly one `if` arm
- the pass replaces the existing `local.set` with `nop` and inserts a cloned `local.set` before the arm-local uses

The pass bails out instead of guessing for later local reads, multiple writes, condition or else reads, result-typed `if`s, and non-const or potentially trapping computations.

### 3. The tuple-opt preset gate is still honest

`tuple_optimization_exact_slot_prereqs_ready()` now sees `code-pushing` as active, but it still requires `simplify-locals-no-structure` before tuple-opt can claim its Binaryen slot in public presets.
The public `optimize` and `shrink` presets remain intentionally narrower until that missing neighbor and stronger `code-pushing` parity proof exist.

### 4. The remaining work is still planned as a parity slice

`agent-todo.md` keeps `code-pushing` under slice `CP` for the broader upstream concerns:

- generic contiguous segment sinking
- profitability heuristics
- trap and side-effect boundaries beyond const-like values
- branchy and one-arm-unreachable fixtures
- artifact and compare-pass validation against Binaryen

## The right remaining Starshine implementation shape

The current docs and neighboring passes strongly suggest that the remaining `code-pushing` port work should be taught as an **early-cluster HOT rewrite family**, not as an isolated generic optimizer.

Why:

- Binaryen runs it after `precompute`
- it is immediately followed by `tuple-optimization`
- the next intended neighbor is `simplify-locals-nostructure`
- Starshine already has explicit `precompute` and `tuple-optimization` dossiers explaining what those neighbors expect from the surrounding shape

So the local strategy beyond the first const-local-set subset should be thought of as:

1. extend the HOT-level representation of Binaryen's two upstream motion families
   - generic structured-segment sinking
   - stricter direct-`if` sinking
2. prove the same movement-safety boundaries locally
   - contiguous-suffix reasoning
   - effect and trap barriers
   - one-arm-unreachable versus two-arm-reachable split
3. keep the scheduler story honest
   - do not claim tuple-opt's exact public preset slot until the remaining neighbor and parity proof are real
4. preserve the handoff to later local cleanup neighbors
   - especially the still-missing `simplify-locals-nostructure` slot

In other words, the future port should slot into a local early optimization ecosystem that is already documented.

## The most important local dependency map

### Upstream `code-pushing` is now a partial left neighbor of local `tuple-optimization`

See [`../tuple-optimization/index.md`](../tuple-optimization/index.md).

Why it matters locally:

- Starshine already implements tuple optimization as an explicit hot pass
- the tuple dossier's exact Binaryen preset slot was blocked on both `code-pushing` and `simplify-locals-nostructure`; after this first `code-pushing` slice, the remaining blockers are `simplify-locals-nostructure` plus stronger code-pushing parity proof
- continued `code-pushing` work therefore unlocks truthful preset placement work, not just one isolated explicit pass flag

### Upstream `code-pushing` is also downstream of local `precompute`

See [`../precompute/index.md`](../precompute/index.md).

Why:

- Binaryen expects `code-pushing` to see a body already simplified by precompute-level folding
- Starshine already has the explicit upstream-aligned `precompute` surface
- remaining local port work should therefore validate not only `--code-pushing` in isolation, but also the real `precompute -> code-pushing` neighborhood

### The right immediate consumer after it is still the missing `simplify-locals-nostructure` slot

See [`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md).

Why:

- Binaryen uses `code-pushing` to make branch-local work more local before the early no-structure locals cleanup runs
- Starshine still tracks that right neighbor as removed, under the local spelling `simplify-locals-no-structure`
- remaining `code-pushing` work should therefore keep its interaction with that later locals cleanup explicit instead of trying to absorb all downstream cleanup itself

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- HOT-region candidate collection for contiguous movable suffixes
- local effect and use tracking broad enough for Binaryen's full segment sinking
- a direct-`if` rewrite engine that matches Binaryen's complete one-arm versus two-arm split for this pass
- pass-fuzz or debug-artifact parity evidence for the direct pass
- public-preset scheduling for the Binaryen slot

So the current repo status is best summarized as:

- active explicit hot pass
- conservative const-like single-consuming-arm local-set movement subset
- tuple-slot dependency still tracked
- backlog still tracks broader parity work
- scheduler slot still documented but not public-preset active

## Validation plan for the remaining port

The existing backlog plus neighboring pass docs imply the right validation ladder.
The remaining implementation should validate in this order:

1. reduced shape tests for the two upstream families
   - generic structured-segment suffix sinks
   - direct `if` sinks
   - one-arm-unreachable special cases
2. negative movement-safety tests
   - side effects, calls, throws, memory, table, and mutable-global barriers
   - default trap-sensitive bailouts
   - value-still-used-after-separator bailouts
   - EH-sensitive bailout families
3. scheduler-neighborhood interaction tests
   - `precompute -> code-pushing`
   - `code-pushing -> tuple-optimization`
   - later `code-pushing -> simplify-locals-nostructure` once that pass exists locally
4. artifact and oracle comparison
   - the `CP` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow.

## Bottom line

Current Starshine `code-pushing` strategy is honest registry and slot planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- tuple-opt's exact-slot gate intentionally depends on `code-pushing` still being absent, which keeps public presets honest
- `src/passes/optimize_test.mbt` locks that boundary in place
- the backlog already treats it as a real early-parity slice under `CP`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `precompute`, `tuple-optimization`, and `simplify-locals-nostructure` dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear pipeline dependency story**
- **clear neighboring implementation map for the eventual port**
