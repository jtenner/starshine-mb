---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
related:
  - ./index.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# Binaryen `merge-locals` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/MergeLocals.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- The pass contract surface also depends directly on:
  - `src/pass.h`
  - `src/ir/local-graph.h`
  - `src/ir/LocalStructuralDominance.h`
  - `src/passes/pass-utils.h`
- The shipped behavior examples come from `test/lit/passes/merge-locals.wast`.
- As of the 2026-04-23 spot check, reviewed current `main` did not show a teaching-relevant drift beyond the claims on this page.

## High-level intent

Binaryen uses `merge-locals` to collapse families of equivalent alias locals before later cast, local-type, and slot-sharing cleanup passes run.

That sentence is true but incomplete.
The reviewed source shows a much sharper contract:

- start from a simple value-producing `local.set`
- use `LocalGraph` influence facts to find the gets and copy sets tied to that root
- use `LocalStructuralDominance` plus equivalent-copy checks to prove other locals are just structurally identical wrappers around the same source story
- choose one existing local as the winner
- rewrite dominated gets and redundant copy sets to that winner

So the real question is not:

- “which locals have one set?”

It is:

- “which local families are provably the same simple value story modulo equivalent copy wrappers?”

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Declare pass properties | `isFunctionParallel() == true` and `invalidatesDWARF() == true` | This is a per-function rewrite that openly invalidates DWARF instead of using a local-name bailout |
| Build graph facts | Create `LocalGraph`, then compute ordinary influences and set influences | Find value roots plus copy/use structure across the function |
| Seed candidate roots | Consider simple root `local.set`s from the graph's set-influence map | Keep the pass small and value-rooted |
| Prove equivalent copy wrappers | Use `LocalStructuralDominance` and `EquivalentCopies` checks | Distinguish true equivalent alias locals from merely similar ones |
| Choose one existing target local | Pick one already-existing local in the family, preferring the one that minimizes rewrites | Normalize around an existing slot rather than inventing a new temp |
| Materialize rewrites | Redirect dominated gets and remove or retarget equivalent copy sets | Turn proof into concrete local cleanup |

## Phase 1: pass properties are part of the contract

`MergeLocals` reports two easy-to-miss properties in the pass source:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

That means the reviewed `version_129` story is **not**:

- skip named-local functions to avoid metadata trouble

The older dossier preserved that stale explanation, but the reviewed pass source does not.
The durable rule is simpler:

- Binaryen treats this as a function-parallel optimization and explicitly declares DWARF invalidation.

## Phase 2: the graph setup is two-part, not just “one-set local” analysis

Inside `doWalkFunction(...)`, the pass builds a `LocalGraph` and then calls:

- `computeInfluences()`
- `computeSetInfluences()`

That distinction matters.
The pass needs both:

- ordinary get/use influence facts
- set-rooted influence facts

The older dossier over-focused on one local having one set.
The reviewed source is more operational:

- iterate value-producing root sets from the set-influence map
- then reason outward from those roots through ordinary influences, copy sets, and structural dominance

## Phase 3: candidate roots are simple sets, not arbitrary locals

The positive root is a `local.set` whose value is simple enough under `FunctionUtils::isSimple(...)`.
That means `merge-locals` is still effect-aware and intentionally conservative, but the conservatism is attached to the **root set value**, not to the old “exactly one set per local plus maybe fresh temp” story.

This keeps the pass out of:

- effectful or trap-sensitive producer families
- large control-heavy producers
- locals whose surrounding rewrite proof depends on more than equivalent copies and dominance can justify

## Phase 4: equivalent-copy proof is the real heart of the pass

The reviewed source introduces a concept the older dossier did not teach clearly enough:

- `EquivalentCopies`

Binaryen does not just say “local B copies local A.”
It checks whether a local's wrapper copy set is structurally equivalent to the root story and whether that equivalence is valid under `LocalStructuralDominance`.

That is why the pass can merge more than adjacent copies but still remain much narrower than global slot coloring.

The durable mental model is:

- a root set provides the source value story
- equivalent copy sets prove that some other locals are only wrappers around that same story
- structural dominance proves the rewritten gets are actually safe to retarget

## Phase 5: target selection chooses one existing local

The older dossier claimed a split between:

- reuse an old source local, or
- allocate one fresh canonical temp

That is not the reviewed `version_129` contract.
The pass source instead picks one **existing** target local among the compatible locals in the family.
The practical reason is rewrite cost:

- if one existing local already serves many gets or is otherwise a cheaper pivot, use it as the winner
- rewrite the equivalent copy locals around that winner

So a better beginner description is:

- Binaryen picks the best existing local in the equivalent family and collapses the others into it

not:

- Binaryen invents one new canonical temp for each merge family

## Phase 6: the rewrite surface is dominated gets plus equivalent copy sets

Once the pass has:

- a simple root set
- a compatible family of equivalent copy locals
- one chosen target local

it rewrites two main things:

- dominated `local.get`s can retarget to the chosen local
- redundant equivalent copy `local.set`s can disappear or retarget because their wrapper role is no longer needed

The visible user-facing effect is still “fewer alias locals and fewer redundant copies,” but the source-backed explanation is now more precise.

## Scheduler placement is part of the meaning

`pass.cpp` inserts `merge-locals` only when:

- `options.optimizeLevel >= 3`, or
- `options.shrinkLevel >= 2`

and it places the pass here in the stronger local-cleanup cluster:

- after `heap2local`
- before `optimize-casts`
- before `local-subtyping`
- before `coalesce-locals`

That placement is not accidental.

### Why after `heap2local`

`heap2local` can create more local traffic and more trivial copy wrappers.
`merge-locals` then gets a richer alias-local surface to collapse.

### Why before `optimize-casts` and `local-subtyping`

Binaryen wants some copy-wrapper cleanup done before cast cleanup and local-type sharpening reason about the local surface.

### Why before `coalesce-locals`

`merge-locals` handles narrow equivalent-copy families first.
`coalesce-locals` later handles broader liveness/interference-driven slot sharing.
The two passes are complementary, not redundant.

## What the pass does **not** do

Binaryen `merge-locals` does **not**:

- run in the ordinary no-DWARF `-O` / `-Os` path used as the repo's canonical parity baseline
- operate as a generic “any local with one set” merger
- create the fresh canonical temp-local story taught in the older dossier
- rely on the stale named-local early bailout explanation
- replace `local-subtyping`, `optimize-casts`, or `coalesce-locals`
- perform full liveness coloring or interference minimization

The real contract is smaller and sharper than the name suggests.

## Bottom line

Binaryen `merge-locals` is a higher-aggression local cleanup pass that starts from simple root sets, proves equivalent copy wrappers with `LocalGraph` plus `LocalStructuralDominance`, chooses one existing target local, and rewrites dominated gets and redundant copy sets around that winner.

That corrected description is the behavior a future Starshine port must preserve.
