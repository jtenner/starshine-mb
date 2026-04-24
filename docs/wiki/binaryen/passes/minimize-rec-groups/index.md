---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md
  - ../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./permutations-brands-and-public-conflicts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../late-pipeline-dispatch.md
  - ../remove-unused-types/index.md
---

# `minimize-rec-groups`

## Role

- `minimize-rec-groups` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139).
- Upstream Binaryen `pass.cpp` registers the public CLI name:
  - `minimize-rec-groups`
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `Split types into minimal recursion groups`

That summary is true, but too small.

A better beginner summary is:

- Binaryen computes the minimal private-type SCCs that must stay recursive for validation,
- but then refuses to accidentally merge distinct old types just because two newly split groups would have the same shape,
- so it disambiguates same-shape groups with valid permutations first,
- and only then falls back to compact synthetic brand types.

It also has two important boundary rules:

- only **private** types are rewritten
- but **public** rec-group shapes still act as immutable collision targets that private groups must not match

So this is not generic type cleanup.
It is **SCC-based rec-group minimization plus identity preservation under Binaryen's isorecursive type model**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `minimize-rec-groups` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `late-pipeline-dispatch` and tracker docs already record it as an upstream-only Binaryen pass name visible in public terminology and release-horizon checks.
- `agent-todo.md` still has **no dedicated `minimize-rec-groups` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - the pass is **GC-gated** but not closed-world-gated
  - it is **not** part of Binaryen's default no-DWARF optimize schedule in `version_129`
  - it rewrites only **private** types but must also avoid colliding with **public** rec-group shapes
  - minimizing SCCs alone is not enough because distinct old types can become indistinguishable under isorecursive typing if emitted group shapes collide
  - exactness matters only when it still affects the **written** type shape under the active feature set
  - the pass can **increase** type count by inserting synthetic brand types when that is the cheapest correct way to preserve distinction
  - subtype and descriptor constraints limit which permutations are valid

## Most important durable takeaways

- `minimize-rec-groups` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- In the reviewed `version_129` scheduler surface, it is an **explicit pass only**: registered in `pass.cpp`, but not inserted into the default optimize presets.
- The pass body checks:
  - GC features enabled
  - otherwise it returns immediately
- Only **private** types are optimized.
- Public rec groups are preserved but recorded as shape conflicts that private groups must avoid.
- The algorithm has two major halves:
  - compute minimal private SCCs
  - preserve nominal distinctness when emitted SCC shapes would otherwise collide
- Shape comparison is **feature-sensitive** because `RecGroupShape` compares types as they will be written under the active features.
- Exactness can therefore matter in one run and disappear in another.
- The pass prefers **valid permutations** of isomorphic groups before adding **brand types**.
- Brand insertion is part of the intended algorithm, not an accidental fallback.
- The final rewrite updates not just type definitions, but also type names and recorded indices.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen takes a rec group, runs SCCs, and emits the smaller groups.

The safer mental model is:

- Binaryen first finds the smallest private groups required by validation,
- then checks whether any two emitted groups would now have the same shape,
- then lazily canonicalizes isomorphic conflict classes,
- then uses only subtype/descriptor-valid permutations to separate those groups when possible,
- and only then adds compact brand types when permutations stop being enough.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a type-section shrink pass that always makes recursion groups smaller

What it actually is in `version_129`:

- a GC-only explicit module pass that:
  - collects private vs public heap-type visibility,
  - computes SCCs of the private type graph,
  - topologically repairs each SCC into a valid emitted order,
  - keeps all resulting private groups distinct from one another and from public groups,
  - uses feature-sensitive shape comparison,
  - tries permutations before brands,
  - and finally rewrites all module type uses and metadata.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` algorithm, helper dependencies, scheduler placement, and the exact phase structure.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `MinimizeRecGroups.cpp`, `pass.cpp`, `module-utils.h`, `type-updating.*`, `strongly_connected_components.h`, `topological_sort.h`, `disjoint_sets.h`, `wasm-type-shape.*`, and the official lit roster, plus the important fact that current `main` still matches `version_129` on the reviewed surfaces.
- [`./permutations-brands-and-public-conflicts.md`](./permutations-brands-and-public-conflicts.md)
  - Focused guide to the hardest half of the pass: why SCC splitting is not enough, how canonicalization and valid topological permutations work, when brands become necessary, how public groups constrain private output, and why exactness is feature-sensitive.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering independent-type splits, chain-vs-cycle boundaries, permutation wins, automorphism and subtype-order bailouts, descriptor/described ordering, exactness-feature toggles, public conflicts, and brand-heavy fallback families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: boundary-only registry entry, honest active-request rejection, active-preset omission, no owner file, no dedicated backlog slice, and the exact local rec-group/type-section code surfaces a future module pass would need to build on.

## Current maintenance rule

- Treat this folder as the canonical home for future `minimize-rec-groups` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the scheduler story honest:
  - Binaryen `version_129` registers the pass
  - but does **not** place it in the default optimize presets on the reviewed surface
- Keep the identity-preservation story explicit:
  - SCC splitting is necessary but insufficient
  - shape collisions are the hard part
  - brands are part of the real contract
- Keep the public/private split explicit instead of implying the pass can rewrite ABI-visible groups.
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md)
- [`../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md`](../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/strongly_connected_components.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/disjoint_sets.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-shape.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-type-shape.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
