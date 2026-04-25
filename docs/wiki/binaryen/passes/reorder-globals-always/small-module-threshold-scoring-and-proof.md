---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md
  - ../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md
  - ../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderGlobals.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalStructInference.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals-real.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderGlobals.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals/size-model-and-dependency-order.md
  - ../global-struct-inference/closed-world-analysis-and-unnesting.md
---

# `reorder-globals-always`: small-module threshold, smooth scoring, proof surface, and no-drift result

This page is the compact source-confirmed answer to four recurring questions:

1. what exactly changes between `reorder-globals` and `reorder-globals-always`?
2. what exact formula does the sibling use in always mode?
3. which shipped tests directly prove the sibling contract?
4. has the reviewed `version_129` surface drifted on current `main`?

## One-sentence answer

`reorder-globals-always` is the same `ReorderGlobals.cpp` engine as ordinary `reorder-globals`, but it skips the ordinary `< 128`-globals bailout and scores later declaration slots with the exact smooth factor `1.0 + (i / 128.0)`, while keeping the same dependency and imports-first legality rules.

## The exact cutoff split

In the shared `run(Module* module)` implementation, ordinary production mode does this early:

- if `globals.size() < 128` and `always` is false, return immediately

That is the whole small-module split.
The sibling does not add a second algorithm for tiny modules.
It just keeps running the normal algorithm when the production pass would intentionally stop.

## The exact smooth scoring formula

The sibling-specific behavior is concentrated in `computeSize(...)`.
When `always` is true, Binaryen computes the estimated size contribution for each chosen slot as:

- `counts[indices[i]] * (1.0 + (i / 128.0))`

That means:

- index `0` costs `1`
- index `1` costs `129/128`
- index `2` costs `130/128`
- after `128` slots, the factor reaches `2`

This is deliberately smoother than the real stepped ULEB-size model.
It is meant to make small-module ordering decisions visible.

## What does **not** change

The always sibling still uses the same legality and selection core:

- the same dependency graph built from initializer `global.get` traffic
- the same `TopologicalSort::minSort(...)` framework
- imports before non-imports
- higher count before lower count
- original index as the tie break
- the same declaration-list rebuild plus `updateMaps()`

So `always` does **not** mean:

- ignore dependencies
- ignore imports
- switch to a name sort
- or become a generic global optimizer

## The strongest direct reason the sibling exists

The clearest real-world source proof is in `GlobalStructInference.cpp`.
After that pass adds helper globals, it checks `addedGlobals` and then runs a nested `PassRunner` containing:

- `reorder-globals-always`

The source comment says the goal is to sort the globals so that added ones appear before their uses.

So the sibling is not only a test convenience.
It is also an explicit small-module and repair-mode helper.

## Dedicated lit-backed proof surface

## 1. `reorder-globals.wast`

This is the main sibling-proof file.
It directly proves that small modules still show the algorithm's behavior under `--reorder-globals-always`:

- hotter independent globals move earlier
- `global.set` traffic counts too
- dependency chains block illegal moves
- mixed independent-plus-dependent modules can move only the independent hot global
- equal-cost cases prefer the earlier/original candidate
- the file comments explicitly reason using the same smooth `1`, `129/128`, `130/128` cost progression as the implementation

## 2. `reorder-globals-real.wast`

This is the production contrast file.
It explicitly says it needs `128+` globals before the non-`always` pass can visibly reorder anything.
That file proves the neighboring point the sibling depends on:

- ordinary `reorder-globals` is the real stepped-size production pass
- `reorder-globals-always` is the small-module/test/internal-fixup sibling

## Exact public identity proof

Even though the engine is shared, the sibling is a real public/test pass identity.
The official proof is split across two tiny source surfaces:

- `pass.cpp` registers `reorder-globals-always`
- `passes.h` declares `createReorderGlobalsAlwaysPass()`
- `ReorderGlobals.cpp` implements that constructor as `new ReorderGlobals(true)`

That is why the wiki should teach the sibling as a real pass, not as an unnamed mode.

## Current-main drift result

Reviewed again on 2026-04-25 using the source set captured in [`../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`](../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md):

- `version_129` `src/passes/ReorderGlobals.cpp`
- current `main` `src/passes/ReorderGlobals.cpp`
- the neighboring registration, constructor, internal-caller, and lit-test files listed in the raw manifest

Result:

- no teaching-relevant drift on the reviewed surface

So the `version_129` explanation on this page is still current for the reviewed behavior. This remains a narrow spot check, not a promise that every future Binaryen global-layout helper is unchanged.

## Starshine-local implication

The source proof above is upstream-only until Starshine grows a shared global-reorder module pass. [`./starshine-strategy.md`](./starshine-strategy.md) records the current local truth: the name is boundary-only, active requests are rejected, presets omit it, and any future port must repair numeric `GlobalIdx` users rather than relying on Binaryen-style name-based references.

## Beginner-safe summary

If you only remember one thing, remember this:

- `reorder-globals-always` is **not** a new global-layout algorithm
- it is the same one, but forced to run below the normal profitability threshold, with a smooth fake size model that makes tests and repair-driven small modules observable

## Sources

- [`../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`](../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md)
- [`../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md`](../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md)
- [`../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md`](../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderGlobals.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalStructInference.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals-real.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderGlobals.cpp>
