---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./traps-never-happen-exact-casts-and-descriptors.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `abstract-type-refining`: implementation structure and tests

This page exists because `AbstractTypeRefining.cpp` is not a self-contained algorithm.
If you read only that one file, you will miss where several of the real rules come from.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/AbstractTypeRefining.cpp` | Core pass logic: gates the pass, scans created struct types, computes `createdTypesOrSubTypes`, optionally computes TNH-only abstract-parent refinements, preoptimizes exact/descriptor shapes, rewrites type uses, and refinalizes |
| `src/passes/pass.cpp` | Registers `abstract-type-refining` and places it in the closed-world GC/type prepass cluster after `gsi` and before `unsubtyping` |
| `src/ir/subtypes.h` | Supplies `SubTypes`, which defines immediate-child queries and the subtype-first iteration order used for both created-subtype propagation and chained TNH refinement |
| `src/ir/module-utils.h` | Supplies `ParallelFunctionAnalysis` and `getPublicHeapTypes(...)`, which define the parallel created-type scan shape and the public-type boundary |
| `src/ir/type-updating.h` / `src/ir/type-updating.cpp` | Supply `TypeMapper`, which performs the real module-wide type-use rewrite after the pass decides the mapping |
| `src/ir/localize.h` | Supplies `ChildLocalizer`, which explains the exact temp-and-block scaffolding that appears when descriptor operands must be removed without reordering effects |
| `src/ir/drop.h` | Supplies `getDroppedChildrenAndAppend(...)`, which explains why impossible `struct.new_desc` in functions becomes “drop children, then unreachable” |
| `src/wasm-type.h` | Supplies bottom-heap-type concepts such as `none`, which matter when the pass rewrites never-created families to bottom |
| `test/lit/passes/abstract-type-refining.wast` | Main positive/bailout surface for parent-to-child TNH refinement, bottomization, locals, casts, tests, and branching casts |
| `test/lit/passes/abstract-type-refining-desc.wast` | Descriptor-focused contract surface for descriptor casts, `ref.get_desc`, `struct.new_desc`, side-effect localization, and shared descriptor families |
| `test/lit/passes/abstract-type-refining-exact.wast` | Tiny regression proving exact local types bottomize correctly and exactness is dropped safely |
| `test/lit/passes/abstract-type-refining-tnh-exact-casts.wast` | Dedicated TNH exact-cast and exact branch-cast surface, including descriptor-cast exactness and impossible-success preservation |
| `test/lit/passes/abstract-type-refining-cont.wast` | Narrow regression proving type-copying stays coherent when a rewritten rec group also contains a continuation type pointing at a function type |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `AbstractTypeRefining::run(Module* module)`

This pass method does six big things:

1. enforce GC + closed-world gates
2. collect directly created struct types from module code and function bodies
3. conservatively mark public types as created too
4. propagate created-subtype relevance upward
5. optionally compute TNH-only abstract-parent refinements
6. build a type mapping, preoptimize exact/descriptor shapes, rewrite type uses, and refinalize

### 2. `NewFinder`

The pass does not use a large escape or value-flow analysis to define “created.”
It uses a tiny `visitStructNew(...)` walker.

That helper is the whole reason the pass is so conservative about:

- arrays
- functions
- generic mentions
- plain casts or refs

### 3. `SubTypes`

The pass does not hand-roll subtype traversal either.
It relies on `SubTypes` for:

- immediate child lookup
- subtype-first topological order
- chain propagation order for TNH refinements

### 4. `TypeMapper`

The pass does not hand-edit every remaining type use itself.
It delegates the actual module-wide rewrite to shared type-updating machinery.
That is why the pass can update:

- locals
- signatures
- globals
- rec-group-contained references
- continuation-adjacent type references

without hand-coding every one of those surfaces.

### 5. `ChildLocalizer` and `getDroppedChildrenAndAppend(...)`

The preoptimization phase is not local AST surgery from scratch.
It reuses:

- `ChildLocalizer` when descriptor operands must be detached but their evaluation order and side effects must remain
- `getDroppedChildrenAndAppend(...)` when impossible `struct.new_desc` must become “preserve effects, then unreachable”

Those helpers explain most of the temporary locals and block wrappers visible in the descriptor lit file.

## Why `AbstractTypeRefining.cpp` is deceptively tricky

The file is much smaller than many other late GC/type passes, but it still hides several important truths.

### Hidden truth 1: “created” means exactly `struct.new*`

If you skim the file name and pass summary, it is easy to think the pass infers “instantiability” from broad use patterns.
It does not.
The direct evidence is just:

- `StructNew`

plus the conservative public-type keepalive rule.

### Hidden truth 2: the pass has two different rewrite modes

Many readers collapse the behavior into “refine abstract parent to child.”
That is only half the story.

The always-on part is:

- fully never-created family -> bottom

The TNH-only part is:

- abstract parent -> unique live child

### Hidden truth 3: descriptor repair is part of the real algorithm

The main algorithm looks like a type mapping problem, but the descriptor file proves the pass must also own:

- exact descriptor-cast rewrite safety
- nullable-descriptor trap preservation
- `ref.get_desc` legality repair
- impossible `struct.new_desc` cleanup

### Hidden truth 4: subtype cleanup is intentionally not here

The pass rewrites type uses everywhere, but deliberately preserves declared supertypes.
That is a design boundary, not a missing feature in this one run.

## What each official lit file proves

## 1. `abstract-type-refining.wast`

This is the broadest contract file.
It proves all of these at once:

- a TNH-only abstract parent can refine to a unique live child
- a branching parent with more than one live child does **not** refine
- a branching parent with only one still-relevant child **does** refine in TNH
- a multi-step chain can refine all the way to the deepest live child in TNH
- fully never-created families map to bottom even without TNH
- nullable casts become null checks instead of unreachable
- `ref.cast`, `ref.test`, `br_on_cast`, and local declarations all participate
- casts to basic types like `struct` stay unchanged

If you only read one test file for this pass, read this one first.

## 2. `abstract-type-refining-desc.wast`

This file is where the hard behavior lives.
It proves that:

- descriptor-bearing casts need preoptimization before type rewriting
- nullable descriptor operands may need `ref.as_non_null` outside TNH
- side-effectful ref and descriptor operands are localized in order
- `br_on_cast_desc_eq` and `br_on_cast_desc_eq_fail` become ordinary branch-cast forms when the descriptor child disappears
- impossible `struct.new_desc` in functions becomes preserved-side-effects-plus-`unreachable`
- impossible `struct.new_desc` in globals becomes a null descriptor
- `ref.get_desc` can become either trap-only or refined-cast-assisted, depending on exactness and subtype possibility
- shared descriptor-described families obey the same broad rules

This is the most important file for understanding why the pass is more than a type mapper.

## 3. `abstract-type-refining-exact.wast`

This file is tiny but very valuable.
It proves a narrow exactness rule:

- if a local type like `(ref (exact $foo))` bottomizes, the result must be a valid non-exact bottom reference type such as `(ref none)`

That is easy to miss if you only look at cast tests.

## 4. `abstract-type-refining-tnh-exact-casts.wast`

This file carries the most subtle semantic warning in the whole dossier.
It proves that in TNH mode:

- exact impossible `ref.cast` does **not** refine to a live child and start succeeding
- instead it becomes a bottom or null-only cast
- the same rule holds for exact descriptor casts
- the same rule extends to `br_on_cast` and `br_on_cast_fail`
- side-effectful children still survive through localization

So the pass is not merely “more aggressive under TNH.”
It is also carefully **less naive** under TNH than a simple “pick the only live child” story would imply.

## 5. `abstract-type-refining-cont.wast`

This file is a narrow robustness regression.
It proves that after rewriting away an unused abstract struct type, the shared type-copying machinery still keeps:

- continuation type -> function type

references coherent in the rebuilt rec group.

That is not the main optimization surface, but it is real contract surface for any port using a shared type rewriter.

## The tests teach four misconceptions to avoid

### Misconception 1: the pass only changes casts

It does not.
The base file shows locals, globals, signatures, and rec-group-contained type uses all changing.

### Misconception 2: TNH just means “more aggressive child refinement”

Not safely.
The exact-cast lit file proves TNH must still preserve impossible-success semantics by bottomizing many exact casts instead of refining them to live children.

### Misconception 3: descriptor cases are just minor edge tests

They are not.
The descriptor file is a huge share of the real algorithmic burden.

### Misconception 4: if a type disappears in test output, this pass alone deleted it

Not always.
Several lit RUN lines pair:

- `--abstract-type-refining --remove-unused-types`

So visible type-section shrinkage can be a combined effect.

## Freshness note

The 2026-04-24 raw manifest in [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md) records the official release/source/test URLs used for this dossier.

I did a narrow current-`main` check on:

- `src/passes/AbstractTypeRefining.cpp`
- `src/passes/pass.cpp`
- the dedicated lit roster listed above

Durable result:

- the checked core pass logic still matches `version_129` on the important reviewed surfaces
- the dedicated lit files still match exactly on the reviewed surfaces
- the reviewed `pass.cpp` surface did not change the registration or scheduler slot for `abstract-type-refining`
- the local Starshine follow-up still found no pass owner file; the exact current local status lives in [`./starshine-strategy.md`](./starshine-strategy.md)

That is a narrow freshness note, not a proof that every neighboring helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module-pass entry point, not a HOT pass
- GC and hard closed-world gates
- a concrete `struct.new*` creation scan, not a generic mention scan
- public-type keepalive treatment
- upward created-subtype propagation
- TNH-only unique-child refinement
- always-on bottomization of fully never-created struct families
- descriptor and exact-cast preoptimization before shared type rewriting
- side-effect and null-trap preservation during descriptor cleanup
- type rewriting that intentionally preserves declared supertypes here
- final refinalization

Any port that implements only “replace abstract parents with live children” without those helper-equivalent responsibilities will not match Binaryen's real behavior.

## Bottom line

For `abstract-type-refining`, the real implementation structure is:

- **one small pass file + shared subtype analysis + shared type rewriter + shared child-localization/drop helpers + a surprisingly important lit roster**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md)
- [`../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-cont.wast>
