---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md
  - ../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./permutations-brands-and-public-conflicts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `minimize-rec-groups`: implementation structure and tests

This page exists because `MinimizeRecGroups.cpp` is not a self-contained “just run SCCs” file.
If you read only the top-level pass name, you will miss why Binaryen needs shape comparison, permutation search, and synthetic brand types.
The source URLs reviewed for this page are now captured in [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md), and the local Starshine status is mapped in [`./starshine-strategy.md`](./starshine-strategy.md).

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/MinimizeRecGroups.cpp` | Core pass logic: GC gate, visibility split, private SCC computation, valid-order repair, shape-conflict resolution, canonicalization, permutation/brand updates, and final rewrite |
| `src/passes/pass.cpp` | Registers the CLI pass name `minimize-rec-groups` and proves the reviewed `version_129` surface treats it as an explicit pass rather than a default optimize-preset slot |
| `src/ir/module-utils.h` | Supplies `collectHeapTypeInfo(...)`, which defines the whole-module private/public heap-type inventory the pass relies on |
| `src/ir/type-updating.h` / `src/ir/type-updating.cpp` | Supply `GlobalTypeRewriter::mapTypes(...)` and `mapTypeNamesAndIndices(...)`, which explain how the finished type rewrite is threaded through the module and metadata |
| `src/support/strongly_connected_components.h` | Supplies the generic Tarjan-style SCC utility that `TypeSCCs` builds on |
| `src/support/topological_sort.h` | Supplies `TopologicalOrders`, which enumerates valid intra-group orders while respecting subtype and descriptor constraints |
| `src/support/disjoint_sets.h` | Supplies the equivalence-class tracking used to organize shape-conflicting isomorphic groups |
| `src/wasm-type-shape.h` | Defines `RecGroupShape`, `ComparableRecGroupShape`, and `BrandTypeIterator`, which are the heart of shape comparison and brand synthesis |
| `src/wasm/wasm-type-shape.cpp` | Shows that rec-group comparison is done on types **as written given the active features**, which explains the exactness feature toggle tests |
| `test/lit/passes/minimize-rec-groups.wast` | Main positive/bailout surface for independent types, acyclic chains, true cycles, permutation wins, automorphism limits, subtype-order limits, and public-group conflicts |
| `test/lit/passes/minimize-rec-groups-brands.wast` | Large stress test proving brand generation remains deterministic and keeps advancing through compact shapes when there are very many duplicate SCCs |
| `test/lit/passes/minimize-rec-groups-desc.wast` | Descriptor/described contract surface proving same-SCC retention, ordering constraints, descriptor-chain permutation limits, and brand fallback when descriptor constraints leave no distinct order |
| `test/lit/passes/minimize-rec-groups-exact.wast` | Tiny regression proving public exact and inexact type shapes are treated as distinct when the written feature set still distinguishes them |
| `test/lit/passes/minimize-rec-groups-ignore-exact.wast` | Feature-toggle regression proving exactness stops differentiating shapes when custom descriptors are disabled, which can force a brand |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `MinimizeRecGroups::run(Module* module)`

This pass method does six big things:

1. enforce the GC gate
2. collect all heap types with private/public visibility info
3. record public rec-group shapes as immutable collisions and private types as rewrite candidates
4. compute private-type SCCs and put each SCC into a valid topological order
5. resolve shape conflicts through lazy equivalence classes, permutations, and brands
6. rebuild the types and rewrite module type uses plus metadata

### 2. `TypeSCCs`

The pass does not use a generic “all heap types” SCC directly.
It defines a thin wrapper that only follows edges to:

- other private types already included in the optimization set

That helper is the whole reason the pass can split private groups even when they still reference public types.

### 3. `createTypeOrderGraph(...)` + `TopologicalOrders`

The pass does not trust SCC iteration order.
It constructs a separate order graph with:

- supertype -> subtype edges
- described type -> descriptor edges

and uses `TopologicalOrders` to get a legal emitted order.

That pair of helpers explains why some visually symmetric SCCs still have only one valid order.

### 4. `RecGroupShape`, `ComparableRecGroupShape`, and `BrandTypeIterator`

This is where most of the pass name becomes misleading.
The real hard questions are:

- when do two newly split groups still have the same shape?
- when do different written features make them collide or not collide?
- when does a permutation help?
- when must we add a brand?

Those answers come from the type-shape helpers, not from the SCC utility.

### 5. `DisjointSets` + `GroupClassInfo`

Once a shape conflict is detected, the pass needs a durable record of:

- which groups are known isomorphic to one another
- which permutations have already been used for that class
- whether a brand has already been inserted

That class-tracking story lives in the pass plus `DisjointSets`.

### 6. `GlobalTypeRewriter` entry points

The pass does not rewrite every expression or metadata table by hand.
It rebuilds the type graph once, maps old types to new types, then hands off the whole-module replacement to:

- `mapTypes(...)`
- `mapTypeNamesAndIndices(...)`

Those calls are why the pass changes more than the raw type section.

## Why `MinimizeRecGroups.cpp` is deceptively tricky

The file is compact relative to the amount of behavior it owns, but it still hides several important truths.

### Hidden truth 1: SCC splitting is only half the job

If you stop reading after `TypeSCCs`, you will accidentally miss the entire nominal-distinctness story.
SCC splitting alone would be wrong whenever two new groups had the same shape.

### Hidden truth 2: the pass is allowed to add types

Many readers assume “minimize” means monotonic shrink.
The brand logic proves the opposite:

- Binaryen will insert a synthetic type when that is the cheapest correct way to keep two old types distinct.

### Hidden truth 3: feature lowering affects shape comparison

The pass does not compare raw IR types.
The `wasm-type-shape.cpp` helper compares types as they would be written under the active feature set.
That is why exactness matters only in some runs.

### Hidden truth 4: public types matter even though they are not rewritten

The pass never mutates public groups, but public-group shapes still participate in the conflict map.
That is why public ABI surfaces remain real optimization barriers here.

## What each official lit file proves

## 1. `minimize-rec-groups.wast`

This is the broadest contract file.
It proves all of these at once:

- a module with no heap types is a no-op
- a singleton heap type is a no-op
- oversized source rec groups with independent members split apart
- acyclic chains split into multiple groups even when the source wrote them in one `(rec ...)`
- true cycles stay grouped
- same-shape singleton groups need brands when no useful permutations exist
- some multi-type same-shape SCCs can be separated by different valid orders instead of a brand
- other SCCs run out of permutations and need a brand after all
- automorphism-heavy shapes can force branding even without subtype constraints
- subtype-order constraints can also force branding by leaving only one legal order
- private groups must avoid colliding with public-group shapes

If you only read one test file for this pass, read this one first.

## 2. `minimize-rec-groups-brands.wast`

This file is the stress test for the synthetic-brand half of the algorithm.
It proves that:

- Binaryen keeps advancing to new brands deterministically across many duplicate SCCs
- the chosen sequence prefers compact shapes first
- the algorithm still stays stable even when the module forces a very long brand chain

This file is the best evidence that brands are part of the intended mainline behavior, not an emergency hack.

## 3. `minimize-rec-groups-desc.wast`

This file proves the ordering and grouping rules for described/descriptor families.
It shows that:

- described types and descriptors must remain in the same SCC / rec group
- described types must precede their descriptors in the emitted order
- some descriptor-containing SCCs cannot be separated by permutation and therefore need brands
- adding extra reorderable types can create enough legal-order freedom to avoid a brand in other cases

This is the most important file for understanding why “same SCC shape” is not the whole ordering story.

## 4. `minimize-rec-groups-exact.wast`

This file is tiny but valuable.
It proves a public-shape rule:

- exact and inexact types are treated as distinct public shapes when the active features would still write that exactness out

Without that distinction, the pass would assert while building its public-group shape set.

## 5. `minimize-rec-groups-ignore-exact.wast`

This file proves the complementary feature rule.
It shows that:

- exactness does **not** keep two groups distinct once the active feature set would erase exactness from the written type
- disabling custom descriptors can therefore create a collision that now requires a brand

That makes the feature-sensitive comparison rule concrete instead of theoretical.

## The tests teach four misconceptions to avoid

### Misconception 1: the pass always shrinks type count

It does not.
The main file plus the brands file show multiple cases where Binaryen inserts extra brand types.

### Misconception 2: all isomorphic SCCs can be handled with permutations

They cannot.
Automorphisms, subtype constraints, and descriptor ordering can leave only one distinct legal order.

### Misconception 3: exactness is always part of the shape

It is only part of the shape when the active feature set still writes it.
The ignore-exact file exists specifically to prove that.

### Misconception 4: public types are irrelevant because they are untouched

They are very relevant.
Public groups still block private groups from taking the same shape.

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/MinimizeRecGroups.cpp`
- `src/passes/pass.cpp`
- the dedicated lit roster listed above

Durable result:

- the checked core pass file is identical to `version_129`
- the checked dedicated lit files are unchanged
- the reviewed `pass.cpp` surface still registers `minimize-rec-groups` without adding it to the default optimize presets on the reviewed surface

That is a narrow freshness note, not a proof that every helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module-pass entry point, not a HOT pass
- a GC gate
- whole-module heap-type visibility analysis
- private-only SCC computation with public-group collision tracking
- valid intra-group ordering for subtype and descriptor dependencies
- feature-sensitive rec-group shape comparison
- lazy equivalence-class formation for shape conflicts
- permutation search that respects ordering constraints
- synthetic brands for exhausted or impossible permutation spaces
- final whole-module type rewrite plus metadata repair

Any port that implements only “split rec groups by SCC” without those helper-equivalent responsibilities will not match Binaryen's real behavior.

## Bottom line

For `minimize-rec-groups`, the real implementation structure is:

- **one dense pass file + shared SCC/topological-order/disjoint-set/type-shape helpers + one important type-rewrite tail + a surprisingly rich lit roster**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md)
- [`../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md`](../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- Binaryen `version_129`:
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
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
