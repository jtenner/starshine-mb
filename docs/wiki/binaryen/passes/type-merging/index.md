---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../unsubtyping/index.md
  - ../merge-similar-functions/index.md
---

# `type-merging`

## Role

- `type-merging` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `type-merging` slice**.
- Upstream `pass.cpp` describes it very briefly as:
  - `merge types to their supertypes where possible`

That summary is true, but too small.

A better beginner summary is:

- Binaryen looks for **private GC heap types that are still used but no longer observably different** from some supertype or sibling,
- proves equivalence with a cast-aware partition-refinement algorithm over the heap-type graph,
- rewrites the module to merge those types,
- and refinalizes afterwards when exact-LUB-sensitive expression types may have changed.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is an explicit tracker expansion for another real local registry pass.
- `type-merging` sits directly beside already-documented GC/type neighbors like `type-refining`, `signature-*`, `remove-unused-types`, `abstract-type-refining`, and `unsubtyping`, but it solves a different problem from all of them.
- It is easy to misread from the name alone as “dead type cleanup” or “duplicate type removal.” The real pass is richer: it is a **late closed-world equivalence merge over private used types**.
- The pass comment also says it can unlock later size optimizations like function merging, so it matters to future shrink-oriented work even though it is outside today's open-world no-DWARF path.

## Beginner summary

A good beginner mental model is:

- a module has several private heap types that still appear in code
- some of them no longer matter as separate runtime identities
- Binaryen checks whether casts, exactness, public visibility, field refinements, and child-type structure still distinguish them
- if not, Binaryen merges them into an earlier safe target type
- then it rewrites all the module's type references consistently

So this pass is best taught as:

- **late private heap-type compaction by provable equivalence**
- not `remove-unused-types`
- not type inference
- not a simple textual deduplicator

## Most important durable takeaways

- The pass only runs when **GC is enabled** and **`--closed-world`** is set.
- Only **private** original heap types are merge candidates.
- Observable cast sites block merges:
  - `ref.cast`
  - exact casts
  - `ref.test`
  - `br_on_cast`
  - `call_indirect`
- The implementation treats the type graph as a **partitioned DFA** and refines partitions to find true equivalence classes.
- Descriptor chains are merged as **linked units**, not as independent nodes.
- Binaryen first merges into identical **supertypes**, then iteratively merges identical **siblings**.
- The pass may need **`ReFinalize`** afterwards because exact result types and LUBs can sharpen after merging.
- The 2026-04-24 raw primary-source capture keeps the official `version_129` release provenance explicit: the reviewed GitHub release page showed publish date **2026-04-01 14:31**.
- A narrow 2026-05-05 current-`main` recheck on the owner file, registration surface, helper headers, and dedicated lit file did not expose teaching-relevant contract drift, so `version_129` remains the source oracle for this dossier. The new freshness bridge now lives beside the original tagged capture and the new Starshine port-readiness page.

## What this pass sounds like versus what it actually does

What it sounds like:

- delete duplicate or redundant type declarations

What it actually is in `version_129`:

- a closed-world, GC-only, module-scale heap-type graph pass with:
  - visibility filtering
  - cast observability analysis
  - topological supertype ordering
  - DFA partition refinement
  - manual post-split correction for supertype-only safety
  - whole-module `TypeMapper` rewriting
  - possible refinalization

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, helper dependencies, main phases, and neighboring pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./dfa-partitions-casts-and-refinalization.md`](./dfa-partitions-casts-and-refinalization.md)
  Focused guide to the easiest part to misunderstand: why the pass is a partition-refinement problem, how cast observability blocks merges, and why `ReFinalize` is part of correctness.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, preserved, bailout, and known-limitation module families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: boundary-only registry entry, honest active-request rejection, no owner file or backlog slice, reusable local type-section surfaces, and the shared type-graph infrastructure a future closed-world module pass would need.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Future-port bridge covering exact local code locations, validation ladder, GC / closed-world gate sequencing, and the Binaryen oracle path for an eventual implementation.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-merging` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from `remove-unused-types` explicit: that pass removes dead private type declarations, while this pass merges **live** private types that are no longer observably distinct.
- Keep the late-pass framing explicit too: `type-merging` belongs after type-sensitive optimization has already benefited from a richer type graph.

## Sources

- [`../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md)
- [`../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md`](../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md)
- [`../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`](../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md`](../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast>
