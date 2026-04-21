# 0157 - Binaryen `reorder-types` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `minimize-rec-groups` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes plus the newer upstream-only dossiers, expand into the remaining tracker-listed upstream-only pass with wiki status `none`.
- Create a new beginner-friendly dossier for `reorder-types`.
- File durable conclusions back into:
  - `docs/wiki/binaryen/passes/reorder-types/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

At that point:

- the main no-DWARF / saved-`-O4z` queue still had no pass with wiki status `none`
- the implemented-landing queue was already closed
- the newly added upstream-only dossiers for `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, `abstract-type-refining`, `unsubtyping`, and `minimize-rec-groups` were already covered
- the tracker still listed exactly one clear remaining upstream-only `none` candidate:
  - `reorder-types`
- `agent-todo.md` still has **no dedicated `reorder-types` slice**

So this run should not reopen an already-deep folder.
It should finish the last obvious `none` target in the tracker's additional upstream-only registry table.

I picked `reorder-types` for six repo-grounded reasons:

- It was the tracker’s clearest remaining `none` entry.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so it is a real Starshine-facing pass name.
- The late-pass terminology docs already record `ReorderTypes` as an upstream addition visible in public `version_125` release-note surfaces.
- It is closely related to already-documented neighbors that future Starshine work will likely consult together: `reorder-globals`, `minimize-rec-groups`, `remove-unused-types`, and the broader late GC/type/layout cluster.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- `agent-todo.md` has **no dedicated local slice for this pass**, so the durable wiki needs to say that explicitly instead of implying there is already a backlog contract.

## Source availability note

This runtime let me inspect the local Starshine repo and the already-filed Binaryen release-horizon docs, but it did **not** provide a live web-fetch tool for reopening raw upstream sources inside this thread.

So this note uses three evidence layers with different confidence:

1. **high-confidence local facts**
   - `reorder-types` is present in `src/passes/optimize.mbt` as a boundary-only pass name
   - it is absent from the canonical no-DWARF default optimize path page
   - the living late-pass docs already record `ReorderTypes` as an upstream pass addition called out by reachable `version_125` release notes
   - `agent-todo.md` has no dedicated slice
2. **high-confidence Binaryen-neighbor inference**
   - the pass is about type ordering / layout rather than deletion or refinement
   - it should be compared against adjacent Binaryen helpers and policies already visible in other type-layout dossiers, especially `type-updating.*`, `module-utils.*`, topological ordering utilities, and the subtype/descriptor ordering surfaces already exposed by `global-type-optimization` and `minimize-rec-groups`
3. **working-contract implementation inferences that need a web-enabled confirmation pass later**
   - likely exact helper file names and the dedicated lit file roster
   - the exact profitability heuristic details
   - whether the pass reorders individual heap types, whole rec groups, or both on every reviewed surface

That means this dossier is still useful and materially better than `none`, but it also carries explicit uncertainty labels where this thread could not directly re-open the upstream raw sources.

## Official Binaryen source inventory to confirm in the next web-enabled follow-up

The likely primary official sources for a direct `version_129` refresh are:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderTypes.cpp>
- pass registration and scheduler surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- likely helper surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
- likely official lit surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-types.wast>

If the next web-enabled thread finds additional dedicated test files such as descriptor / exactness / rec-group variants, it should fold them back into this dossier explicitly.

## Repo-local context used here

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`
- the already-deepened neighboring dossiers for:
  - `reorder-globals`
  - `remove-unused-types`
  - `global-type-optimization`
  - `minimize-rec-groups`

## High-level conclusion

Even before a web-enabled source refresh, the durable shape of `reorder-types` is already much clearer than the pass name alone suggests.

`reorder-types` is best understood as:

- an upstream **module pass**,
- currently **boundary-only** in Starshine,
- outside the repo’s canonical no-DWARF default optimize path,
- and conceptually a **type-index layout pass** that tries to put more profitable / frequently referenced heap types at smaller indices while preserving the validity constraints of the type graph.

The most important durable beginner-facing corrections are:

- this is **not** dead-type cleanup like `remove-unused-types`
- this is **not** rec-group splitting like `minimize-rec-groups`
- this is **not** field/signature refinement like `type-refining`, `signature-pruning`, `signature-refining`, or `global-type-optimization`
- the hard part is not “sorting a list”; it is **sorting under graph constraints**
- any real port must preserve both the **cost model** and the **type-validity ordering constraints**
- the rewrite surface is module-wide because changing heap-type order means rewriting all heap-type references plus metadata, not just the type section text

## Working contract for the pass

Based on the repo-local evidence and Binaryen’s nearby helper patterns, the safest current working contract is:

1. gather module heap types and how often each one is referenced
2. model ordering constraints that keep the rewritten type graph valid
   - at minimum: supertypes before subtypes
   - likely also: described types before descriptors on descriptor-enabled surfaces
   - rec-group boundaries or rec-group-local constraints must remain valid
3. estimate which types are most profitable to move earlier in the flat type-index space
4. reorder only when the estimated index-layout gain is worth it
5. rewrite the module’s type definitions and all type uses through a full type-remap pass
6. preserve semantics exactly; only the encoded layout and indices should change

This should be read as a **working algorithm contract**, not yet a line-by-line `version_129` proof.

## Scheduler placement conclusion

Local facts are clearer here than for the exact implementation details.

- `reorder-types` is present in Starshine’s local boundary-only registry.
- It is **not** present on the canonical no-DWARF `-O` / `-Os` path page.
- The current tracker already frames it as an **additional upstream-only registry pass**, not part of the main open-world parity queue.

So the durable scheduler conclusion for the living wiki is:

- treat `reorder-types` as an **explicit upstream pass name**, not a currently required default-preset slot for Starshine parity.

A future Starshine implementation should therefore treat scheduler placement as a policy decision, not as an already-mandated missing preset slot.

## Likely helper / analysis dependencies

The pass is almost certainly not a pure standalone sorter.
A future port should expect at least these dependency families:

- **module-wide type inventory / visibility / declaration scanning**
  - likely via `module-utils.*`
- **type-order legality helpers**
  - especially subtype-first or supertype-first ordering utilities
  - likely via `wasm-type-ordering.h` and/or topological-sort helpers
- **full-module heap-type rewriting**
  - likely via `type-updating.*`
- **metadata repair**
  - type names and recorded indices need updating after reorder
- **feature-sensitive shape rules**
  - because exactness / descriptors / rec-group formatting can affect what orders are legal or profitable

## Relationship to nearby passes

This pass matters more when compared against its neighbors:

- `remove-unused-types`
  - removes dead private heap types
- `minimize-rec-groups`
  - changes where rec-group boundaries are drawn and may add brands to preserve identity
- `reorder-types`
  - keeps the live type graph but changes the **order / layout** of type indices for size or locality reasons
- `reorder-globals`
  - the closest already-deepened teaching analogue in this repo: a frequency / cost-model layout pass whose real contract is constrained ordering rather than semantics-changing optimization

The clearest beginner contrast is:

- `remove-unused-types` changes **what exists**
- `minimize-rec-groups` changes **which recursion groups exist**
- `reorder-types` changes **where surviving types land in index space**

## Important shapes to teach

Even without the raw upstream file open in this runtime, the durable shape families are clear enough to document.

### Positive families

- a heavily referenced private heap type moves earlier so many uses get a smaller encoded type index
- an entire hot rec group moves earlier when the group must stay together
- hot child types can only move as far as their parent / descriptor constraints allow
- ties should stay stable unless the cost model has a reason to break them

### Negative / bailout families

- no-op on small or already-well-ordered modules
- no profitable move when legal constraints pin the current order
- no split of rec groups if the pass is only about reordering rather than regrouping
- no illegal parent-after-child or descriptor-after-described rewrite
- no metadata drift: every heap-type use and name/index table must be rewritten consistently

## Easy misunderstandings to prevent

### Misunderstanding 1: this is just `minimize-rec-groups`

No.
`minimize-rec-groups` changes rec-group boundaries and may add brands to preserve identity.
`reorder-types` is about index order and layout.

### Misunderstanding 2: this is just `remove-unused-types`

No.
Deletion and ordering are different passes with different safety obligations.

### Misunderstanding 3: “reorder” means any sort order is fine

No.
Type order is constrained by validity and helper invariants.
A profitable order that violates those constraints is not a legal rewrite.

### Misunderstanding 4: this is a local peephole pass

No.
Changing type indices is a module-wide rewrite.
Every declaration and code site that mentions a heap type must stay in sync.

### Misunderstanding 5: if a type is public, it can never participate in the cost model

That is still an open detail to confirm from upstream source.
The safer current statement is narrower:

- future work must verify exactly how Binaryen treats public or externally relevant types in the ordering algorithm,
- and the port must preserve that policy explicitly rather than guessing.

## What a future Starshine port must preserve

- Preserve the distinction between **layout optimization** and **semantic graph changes**.
- Preserve all ordering constraints required for valid rewritten type sections.
- Preserve stable full-module remapping of heap-type references, names, and recorded indices.
- Preserve any profitability threshold or no-op threshold that upstream uses; do not eagerly reorder every module just because a sort order exists.
- Preserve rec-group and subtype / descriptor legality boundaries exactly.
- Keep the scheduler story honest: this is an upstream explicit pass name, not part of the current no-DWARF parity queue.

## Follow-up questions for the next web-enabled thread

1. Does `version_129` `ReorderTypes.cpp` reorder flat heap types, whole rec groups, or both?
2. What exact cost model does it use: raw use counts, estimated LEB width, group size weighting, or something more subtle?
3. Does it skip work below a concrete threshold, like `reorder-globals` does for under-`128` globals?
4. What exact helper types and graphs does it use for legality constraints?
5. How does it treat public, imported, descriptor-bearing, or exact types?
6. What official lit files exercise the tricky boundaries?
7. Did current `main` drift relative to `version_129` on any of those surfaces?

## Files added or updated in this thread

- added `docs/wiki/raw/research/0157-2026-04-21-reorder-types-binaryen-research.md`
- added `docs/wiki/binaryen/passes/reorder-types/index.md`
- added `docs/wiki/binaryen/passes/reorder-types/binaryen-strategy.md`
- added `docs/wiki/binaryen/passes/reorder-types/ordering-cost-model-and-boundaries.md`
- added `docs/wiki/binaryen/passes/reorder-types/wat-shapes.md`
- updated `docs/wiki/binaryen/passes/index.md`
- updated `docs/wiki/binaryen/passes/tracker.md`
- updated `docs/wiki/index.md`
- updated `docs/wiki/log.md`

## Sources

Repo-local sources used directly in this thread:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`
- `docs/wiki/raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/index.md`
- `docs/wiki/binaryen/passes/reorder-globals/index.md`
- `docs/wiki/raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`

Official upstream surfaces to confirm in a web-enabled follow-up:

- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderTypes.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/topological_sort.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-types.wast>
