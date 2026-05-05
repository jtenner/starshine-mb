---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `unsubtyping`: implementation structure and tests

This page exists because `Unsubtyping.cpp` is not a self-contained algorithm.
If you read only that one file, you will miss where several of the real rules come from.
The reviewed primary-source manifest for this file map is [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md); the exact current Starshine status lives in [`./starshine-strategy.md`](./starshine-strategy.md).
The 2026-05-05 current-main recheck reviewed the same owner and lit surfaces and found no teaching-relevant drift, so the file map below remains the source-correct reading.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/Unsubtyping.cpp` | Core pass logic: seeds required subtype/descriptor edges, runs the fixed point, fixes descriptor-bearing allocations, rewrites private type declarations, and refinalizes afterward |
| `src/passes/pass.cpp` | Registers `unsubtyping` and places it after `gsi` and optional `abstract-type-refining` in the closed-world GC/type cluster |
| `src/ir/subtype-exprs.h` | Supplies `SubtypingDiscoverer`, which defines most of the initial IR validation constraints the pass reasons about |
| `src/ir/js-utils.h` | Supplies `iterJSInterface(...)` and `hasPossibleJSPrototypeField(...)`, which explain the JS-boundary keepalive rules |
| `src/ir/module-utils.h` | Supplies `getPublicHeapTypes(...)` and `ParallelFunctionAnalysis`, which define the public/private split and the parallel scan shape |
| `src/ir/type-updating.h` / `src/ir/type-updating.cpp` | Supply `GlobalTypeRewriter`, which performs the real private-type rebuild and whole-module type-use update |
| `src/ir/localize.h` | Supplies `ChildLocalizer`, which explains the function-local descriptor-allocation fixups |
| `src/ir/effects.h` | Supplies `EffectAnalyzer`, which explains when removed module-level descriptor initializers still need synthetic globals to preserve traps |
| `src/wasm-type.h` | Supplies descriptor and subtype queries like `getDescriptorType()`, `getDescribedType()`, and `isSubType(...)` |
| `test/lit/passes/unsubtyping.wast` | Main baseline validation-surface file: public freeze, core validation constraints, structural transitivity, and broad expression coverage |
| `test/lit/passes/unsubtyping-casts.wast` | Ordinary-vs-exact cast, guaranteed-success, guaranteed-fail, fixed-point chain, and `ref.eq` non-flow coverage |
| `test/lit/passes/unsubtyping-cmpxchg.wast` | Shared/unshared ref-field cmpxchg expected-value typing surface |
| `test/lit/passes/unsubtyping-desc.wast` | Descriptor-square, `ref.get_desc`, descriptor-cast, and trap-preserving `struct.new_desc` coverage |
| `test/lit/passes/unsubtyping-desc-tnh.wast` | `trapsNeverHappen` descriptor-fixup differences |
| `test/lit/passes/unsubtyping-jsinterop.wast` | JS-boundary flow, `any`-boundary cast, JS prototype keepalive, and `extern.convert_any` coverage |
| `test/lit/passes/unsubtyping-stack-switching.wast` | Continuation, `cont.bind`, `suspend`, and `resume` coverage |

## Important test-harness warning

Most of the main official lit files do **not** run `unsubtyping` in isolation.
They run:

- `--unsubtyping --remove-unused-types`
- often with `--preserve-type-order`

That means many visible type-section shrink results in the checked output are a **combined** effect of:

1. `unsubtyping` removing subtype or descriptor relations, and then
2. `remove-unused-types` deleting the now-unreferenced heap types

A beginner can easily misread those outputs as if `unsubtyping` alone explicitly deletes every vanished type.
The implementation file does not do that directly.
The test harness is intentionally showing the very common next-pass cleanup combo.

The one small exception in this reviewed roster is:

- `unsubtyping-cmpxchg.wast`

which runs just `--unsubtyping` and focuses on typing rather than section shrink.

## The real call graph

The core flow in `version_129` is compact but layered.

### 1. `Unsubtyping::run(Module* wasm)`

This pass method does six big things:

1. enforce GC + closed-world gates
2. seed required subtype/descriptor edges from public types, JS boundaries, and the IR
3. iterate to a fixed point over those requirements in `TypeTree`
4. fix descriptor-bearing allocations before type rewrite
5. rewrite private declared supertype/descriptor edges through `GlobalTypeRewriter`
6. run `ReFinalize()`

### 2. `SubtypingDiscoverer`

The pass does not implement most IR validation scanning from scratch.
It reuses the shared subtype-expression walker, which already knows how to derive constraints from:

- structured control flow
- calls and returns
- locals/globals/tables
- struct and array operations
- exceptions
- continuations and stack-switching ops

That helper explains why the initial validation surface is much broader than the small pass file suggests.

### 3. `TypeTree`

The pass does not keep a flat set of edges.
It keeps a mutable forest with:

- parent pointers
- child lists
- descriptor/described links
- JS-exposure marks

That helper structure explains the reparenting logic and the minimal-forest story.

### 4. `GlobalTypeRewriter`

The pass does not hand-edit every remaining type use itself.
It delegates the private-type rebuild and module-wide use updates to shared type-updating machinery.

### 5. `ChildLocalizer` and `EffectAnalyzer`

The pass does not inline its descriptor-allocation repair logic either.
It relies on:

- `ChildLocalizer` for function-local operand-preserving rewrites
- `EffectAnalyzer` for module-level trap-preservation decisions

That is why the allocation-fixup half of the pass is easy to underestimate if you only skim the central worklist algorithm.

## Why `Unsubtyping.cpp` is deceptively tricky

The file is substantial, but still hides several important truths behind helpers and test setup.

### Hidden truth 1: the pass is about descriptors too

The name suggests only declared supertypes.
But the file spends real algorithmic effort on:

- `Kind::Descriptor`
- `noteDescriptor(...)`
- `completeDescriptorSquare(...)`
- `fixupAllocations(...)`

and the dedicated descriptor lit files prove that this is not incidental.

### Hidden truth 2: casts are not handled in one step

The file does **not** simply see a cast and keep the obvious declaration edge.
Ordinary casts are stored and only later converted into subtype requirements after the pass discovers which concrete types can still flow into the cast source under the minimized graph.

### Hidden truth 3: many visible type deletions belong to the harness combo

If you look only at test output and not the RUN lines, it is easy to over-attribute visible type disappearance to `unsubtyping` itself.
The official lit setup intentionally composes it with `remove-unused-types` for most section-shrink checks.

## What each official lit file proves

## 1. `unsubtyping.wast`

This is the broadest contract file.
It proves all of these at once:

- trivial declaration-only subtype chains can collapse when nothing needs the parent
- public types stay unchanged
- function bodies, global initializers, tables, and active element segments can directly require subtype edges
- kept declaration edges imply more edges through struct fields, arrays, and function types
- block, `if`, loop, `br`, `br_if`, `br_table`, call, indirect call, local/global/table set, `select`, try/catch, tag payload, and multivalue return shapes all matter
- continuation-like `call_ref` and unreachable cases must remain valid after the shared repair passes

If you only read one test file for the pass, read this one first.

## 2. `unsubtyping-casts.wast`

This file proves the ordinary-vs-exact cast story.

It shows that:

- an isolated downcast can become cheaper if no concrete flowing subtype makes success observable
- once a concrete subtype is shown to flow into the cast source, the cast can keep intermediate subtype edges alive
- `ref.test`, `br_on_cast`, and `br_on_cast_fail` use the same cast-preservation logic
- exact casts keep a smaller relation surface than ordinary casts
- guaranteed-success upcasts keep the direct subtype relation they depend on
- guaranteed-fail casts should not invent new edges
- `ref.eq` non-flow constraints should not block unrelated user-type unsubtyping
- some examples need multiple worklist rounds before the full chain of required relations is discovered

This is the file that most clearly corrects the naive mental model:

- “seeing a cast means keep the declaration edge”

## 3. `unsubtyping-cmpxchg.wast`

This file is tiny, but important.
It proves that ref cmpxchg expected-value typing must still respect:

- `eqref` for unshared ref fields/elements
- `(ref null (shared eq))` for shared ref fields/elements

So the type-rewrite / refinalize tail of the pass is part of the real contract even for shapes that do not look descriptor-heavy.

## 4. `unsubtyping-desc.wast`

This is the hardest conceptual file.
It proves:

- descriptor relations can be removed independently of ordinary subtype edges
- some relations must stay because `ref.get_desc` or descriptor-aware casts can observe them
- some module-level nullable descriptor allocations must preserve a potential trap and therefore keep or re-express the descriptor edge
- function-local nullable descriptor cases can instead be repaired with `ref.as_non_null` plus localization
- descriptor squares can recursively force both subtype edges and descriptor edges to stay together
- descriptor-supertype edges can sometimes disappear even when described-type subtype edges remain

If you want to understand why descriptors live in this pass at all, read this file.

## 5. `unsubtyping-desc-tnh.wast`

This file proves the `trapsNeverHappen` boundary.

It shows that:

- nullable descriptor traps do not need preservation when traps are assumed not to occur
- function-local `ref.as_non_null` fixups disappear in those cases
- module-level helper globals for removed trapping descriptor initializers are not needed then either

So TNH is not just a generic optimizer footnote here.
It changes a real part of the pass contract.

## 6. `unsubtyping-jsinterop.wast`

This file is the biggest source-backed correction to the naive “only wasm validation matters” mental model.

It proves that:

- JS boundary flow through exports/imports and `@binaryen.js.called` can keep subtype edges alive via `any`
- descriptors are only kept for possible JS-prototype carriers
- descriptors that cannot configure prototypes can still be removed even if the type crosses the JS boundary
- `extern.convert_any` exposes a type to JS directly
- inexact exposure can make subtype-descendant descriptor relations matter too

Without this file it would be easy to misdescribe the pass as purely wasm-internal.

## 7. `unsubtyping-stack-switching.wast`

This file proves that the pass handles the continuation/stack-switching surface too.

It shows that:

- `cont.new` can require function-type subtyping
- `cont.bind` can require operand, parameter, and result subtype compatibility
- `suspend` and `resume` contribute constraints as well
- null or unreachable continuation cases still must not crash after the graph is rewritten

A future port that ignores stack-switching would therefore be incomplete.

## The tests teach four misconceptions to avoid

### Misconception 1: the pass just edits declaration edges

It does not.
The tests cover broad validation surfaces, descriptors, casts, JS interop, and continuation instructions.

### Misconception 2: any cast keeps its whole original relation chain

It does not.
The cast file proves ordinary casts are flow-sensitive in a conservative fixed-point sense, and exact casts are even narrower.

### Misconception 3: descriptor cleanup belongs elsewhere

It does not.
The descriptor files prove descriptor-square completion and descriptor-allocation fixups are central to this pass.

### Misconception 4: visible type deletions in the test output are all this pass

They are not.
Most of the visible shrink is checked under `--unsubtyping --remove-unused-types`.

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/Unsubtyping.cpp`
- `src/passes/pass.cpp`
- the dedicated lit roster listed above

Durable result:

- the checked core pass logic and reviewed lit surface still match `version_129` on the important reviewed surfaces
- the checked pass-file diffs were only tiny non-semantic cleanup (`const Module&` and a typo fix)
- the reviewed lit files were unchanged

That is a narrow freshness note, not a proof that every helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module pass entry point, not a HOT pass
- a hard GC + `--closed-world` gate
- public-type freezing
- broad validation-constraint discovery across the shared subtype-expression surface
- exact-cast versus ordinary-cast distinction
- descriptor-square completion logic
- JS-boundary and JS-prototype keepalive logic
- function-local allocation fixups via localization
- module-level removed-allocation trap preservation
- private-type rewriting through shared type-updating infrastructure
- post-rewrite refinalization

Any port that implements only “drop declaration edges that look unused” without those helper-equivalent responsibilities will not match Binaryen's real behavior.

## Bottom line

For `unsubtyping`, the real implementation structure is:

- **one closed-world module pass + shared validation-constraint walker + shared JS-boundary helpers + shared type rewriter + a lit roster that proves descriptor, cast, and continuation corner cases**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`](../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtype-exprs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-stack-switching.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-stack-switching.wast>
