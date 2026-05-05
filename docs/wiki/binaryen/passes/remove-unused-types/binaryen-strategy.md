---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0477-2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
---

# Binaryen `remove-unused-types` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass, anchored by [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md).

Primary files:

- `src/passes/RemoveUnusedTypes.cpp`
- `src/passes/pass.cpp`
- `src/ir/type-updating.h`
- `src/ir/module-utils.h`
- `test/lit/passes/remove-unused-types.wast`

A 2026-05-05 current-main recheck on the same owner / registration / helper / test surfaces again did not surface teaching-relevant drift from the corrected `version_129` story.
That is still not a whole-repo equivalence proof.

## Correction from the older dossier

The older 0149 research note said the pass file performed a pass-local optimization-level gate, collected public and used types itself, copied whole live private rec groups into a local builder, and handed that builder to `GlobalTypeRewriter`.
That is now superseded.

The actual `version_129` pass body is much smaller:

1. return immediately if the module has no GC features
2. fatally reject open-world execution
3. call `GlobalTypeRewriter(*module).update()`

Most of the algorithm lives in `type-updating.h`.

## High-level intent

Binaryen uses `remove-unused-types` to shrink and rebuild the heap-type graph of a **closed-world GC module** after earlier cleanup/refinement has made private heap types unnecessary.

A precise summary is:

- preserve public type groups as external-boundary anchors,
- collect heap types that are still used in IR,
- remove private heap types that are not used,
- rebuild surviving private types in dependency order,
- then update all module type uses through the new mapping.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Pass-file gate | `RemoveUnusedTypes.cpp` returns on no-GC modules and fatally rejects `!closedWorld` | The transform is only meaningful for GC type graphs and is only correct under closed-world assumptions |
| Scheduler placement | `pass.cpp` adds the pass in the closed-world GC/type optimization neighborhood under the broader optimization-level checks | The standalone pass file does not own the optimization-level policy; the default pass runner does |
| Collect type metadata | `GlobalTypeRewriter` gathers used IR heap types and public/private visibility data | Establish which old types can disappear and which groups are externally anchored |
| Public group anchoring | Public groups are remembered separately | Public type identity / grouping must not be casually reshaped away |
| Private predecessor graph | Private supertypes and described-type dependencies become ordering edges | Rebuilt private types must still reference already-available private dependencies |
| Sort private survivors | Private used types are topologically sorted with original index tie-breaking | Keeps the rebuild deterministic and dependency-safe |
| Rebuild private types | Surviving private heap types are copied through a mapper into a fresh private group | Drops unused private types and rewires private references to new heap types |
| Rewrite module | Functions, locals, globals, tables, elems, tags, and instruction types are remapped | The output must be a valid whole-module type graph, not just a pruned type list |

## Phase 0: GC and closed-world are part of correctness

`RemoveUnusedTypes::run(Module* module)` first checks GC features.
No-GC modules have no relevant GC heap-type graph to shrink, so the pass returns.

The same pass body then treats open-world execution as an error, not a quiet no-op.
That matters for teaching:

- default Binaryen scheduling should only reach the pass in closed-world mode,
- explicit user invocation in open world is rejected,
- a Starshine port should not silently run this rewrite in an open-world module.

## Phase 1: default scheduling still supplies optimization context

The corrected pass body does not have a direct `optimizeLevel >= 2` check.
The optimization-level story comes from `pass.cpp`, where Binaryen schedules `remove-unused-types` in the closed-world GC/type optimization cluster.

So the accurate split is:

- **pass file**: GC + closed-world correctness gate and transform dispatch
- **pass runner / scheduler**: when optimization presets choose to run it

## Phase 2: `GlobalTypeRewriter` collects the real keep/drop facts

`GlobalTypeRewriter` begins by collecting heap-type information with used-IR inclusion and visibility metadata.
That replaces the older mistaken model of a pass-local `UsedTypeScanner`.

The important categories are:

- public types / groups that anchor the external boundary,
- private types that still appear in used IR-facing type positions,
- private types that are not used and can disappear.

The scanner/helper surface is broad because heap-type uses can appear in more places than instruction operands alone:

- function signatures and locals,
- globals and initializers,
- tables and element segments,
- tags,
- heap-type fields,
- expressions and expression result types.

## Phase 3: public groups are anchors, not ordinary private candidates

The helper tracks public groups separately.
A public type can survive even if it does not look profitable internally.

That rule exists because public type identity and subtype/group structure can be observable across the boundary.
A closed-world optimizer can still make more assumptions than an open-world optimizer, but it must preserve the public anchor surface it has chosen to expose.

## Phase 4: surviving private types are dependency-sorted

`GlobalTypeRewriter` builds predecessor constraints among private types.
The important predecessor families are:

- private supertype dependencies,
- descriptor/described dependencies for private described types.

Those edges are then topologically sorted, with original type-index order used as a deterministic tie-breaker.

Beginner translation:

- Binaryen does not just keep surviving private types in arbitrary hash-table order.
- It creates a new private type order that still lets type definitions refer to their needed private predecessors.

## Phase 5: surviving private types are rebuilt into a fresh private group

The corrected source reading does **not** say that each used private member keeps its whole old rec group.
Instead, `GlobalTypeRewriter` rebuilds the surviving private types through a mapper into a new group.

This has two important consequences:

- a private type in the same old rec group as a used type can still disappear if it is not used by the surviving graph,
- old private rec-group boundaries are not the preservation unit.

The preservation units are better described as:

- public groups that anchor the boundary,
- plus used private heap types rebuilt under dependency constraints.

## Phase 6: module-wide remapping is the real output contract

After constructing the new type mapping, Binaryen updates all relevant type uses throughout the module.
This includes declaration-level and code-level surfaces.

A future port that only filters the type vector would be wrong.
The pass output is valid only if every surviving type reference points at the new heap-type graph.

## Scheduler placement explains the neighboring docs

The repo's current no-DWARF open-world page does not include `remove-unused-types`.
That is expected.

The pass belongs to Binaryen's closed-world GC/type cluster around pages such as:

- [`../type-refining/index.md`](../type-refining/index.md)
- [`../signature-pruning/index.md`](../signature-pruning/index.md)
- [`../signature-refining/index.md`](../signature-refining/index.md)
- [`../global-refining/index.md`](../global-refining/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- [`../global-struct-inference/index.md`](../global-struct-inference/index.md)
- [`../type-merging/index.md`](../type-merging/index.md)
- [`../unsubtyping/index.md`](../unsubtyping/index.md)

That placement also explains why the pass is module-owned and type-graph-owned, not a HOT expression peephole.

## What the pass sounds like versus what it actually is

What it sounds like:

- a dead-type sweep.

What it actually is:

- a closed-world GC type-graph rewrite with:
  - public-group anchoring,
  - used-private-type collection,
  - dependency-sorted private rebuilds,
  - descriptor/supertype ordering constraints,
  - and full-module remapping.

## Validation implications

A faithful implementation should validate with:

- no-GC no-op cases,
- open-world rejection/no-run behavior matching the chosen API,
- private unused singleton removal,
- private unused member removal even inside a larger old group when it is not referenced,
- used private type retention,
- public type/group retention,
- descriptor and private-supertype dependency ordering,
- final module validation after type remapping,
- parity against `wasm-opt --closed-world --remove-unused-types` for targeted fixtures.

## Bottom line

Binaryen `remove-unused-types` in `version_129` is a tiny pass-file wrapper around `GlobalTypeRewriter`.
Teach it as:

- **closed-world public-group-preserving private heap-type cleanup plus whole-module type remapping**.

Do not teach it as:

- a pass-local used-type scanner,
- a whole-old-rec-group retention rule,
- or a per-type delete loop.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for the corrected phase map: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
