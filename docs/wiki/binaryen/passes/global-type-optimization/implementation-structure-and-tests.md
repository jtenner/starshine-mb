---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./wat-shapes.md
---

# `global-type-optimization`: implementation structure and tests

This page exists because `GlobalTypeOptimization.cpp` is not a self-contained algorithm.
If you read only that one file, you will miss where several of the real rules come from.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/GlobalTypeOptimization.cpp` | Core pass logic: gates the pass, scans field traffic, propagates hierarchy facts, decides immutability/removals, rewrites field instructions, and updates private struct types |
| `src/passes/pass.cpp` | Registers the upstream CLI name `gto` and places it in the closed-world GC/type prepass cluster after `global-refining` |
| `src/ir/struct-utils.h` | Supplies `StructScanner` and `TypeHierarchyPropagator`, which define the exact/inexact scan model and most of the hierarchy propagation behavior |
| `src/ir/js-utils.h` | Supplies `hasPossibleJSPrototypeField(...)` and `iterJSInterface(...)`, which explain the JS-descriptor keepalive rules |
| `src/ir/module-utils.h` | Supplies `getPublicHeapTypes(...)`, which defines the public/private boundary the pass refuses to cross |
| `src/ir/type-updating.h` / `src/ir/type-updating.cpp` | Supply `GlobalTypeRewriter`, which performs the real module-wide heap-type remapping after field layout changes |
| `src/wasm-type-ordering.h` | Supplies `HeapTypeOrdering::supertypesFirst(...)`, which explains why parent layout decisions are fixed before child decisions |
| `src/support/permutations.h` | Supplies `makeIdentity(...)`, used when the pass decides whether a computed field permutation is actually interesting |
| `test/lit/passes/gto-removals.wast` | Main positive/bailout field-removal and rewrite-safety surface |
| `test/lit/passes/gto-removals-rmw.wast` | Atomic RMW/cmpxchg keepalive and reindexing surface |
| `test/lit/passes/gto-mutability.wast` | Mutability, tag/local/signature repair, subtype, and public-parent surface |
| `test/lit/passes/gto-desc.wast` | Descriptor-adjacent removals and module-initializer trap-preservation surface |
| `test/lit/passes/gto-jsinterop.wast` | JS prototype exposure surface for exported/imported functions, globals, tables, exactness, and subtype propagation |
| `test/lit/passes/gto-shared-jsinterop.wast` | Shared-extern JS prototype keepalive surface |
| `test/lit/passes/gto-strings-jsinterop.wast` | String prototype-negative surface |
| `test/lit/passes/gto_and_cfp_in_O.wast` | Closed-world `-O` scheduler and later-pass interaction surface |
| `test/lit/passes/signature-refining_gto.wat` | Narrow regression for running `gto` after earlier signature/type tightening |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `GlobalTypeOptimization::run(Module* module)`

This pass method does six big things:

1. enforce GC + closed-world gates
2. scan struct traffic in functions and module code
3. add JS-interface exposure reads
4. compute hierarchy-aware immutability/removal plans
5. rewrite affected field instructions while old types still exist
6. rebuild private struct types and remap remaining type uses

### 2. `StructUtils::StructScanner`

The pass does not implement its own tree walk from scratch.
It reuses the shared struct scanner that already understands:

- exact vs inexact ref traffic
- constructor vs set/get traffic separation
- tee / `br_if` fallthrough values
- direct field-copy shapes

That helper explains why the scan phase is richer than the small `FieldInfoScanner` methods suggest.

### 3. `StructUtils::TypeHierarchyPropagator`

The pass does not hand-roll subtype propagation either.
It uses the shared hierarchy propagator twice to get two distinct answers:

- facts from subs **and** supers
- facts from ourselves and supers only

That split is most of the real removal logic.

### 4. `GlobalTypeRewriter`

The pass does not hand-edit every remaining type use itself.
It delegates the whole-module heap-type remapping to `GlobalTypeRewriter`, which updates:

- code expression types
- locals and function signatures
- tables and element segments
- globals and tags
- type names and preserved indices

### 5. `JSUtils`

The pass does not hardcode export/import scanning itself.
It delegates JS-boundary enumeration to `iterJSInterface(...)` and only adds the pass-specific rule:

- exposed descriptors may need to keep their prototype field alive

## Why `GlobalTypeOptimization.cpp` is deceptively tricky

The file is substantial, but still hides several important truths behind helpers.

### Hidden truth 1: constructor traffic is scanned, but not used the way most people expect

The file allocates both:

- `functionNewInfos`
- `functionSetGetInfos`

but only combines:

- `functionSetGetInfos`

into the real decision map.

So the scan file alone does not tell you the actual optimization condition.
You have to follow the data flow into the later combine step.

### Hidden truth 2: type repair is not local to the pass file

The pass file decides:

- which fields move
- which fields disappear
- which fields become immutable

but the safe remapping of the rest of the module happens in shared type-updating code.

### Hidden truth 3: several “ordinary field liveness” cases are actually JS boundary cases

The JS-descriptor keepalive rules do not come from `GlobalTypeOptimization.cpp` alone.
They depend on `js-utils.h` and the lit files.

## What each official lit file proves

## 1. `gto-removals.wast`

This is the broadest contract file.
It proves all of these at once:

- unread fields can disappear
- write-only fields can disappear too
- constructor traffic alone does not keep a field alive
- read traffic keeps fields alive
- side-effectful removed constructor operands are localized before reordering
- mutable vs immutable globals affect whether localization is necessary
- removed writes still preserve null traps and side-effect order
- subtype reordering is real, not pretty-print noise
- public rec groups and public ancestors block some removals
- removed atomic sets need special handling
- EH `pop` cases require nested-pop repair
- field names must be remapped correctly after reorder/removal

If you only read one test file for this pass, read this one.

## 2. `gto-removals-rmw.wast`

This file proves the atomic field families are part of the real contract.

It shows that:

- atomic RMW counts as both read and write
- atomic cmpxchg counts as both read and write
- a field used by either must stay alive and mutable
- if an earlier sibling field disappears, atomic field indexes must still be remapped correctly

That is one of the easiest places to accidentally under-document the pass if you only read the ordinary removal tests.

## 3. `gto-mutability.wast`

This file is the best proof that `gto` is not just dead-field stripping.

It shows:

- fields with no runtime `struct.set` can become immutable
- constructor writes do not block immutability
- tags, locals, and function signatures mentioning the rewritten struct types must remain valid
- subtype chains matter for inherited-field immutability
- a public parent can block immutability of shared inherited fields
- a child-only field can still optimize even when the public parent is frozen

It is also the clearest test surface for the difference between:

- “the parent has that field too”
- and
- “the child field is child-only and can optimize independently”

## 4. `gto-desc.wast`

This file is where the trap-preservation story becomes most obvious.

It proves that:

- removed constructor operands in module-level globals are not just discarded if they can still trap
- fresh `gto-removed-*` globals preserve instantiation-time traps for those removed operands
- descriptor-adjacent traffic is still rewritten consistently when struct fields disappear
- ordinary descriptor optimization itself is left to `unsubtyping`, not `gto`

That last point is a very useful scope boundary for future docs.

## 5. `gto-jsinterop.wast`

This file is the biggest source-backed correction to the naive “field is dead unless wasm reads it” mental model.

It proves that:

- exported/imported functions can make types flow out to JS
- exported/imported globals can do the same
- imported/exported tables can do the same
- exact versus inexact boundary types matter for subtype exposure
- descriptor prototype fields may need to stay alive purely because JS could observe them
- non-prototype-capable fields like `anyref`, `nullexternref`, and string refs can still disappear

Without this file it would be easy to misdescribe the pass as purely wasm-internal.

## 6. `gto-shared-jsinterop.wast`

This tiny file proves one conservative edge rule:

- shared extern-like descriptor prototype fields are also kept alive

That is easy to miss if you only read the more common non-shared JS interop tests.

## 7. `gto-strings-jsinterop.wast`

This file proves the opposite boundary:

- strings are not treated as prototypes here
- so a descriptor field holding a string can still be removed

That negative family is as important as the positive JS-prototype keepalive rules.

## 8. `gto_and_cfp_in_O.wast`

This file is not about a single isolated rewrite.
It proves scheduler meaning.

The core lesson is:

- closed-world `-O` runs `gto`
- open-world `-O` does not
- later global cleanup and constant-field propagation can become stronger because `gto` removed a dead `funcref` field first

That is why the pass placement after `global-refining` and before later global cleanup is part of the real contract.

## 9. `signature-refining_gto.wat`

This file is easy to overlook, but it proves an important robustness boundary.

After earlier signature tightening can turn a parameter into a bottom-like type family, `gto` still needs to:

- scan safely
- avoid crashing while updating types
- coexist with later `remove-unused-types` and roundtrip work

So even though this is not the main `gto` surface, it is still a real adjacent regression for the closed-world cluster.

## The tests teach four misconceptions to avoid

### Misconception 1: `struct.new` proves the field is live

It does not.
The tests explicitly show fields disappearing even when constructors still mention them.

### Misconception 2: unread-field removal is just a local rewrite

It is not.
The parent/child reordering lit families prove the pass is really a subtype-layout rewrite.

### Misconception 3: JS interop is out of scope here

It is not.
Descriptor prototype exposure is part of the pass contract.

### Misconception 4: once a field is removed, removed writes can vanish completely

They cannot.
The tests prove the pass must still preserve:

- side effects
- null-trap timing
- instantiation-time traps in module-level code

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/GlobalTypeOptimization.cpp`
- `src/passes/pass.cpp`
- the dedicated lit roster listed above

Durable result:

- the checked core pass logic and dedicated test surface still match `version_129` on the important reviewed surfaces
- the only reviewed pass-file diff was a comment typo fix
- the reviewed lit files were unchanged

That is a narrow freshness note, not a proof that every helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module pass entry point, not a HOT pass
- the upstream/local naming split (`gto` vs `global-type-optimization`)
- shared-scanner-equivalent exact/inexact field tracking
- hierarchy propagation for both “reads anywhere” and “only strict subtypes care” queries
- public-type boundary handling
- JS descriptor prototype keepalive handling
- instruction-before-type rewrite ordering
- side-effect and trap preservation during removed-field rewrites
- whole-module heap-type remapping and field-name repair

Any port that implements only “remove unread struct fields” without those helper-equivalent responsibilities will not match Binaryen's real behavior.

## Bottom line

For `global-type-optimization`, the real implementation structure is:

- **one closed-world module pass + shared struct scanner + shared hierarchy propagation + shared type rewriter + a large lit roster that carries much of the teaching burden**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`](../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/permutations.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining_gto.wat>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining_gto.wat>
