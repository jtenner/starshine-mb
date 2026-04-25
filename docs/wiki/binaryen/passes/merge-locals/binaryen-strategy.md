---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Binaryen `merge-locals` strategy

## Source rule

Use Binaryen `version_129` plus the 2026-04-25 current-`main` recheck as the source oracle for this page.
The corrected source-backed owner surface is:

- `src/passes/MergeLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/local-graph.h`
- `test/lit/passes/merge-locals.wast`

The earlier living page's `LocalStructuralDominance`, `EquivalentCopies`, and `pass-utils.h` explanation is superseded for `merge-locals`; those names were not part of the reviewed implementation contract.

## High-level intent

Binaryen uses `merge-locals` to reduce redundant local traffic created by simple single-set locals.
It is stronger than a peephole because it uses `LocalGraph` influence information, but it is much narrower than [`../coalesce-locals/index.md`](../coalesce-locals/index.md) because it does not perform liveness/interference slot coloring.

The accurate short form is:

1. skip debug-name-sensitive functions
2. build an eager `LocalGraph`
3. find locals with exactly one set
4. require a simple set value and a consistent influenced-get story
5. either reuse a small source-local chain or create a fresh temp
6. retarget influenced gets and remove redundant sets

## Strategy table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Function gate | Skip functions that have local names | Preserve useful debug-facing local names instead of worsening them |
| Graph setup | Build `LocalGraph(getFunction(), false)` and compute ordinary plus set influences | Recover enough set/get flow to rewrite beyond adjacent copies |
| Candidate scan | Visit locals with exactly one set in the graph | Keep the transform small and provable |
| Safety gate | Require a present, simple set value and consistent influenced gets | Avoid duplicating effects/traps or retargeting gets fed by another set |
| Target choice | Prefer a small source-local chain; otherwise allocate a fresh temp | Avoid unnecessary temps when a source local is safe, but still merge nontrivial simple values |
| Materialization | Rewrite influenced gets, insert / keep the target set, replace redundant sets | Turn the graph proof into concrete IR cleanup |

## Phase 1: local names are a real bailout

The reviewed `MergeLocals.cpp` still skips a function when it has local names.
The source comment frames local names as useful debug information.

That means the 2026-04-23 dossier's statement that Binaryen no longer uses this bailout was wrong for the reviewed sources.
A future Starshine port should decide deliberately whether to mirror this exact debug-name boundary or document a different local policy.

## Phase 2: eager `LocalGraph` is the analysis engine

The pass constructs a `LocalGraph` in non-lazy mode, then calls:

- `computeInfluences()`
- `computeSetInfluences()`

This gives it two related facts:

- which local gets are influenced by which sets
- which sets influence which other local surfaces

The graph allows shapes like branch, DAG, loop-backedge, and order-sensitive copy families to be reasoned about without making the pass a full dataflow optimizer.

## Phase 3: candidates are one-set locals

For each local, Binaryen checks the graph's set list.
The local must have exactly one set.
That set must have a value.

This is the key correction from the stale 2026-04-23 page:

- the source-backed pass really does start with a one-set-local rule
- it does not start from an abstract root set plus equivalent-copy wrapper proof

## Phase 4: the set value must be simple

Binaryen then checks whether the set value is simple enough to move.
The practical meaning for readers is:

- constants and plain local gets are in-scope
- complex computations, calls, and effectful/trap-sensitive expressions are out-of-scope

That preserves evaluation order and trap behavior.

## Phase 5: all influenced gets must agree on the same set

For the candidate local, the pass inspects influenced gets.
If any influenced get is fed by a different set, the candidate fails.

That rule is why extra sets and ambiguous control-flow families bail out even when the code still “looks like local copying” to a human reader.
The pass only rewrites when `LocalGraph` preserves one clean set/get story for the local.

## Phase 6: source-local reuse versus fresh-temp materialization

Binaryen has two output modes.

### Reuse an existing source local

When the candidate's single set is a `local.get` from a small enough source-local chain, Binaryen can retarget uses to the existing source local.
This is the cheapest case: fewer locals and fewer sets without adding a temp.

### Create a fresh temp

When the value is still simple but is not a tiny reusable source-local chain, Binaryen creates a fresh local temp, stores the simple value there, retargets influenced gets, and removes the old redundant sets.

So the older “fresh-temp canonicalization” idea was not entirely wrong; what was wrong was the 2026-04-23 correction that removed it and replaced it with an `EquivalentCopies` target-selection model.

## Scheduler placement

`pass.cpp` inserts `merge-locals` only under stronger settings:

- `options.optimizeLevel >= 3`, or
- `options.shrinkLevel >= 2`

It sits after `heap2local` and before:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

This explains why Starshine tracks it as saved-`-O4z` relevant but not part of the canonical no-DWARF `-O` / `-Os` path.

## What the pass does not do

Binaryen `merge-locals` does **not**:

- run in the ordinary no-DWARF `-O` / `-Os` path used as this repo's baseline
- merge arbitrary locals that merely have compatible types
- perform liveness/interference slot coloring
- refine local types
- use `LocalStructuralDominance` or `EquivalentCopies` in the reviewed implementation
- replace [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

## Bottom line

Binaryen `merge-locals` is a higher-aggression one-set-local cleanup pass: it uses `LocalGraph` to prove that a local's influenced gets all come from one simple set, then rewrites that local either to a small existing source-local chain or to a fresh temp.
That corrected model is the one a future Starshine port should preserve.
