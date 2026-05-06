---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md
  - ../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./historical-lineage-and-modern-supersession.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# Binaryen strategy for local `remove-unused`

## Upstream source rule

Use two different upstream source horizons here:

- **historical oracle** for what the local alias most likely means:
  - commit `5881b541a4b276dcd5576aa065e4fb860531fc7b`
  - where Binaryen publicly registered `remove-unused-functions`
- **modern oracle** for what Binaryen exposes now:
  - `version_129`
  - current `main` spot-checks on 2026-04-25 and 2026-04-27 for registration drift
  - where Binaryen exposes `remove-unused-module-elements` but no `remove-unused` or `remove-unused-functions`

That split is the whole point of this dossier.

## The key conclusion in one sentence

The local Starshine registry name `remove-unused` is best understood as a stale shorthand for historical upstream `remove-unused-functions`, a small function-only reachability pass that Binaryen replaced in 2016 with the broader `remove-unused-module-elements` pass.

## What the old upstream pass really was

The historical `RemoveUnusedFunctions.cpp` implementation was tiny.

It did four real things:

1. collect root functions
2. run direct-call reachability from those roots
3. erase unreachable functions
4. rebuild the function map

That means the old pass was:

- a **module pass**
- **function-only**
- based on **direct call graph reachability**
- conservative about indirect calls by rooting all functions named in table segments

It was **not**:

- modern RUME
- a general declaration-pruning pass
- a function-type cleanup pass
- a body optimizer

## Historical root set

The old pass rooted functions from exactly these places:

- the start function
- exported functions
- function names listed in table segments

That root set matters because it explains both the power and the limitation of the pass.

### Why table segments mattered

The old pass did not try to reason precisely about indirect-call reachability.
Instead, it treated every function named in a table segment as live.

That is a safe but conservative rule.

## Historical reachability engine

After collecting roots, the pass used `DirectCallGraphAnalyzer`.

That tells us the old algorithm followed only:

- direct call edges
- from the root functions above

So the old pass was a classic small dead-function-elimination pass.

## Historical rewrite effect

When a function was unreachable, the old pass:

- erased it from `module->functions`
- then called `module->updateFunctionsMap()`

That is a much narrower rewrite surface than modern `remove-unused-module-elements`, which must also maintain many non-function indices and declaration kinds.

## The supersession event

Commit `98e9e604...` is the important turning point.

That commit:

- added `RemoveUnusedModuleElements.cpp`
- changed public pass registration from `remove-unused-functions` to `remove-unused-module-elements`
- changed the public factory declaration accordingly
- updated default-pass scheduling to use the new broader pass

So the lineage is not subtle.
Binaryen did not merely add another sibling.
It replaced the historical function-only public pass with a broader module-element pass.

## What current Binaryen exposes instead

Current `version_129` `pass.cpp`, with narrow current-`main` spot checks on 2026-04-25, 2026-04-27, and 2026-05-06, registers these relevant names:

- `remove-unused-brs`
- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`
- `remove-unused-names`
- `remove-unused-types`

And it does **not** register:

- `remove-unused`
- `remove-unused-functions`

That modern absence is a first-class documentation fact.

## Why the local alias is easy to mis-port

A future Starshine porter could make three different mistakes.

### Mistake 1: treat `remove-unused` as a current alias for RUME

That would lose the historical distinction between:

- old function-only direct-call reachability
- modern multi-kind declaration pruning

### Mistake 2: treat `remove-unused` as a still-public upstream spelling

Current `version_129` sources and help tests show that this is false.

### Mistake 3: invent a new undefined catch-all pass contract

The historical upstream evidence already gives us a better explanation.
There is no need to invent one.

## Relationship to modern `remove-unused-module-elements`

Modern RUME is the closest modern replacement, but the two contracts are not the same.

### Old `remove-unused-functions`

- roots start/export/table-segment functions
- follows direct calls
- deletes unreachable functions
- updates the function map

### Modern `remove-unused-module-elements`

- works on many declaration kinds
- handles stronger-vs-reference-only reachability distinctions
- prunes function types
- can weaken or null out surviving non-function declarations instead of simply deleting them
- has much broader index-remap obligations

So the correct relationship is:

- **successor / replacement**, not **exact synonym**

## Practical porting rule

If someone wants to port the local registry entry literally, ask first:

- do we want the historical upstream function-only pass?
- or do we actually want modern `remove-unused-module-elements`?

For current Binaryen parity, the answer is almost certainly:

- modern `remove-unused-module-elements`

For historical registry cleanup and naming honesty, the answer is:

- document `remove-unused` as the stale alias of the old function-only pass lineage

For the Starshine-specific decision matrix, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Most important preservation rules for the wiki

1. Keep the historical upstream name `remove-unused-functions` explicit.
2. Keep the 2016 supersession by `remove-unused-module-elements` explicit.
3. Keep current upstream absence explicit.
4. Keep the split from body-cleanup passes like `remove-unused-names` and `remove-unused-brs` explicit.
5. Keep the split from GC/type cleanup like `remove-unused-types` explicit.

## Best beginner summary

If someone remembers only one sentence, it should be this:

> Local `remove-unused` is not a current Binaryen pass name; it is best read as a stale shorthand for old upstream `remove-unused-functions`, which only removed unreachable functions and was later replaced by the broader `remove-unused-module-elements` pass.

## Sources

- [`../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md`](../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`](../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
