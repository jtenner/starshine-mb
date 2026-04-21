---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `global-type-optimization` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/GlobalTypeOptimization.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `StructUtils::StructScanner`
- `StructUtils::TypeHierarchyPropagator`
- `JSUtils::hasPossibleJSPrototypeField(...)`
- `JSUtils::iterJSInterface(...)`
- `ModuleUtils::getPublicHeapTypes(...)`
- `GlobalTypeRewriter`
- `HeapTypeOrdering::supertypesFirst(...)`
- `ChildLocalizer`
- `EHUtils::handleBlockNestedPops(...)`
- `makeIdentity(...)`

The shipped lit surface is also part of the contract:

- `test/lit/passes/gto-removals.wast`
- `test/lit/passes/gto-removals-rmw.wast`
- `test/lit/passes/gto-mutability.wast`
- `test/lit/passes/gto-desc.wast`
- `test/lit/passes/gto-jsinterop.wast`
- `test/lit/passes/gto-shared-jsinterop.wast`
- `test/lit/passes/gto-strings-jsinterop.wast`
- `test/lit/passes/gto_and_cfp_in_O.wast`
- `test/lit/passes/signature-refining_gto.wat`

## High-level intent

Binaryen uses `global-type-optimization` to optimize **private struct field layout** at the module level.

But the real contract is narrower than the pass name sounds.

The pass only stays correct because it preserves all of these at once:

1. only GC-enabled modules are eligible
2. only closed-world runs are eligible
3. only private struct types are actually rewritten
4. read/write facts are propagated across supertypes and subtypes before deciding anything
5. JS-visible descriptor prototype fields are treated as reads when they can flow out to JS
6. removed field instructions preserve effects and traps before the type graph changes
7. private type rebuilding updates names and remaining type uses consistently afterward

That is why this is a module pass even though much of the visible rewrite happens in `struct.*` instructions.

## Where the pass runs

In `pass.cpp`, Binaryen registers the pass under the short CLI name:

- `gto`

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, `gto` is **absent**.

The open-world path stays:

- `... -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi -> ...`

That means the repo's main no-DWARF orientation page should continue to omit `global-type-optimization`.

### Closed-world Binaryen path

When Binaryen runs in closed world, the neighborhood grows:

- before `gto`:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
  - `global-refining`
- after `gto`:
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That means `gto` is part of the **early closed-world GC/type cluster**, not a late cleanup pass.

### Important scheduler fact: `-O` closed world versus open world

`gto_and_cfp_in_O.wast` makes the placement concrete.

In closed world `-O`, Binaryen can:

- remove an unread `funcref` field with `gto`
- let later global cleanup delete the now-dead helper function the removed `ref.func` once kept alive
- then let later constant-field propagation fold the surviving field more aggressively

So the pass slot is not decorative.
It is part of a real optimization chain.

## Phase 0: hard GC + closed-world gates

`GlobalTypeOptimization::run(Module* module)` begins by returning immediately when:

- `!module->features.hasGC()`

and then throws a fatal error when:

- `!getPassOptions().closedWorld`

This is one of the most important differences from neighboring passes.
`gto` does not merely *tend* to run in closed world.
The pass body itself insists on it.

## Phase 1: scan field traffic with a shared struct scanner

Binaryen first defines the tiny per-field summary type:

- `FieldInfo { bool hasWrite; bool hasRead; }`

Then it builds:

- `FieldInfoScanner : StructUtils::StructScanner<FieldInfo, FieldInfoScanner>`

### What the scanner records

The derived scanner records:

- `noteExpression(...)` -> write
- `noteDefault(...)` -> write
- `noteCopy(...)` -> write
- `noteRead(...)` -> read
- `noteRMW(...)` -> read and write

It deliberately ignores descriptor pseudo-fields in the ordinary path:

- `if (index == StructUtils::DescriptorIndex) return;`

The comment in the file is explicit:

- unused descriptors are optimized in `Unsubtyping` instead

So `gto` is not generic descriptor-field cleanup.
It only protects certain descriptor fields from removal later.

### Special JS path: `extern.convert_any`

The scanner also overrides `visitRefAs(...)`.

When it sees:

- `ExternConvertAny`

and the input ref type's descriptor might have a possible JS prototype field, it marks:

- descriptor field `0`

as read.

This is one of the key reasons the pass is not just wasm-internal field liveness.
JS boundary semantics matter.

### Important `StructScanner` behavior hidden behind the derived class

The shared scanner infrastructure adds three details that matter a lot:

- `struct.new` traffic is tracked in a separate exact-type map
- `struct.set` / `struct.get` / atomic field ops are tracked under the observed exactness of the reference
- `noteExpressionOrCopy(...)` consults `Properties::getFallthrough(...)`, so tee/`br_if`-style fallthrough values can still count, and direct `struct.get` copies are identified specially

That means the field-traffic analysis is already a little richer than “visit literal children.”

### Big beginner correction: constructor writes do not drive the decision phase

This is one of the easiest things to misread.

The pass allocates both:

- `functionNewInfos`
- `functionSetGetInfos`

but later only combines:

- `functionSetGetInfos`

into the real optimization map.

So the actual mutability/removability decision is driven by:

- `struct.set`
- `struct.get`
- atomic RMW / cmpxchg
- JS-exposed descriptor reads

and **not** by constructor traffic.

That is why the lit tests can honestly say:

- `struct.new` does not keep a field alive
- `struct.new_default` does not keep a field alive
- constructor traffic does not prevent a field from becoming immutable

Constructor operands still matter later during rewriting, but not during the main field-optimization decision.

## Phase 2: scan both functions and module code

The pass instantiates:

- `StructUtils::FunctionStructValuesMap<FieldInfo> functionNewInfos(*module)`
- `StructUtils::FunctionStructValuesMap<FieldInfo> functionSetGetInfos(*module)`
- `FieldInfoScanner scanner(functionNewInfos, functionSetGetInfos)`

and then runs both:

- `scanner.run(getPassRunner(), module)`
- `scanner.runOnModuleCode(getPassRunner(), module)`

That means `gto` explicitly reasons about:

- function bodies
- module-level code such as global initializers

The module-code walk matters later for preserving instantiation-time traps when removed constructor operands came from globals.

## Phase 3: combine runtime field facts and add JS-interface exposure

After scanning, the pass does:

- `functionSetGetInfos.combineInto(combinedSetGetInfos)`

and then:

- `SubTypes subTypes(*module)`
- `analyzeJSInterface(*module, subTypes)`

### What `analyzeJSInterface(...)` protects

This helper only runs when:

- `wasm.features.hasCustomDescriptors()`

Inside it, the pass uses `JSUtils` to conservatively note reads of descriptor field `0` when values may flow **out** to JS.

The logic is:

- only descriptor field `0` is relevant here
- only immutable extern-like fields are treated as possible JS prototype carriers
- values that flow out through exports, imports, JS-called functions, tables, or globals can expose those prototype carriers to JS
- inexact exposure propagates from supertypes to subtypes
- exact exposure does not imply the same subtype propagation

That explains several lit families:

- `externref` and `(ref extern)` prototype fields can stay alive
- `anyref`, `nullexternref`, and `stringref` descriptor fields can still be removed here
- mutable descriptor fields do not get the same JS-prototype protection
- a public or imported supertype flowing out can keep a subtype descriptor field alive too

## Phase 4: propagate usage through the type hierarchy

The pass then builds two different propagated maps using:

- `StructUtils::TypeHierarchyPropagator<FieldInfo> propagator(subTypes)`

### Map A: information from subs and supers

Starting from `combinedSetGetInfos`, Binaryen runs:

- `propagator.propagateToSuperAndSubTypes(dataFromSubsAndSupersMap)`

This answers:

- was the field read or written anywhere in the compatible super/subtype family?

That is the conservative map used for unread-field and immutability checks.

### Map B: information from ourselves and supers

Starting from the original runtime set/get info, Binaryen runs:

- `propagator.propagateToSubTypes(dataFromSupersMap)`

This answers:

- was the field used in ourselves or any supertype above us?

That is the more precise map used for the “only strict subtypes need this field” removal case.

### Why the pass needs both maps

This split is core to the algorithm.

Without it, Binaryen could not distinguish:

- “the field is dead everywhere”
- from
- “the field is live only in strict subtypes, so the parent can drop it if layout is repaired correctly”

That distinction is exactly what makes the parent/child reorder examples in the lit tests possible.

## Phase 5: freeze public types entirely

Before optimizing anything, the pass collects:

- `ModuleUtils::getPublicHeapTypes(*module)`

and puts the result in a set.

Then, in the main processing loop, it skips any type that is:

- not a struct
- or public

So `gto` rewrites only **private struct types**.

The public/private boundary is a hard semantic rule, not a heuristic.
That is why:

- public rec groups stay untouched
- a public parent can block inherited-field optimizations in children
- but a child-only field can still optimize if the public parent does not contain it at all

## Phase 6: visit private structs in supertypes-first order

The main loop iterates:

- `HeapTypeOrdering::supertypesFirst(propagator.subTypes.types)`

That order matters.
Binaryen wants parent layout decisions fixed before children decide what they can keep or append.

For each private struct, it looks up the **exact** entry:

- `(type, Exact)`

because the exact/inexact propagation asymmetry matters for the finer removal checks.

## Phase 7: decide which fields can become immutable

For each field:

- if already immutable -> skip
- if any write exists anywhere in the relevant family -> skip
- if a parent has that same field index, the parent must also be able to become immutable there -> otherwise skip
- else mark the field in `canBecomeImmutable`

That parent check is essential.
Binaryen cannot have:

- mutable field in the parent
- immutable field at the same inherited slot in the child

and still claim subtype compatibility.

This is why the lit files show both:

- positive “no set exists, so immutable is possible” cases
- negative “the parent is public/frozen, so the shared inherited field must stay mutable” cases

## Phase 8: decide which fields can be removed

For each field, Binaryen computes:

- `hasNoReadsAnywhere`
- `hasNoReadsOrWritesInSupers`

and removes the field if either is true.

### Removal case A: unread everywhere

If the field is never read in the whole compatible family, Binaryen can remove it even if writes exist.

That is the source-backed reason write-only fields disappear.

### Removal case B: used only in strict subtypes

If there are no reads or writes in ourselves or our supertypes, then only strict subtypes need the field.

In that case the parent may drop it, and the subtype will later append the field after the parent's kept prefix.

That is the key layout-aware optimization that makes `gto` more than a trivial dead-field sweep.

## Phase 9: compute a subtype-safe field permutation/removal map

If there are removable fields, or the parent already reordered/removed fields, Binaryen computes:

- `indexesAfterRemoval`

with the special sentinel:

- `RemovedField = Index(-1)`

The algorithm preserves four rules at once:

1. if the parent kept a field, the child must keep it at the same new index
2. if the parent removed a field but the child still needs it, the child appends it later
3. child-only fields may be removed or appended after the inherited prefix
4. removable middle fields in the parent may require reordering so the final parent shape still forms a valid subtype prefix for the child

That is why the pass comments walk through the classic example where a parent field is used only in the child:

- first reorder the parent so the now-dead parent-only field falls at the end
- then remove it from the parent
- then let the child append its still-needed version after the parent's surviving prefix

A future port must preserve this “reorder before drop” reasoning.

## Phase 10: rewrite instructions before rewriting types

If any fields are removed, the pass does:

- `updateInstructions(*module)`

before:

- `updateTypes(*module)`

The source comment explains why:

- while rewriting instructions, Binaryen still needs the old heap types to identify the original field layout

If only immutability changed, the instruction rewrite may be skipped.
If either removals or immutability changes happened, the type rewrite runs.

That order is not optional.

## Phase 11: instruction rewrites preserve side effects and traps

`updateInstructions(...)` defines a nested function-parallel `FieldRemover`.
It also runs the same walker on module code.

### `visitStructNew(...)`

If the constructor type has a removal/reorder map:

- inside functions:
  - `ChildLocalizer` is used first so side-effectful children can be reordered or dropped safely
  - localization can insert blocks, which later require EH nested-pop fixups
- outside functions:
  - locals cannot be used
  - removed operands that may trap are saved for later synthetic globals so instantiation-time traps still happen
- then operands are removed/reordered according to `indexesAfterRemoval`

That is why the lit file shows subtle cases such as:

- removed side-effectful constructor operands becoming localized temps
- immutable `global.get` sometimes avoiding localization
- mutable `global.get` needing localization because later calls could in theory change it
- unreachable constructor operands being preserved through a replacement block instead of simply vanishing

### `visitStructSet(...)`

If the field survives:

- update the field index

If the field was removed:

- emit a `drop` of the value
- still null-check the reference with `ref.as_non_null`
- preserve the order so the value's side effects happen before the null trap on the reference
- if the set was atomic, emit no fence because a removed field has no remaining reads to synchronize with

That is one of the most important non-obvious correctness rules in the whole pass.

### `visitStructGet(...)`, `visitStructRMW(...)`, `visitStructCmpxchg(...)`

These rewrites are intentionally simple:

- surviving fields are reindexed
- removed fields are asserted impossible

That is the direct source proof that read traffic, atomic RMW, and cmpxchg keep fields alive.

### EH fixups

If localization inserted blocks in a function, the pass later calls:

- `EHUtils::handleBlockNestedPops(...)`

on that function.

The lit cases involving `pop` in a constructor confirm this is part of the pass contract.

### Synthetic globals for removed trapping initializers

After the walk, the pass inserts fresh immutable globals named like:

- `gto-removed-0`
- `gto-removed-1`

for removed module-initializer operands that may still trap.

This is how Binaryen preserves instantiation-time traps even after an unread field disappears from a global initializer.

## Phase 12: rewrite private struct types and repair field names

If anything changed, `updateTypes(...)` builds a local `TypeRewriter : GlobalTypeRewriter`.

Its `modifyStruct(...)` hook:

1. sets fields immutable according to `canBecomeImmutable`
2. reorders/removes fields according to `indexesAfterRemovals`

Then it does one extra thing manually:

- remap `wasm.typeNames[oldStructType].fieldNames`

The source comment is explicit that `GlobalTypeRewriter` cannot do that by itself because it does not know the old-field -> new-field permutation.

The partial-name lit cases exercise this directly.

## Phase 13: `GlobalTypeRewriter` is the real whole-module remapping engine

`TypeRewriter(...).update()` delegates the broader heap-type remapping to shared code in `type-updating.*`.

The helper's visible responsibilities include:

- rebuilding only private types
- preserving predecessor/topological constraints
- updating expression types in code and module code
- updating function locals and signatures that mention the changed struct types
- updating tables, element segments, globals, and tags
- updating type names and preserved indices

That is why gto-mutability can safely test things like:

- tag parameter types
- locals of ref-to-struct type
- function signatures mentioning the struct type
- `call_indirect` signatures that mention the struct type

without needing a separate pass-specific repair mechanism for each.

## What the pass does **not** do

Binaryen `gto` in `version_129` does **not** do any of these:

- it does not run in open world
- it does not optimize public types
- it does not refine field value types
- it does not optimize arrays or function signatures
- it does not optimize descriptors generally; ordinary descriptor cleanup is deferred to `unsubtyping`
- it does not use CFG or liveness reasoning beyond the shared structural field-traffic propagation described above

Those boundaries are just as important as the positive rewrites.

## What the pass sounds like versus what it actually is

What it sounds like:

- a broad GC type optimizer

What it actually is in `version_129`:

- a closed-world private-struct mutability/removal pass with hierarchy propagation, JS-boundary keepalive rules, instruction-before-type rewriting, and explicit trap-preservation logic.

That is the behavior a future Starshine port would need to preserve.

## Bottom line

Binaryen `gto` is really:

- **private struct field immutability + unread-field removal + subtype-layout repair + JS-prototype keepalive + trap-preserving rewrite order**

The public one-line summary in `pass.cpp` hides that entire story.

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
