# 0153 - Binaryen `global-type-optimization` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `signature-refining` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes plus the new closed-world cluster dossiers, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `global-type-optimization`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/global-type-optimization/`
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
- the prompt still excluded the recently refreshed parity dossiers and the newly added `remove-unused-types`, `type-refining`, `signature-pruning`, and `signature-refining` upstream-only dossiers
- the tracker's clearest still-`none` upstream-only candidates were `global-type-optimization`, `abstract-type-refining`, `unsubtyping`, `minimize-rec-groups`, and `reorder-types`
- `agent-todo.md` still had **no dedicated `global-type-optimization` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `global-type-optimization` for seven source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- It sits immediately after `global-refining` and immediately before `remove-unused-module-elements`, optional `remove-unused-types`, optional `cfp` / `cfp-reftest`, and `gsi` in Binaryen's closed-world GC/type prepass cluster, so documenting it now fills the biggest remaining hole in that neighbor chain.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official implementation is more specific than the name suggests: it is not generic global type cleanup, but a private-struct-field mutability/removal pass with subtype-layout repair, JS-descriptor prototype exposure handling, and explicit trap-preservation rewrites.
- The implementation hides multiple beginner traps that are worth documenting explicitly:
  - upstream `pass.cpp` registers the short public CLI name `gto`, while the local Starshine registry and tracker use the full descriptive name `global-type-optimization`
  - the pass body itself requires `--closed-world` and throws a fatal error if you invoke it without that option, unlike some neighboring passes whose closed-world restriction is scheduler-only
  - it does **not** refine field value types at all; it only changes field mutability and field presence/order
  - `struct.new` traffic does **not** keep a field alive or mutable in the actual decision phase
  - unread-field removal is hierarchy-aware and may require reordering parent fields so removed fields fall off the end while subtypes still append compatible layouts
  - JS-visible descriptor prototype fields can keep otherwise-unused descriptor field `0` alive even when no wasm code reads it
  - removed field writes and removed module-initializer operands must preserve side-effect order and trapping behavior carefully
- The official lit surface is large and teachable, with focused files for removals, mutability, atomic RMW/cmpxchg, descriptors, JS interop, shared JS interop, string JS interop, and closed-world `-O` interaction with later passes.

So this thread is not reopening an old parity item.
It is the first explicit living dossier for the closed-world-cluster `global-type-optimization` pass that bridges the repo's existing `global-refining`, `remove-unused-types`, and `global-struct-inference` docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/permutations.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining_gto.wat>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit files checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining_gto.wat>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `GlobalTypeOptimization.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed algorithmic surfaces that matter most here:
  - same GC gate
  - same hard `--closed-world` fatal
  - same `FieldInfoScanner` structure
  - same JS-interface exposure logic
  - same supertypes-first immutability/removal computation
  - same instruction-before-type rewrite order
  - same `ChildLocalizer` / EH-fixup / removed-init-trap-global contract
- the only reviewed `GlobalTypeOptimization.cpp` diff was a comment typo fix:
  - `propate` -> `propagate`
- the checked `pass.cpp` diff on the reviewed `gto` surfaces did not change the `gto` registration or scheduler slot; the only observed diff hunks were unrelated spelling fixes elsewhere in the registry
- the checked dedicated lit files above were byte-identical on the reviewed surfaces

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable rule for the living wiki should be:

- use `version_129` as the normative algorithm oracle
- record later upstream drift explicitly if it matters
- do not invent a semantic drift story when the checked current surfaces still match the reviewed tag behavior

## Repo-local sources used for context

Starshine-side files that mattered while choosing and framing this dossier:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `global-type-optimization`
- the local registry tracks the pass only as the full boundary-only name `global-type-optimization`, not as the upstream shorthand `gto`
- the current living `global-refining`, `remove-unused-types`, and `global-struct-inference` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `global-type-optimization` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `global-type-optimization` is not generic “optimize GC types globally.”

The real `version_129` contract is narrower and more concrete:

1. require GC features and reject non-closed-world invocation
2. scan struct field reads and writes across the module's code using the shared `StructScanner` machinery
3. treat ordinary `struct.set`, `struct.get`, `struct.atomic.rmw.*`, and `struct.atomic.rmw.cmpxchg` traffic as the main optimization evidence
4. separately protect descriptor prototype fields that may become visible to JS
5. propagate read/write facts across supertypes and subtypes so layout and mutability decisions stay subtype-safe
6. skip all public heap types entirely
7. mark mutable fields immutable when there are no writes anywhere in the relevant hierarchy and the parent-compatible layout also allows it
8. mark fields removable when they are unread everywhere or only needed in strict subtypes
9. compute a field-permutation/removal map that keeps subtype layout valid, often by moving removable parent fields to the end first
10. rewrite affected `struct.new` / `struct.set` / `struct.get` / atomic field instructions before changing the type graph
11. preserve side-effect and trap order when removed fields delete writes or constructor operands
12. rebuild private struct types with the new mutability and field order, then remap all type uses and field names consistently

A better short summary is:

- **Binaryen `gto` is a closed-world GC module pass that makes private struct fields immutable when no runtime write reaches them and removes unread fields when subtype layout and JS-boundary rules still allow it.**

The three biggest beginner corrections are:

- the pass does **not** narrow field value types; that belongs to neighbors like `type-refining`, `cfp`, `abstract-type-refining`, and `unsubtyping`
- `struct.new` constructor operands do **not** keep fields alive or mutable in the actual decision phase
- “remove an unread field” does **not** mean “delete that index in place”; subtype layout compatibility may require reordering fields first and appending preserved child-only fields later

## Upstream naming and scheduler surface

`pass.cpp` registers the pass with the short name:

- `gto`

and the summary:

- `globally optimize GC types`

That summary is accurate, but too small.
It hides several central details:

- the pass only optimizes **struct** types today
- it changes **mutability** and **field presence/order**, not field value types
- it is a **module pass**, not a local peephole
- it is **closed-world-only** at the pass-body level, not just by scheduler convention
- it has explicit JS-prototype, atomic-RMW, trap-preservation, and subtype-layout rules

### Local naming mismatch that future docs must keep explicit

The local Starshine registry and tracker use the fuller descriptive name:

- `global-type-optimization`

while upstream `pass.cpp` uses the CLI shorthand:

- `gto`

That mismatch is small but important.
The new living folder should keep both names visible instead of pretending only one is canonical across both codebases.

### Relation to nearby passes

The most useful mental model is:

- `global-refining` tightens **global declaration types** from initializer-plus-write LUBs
- `gto` tightens **private struct field mutability/layout**
- `remove-unused-module-elements` can then remove code and references that those field removals made dead
- `remove-unused-types` can then drop now-dead heap types
- `cfp` / `cfp-reftest` can exploit the simplified post-`gto` field graph
- `gsi` can then reason over a smaller, cleaner global-struct world
- `abstract-type-refining` and `unsubtyping` continue the later closed-world GC/type cleanup chain

The dedicated lit file `gto_and_cfp_in_O.wast` is especially valuable here.
It shows a concrete closed-world `-O` story where:

- `gto` removes an unread `funcref` field
- that removal eliminates a previously live `ref.func` edge
- `remove-unused-module-elements` can then drop the now-dead helper function
- and later constant field propagation can infer the remaining i32 field as a constant

So scheduler placement is not just trivia.
It is part of the optimization payoff story.

### Scheduler placement

`gto` is not part of the repo's main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default global-prepass cluster is:

- if `wasm->features.hasGC()` and `options.optimizeLevel >= 2`
- and if `options.closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- then continue with:
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That teaches four durable things:

- `gto` is a **closed-world post-`global-refining`** GC/type-layout step
- it belongs to the early global GC/type cluster, not the later function-pass cluster
- the default-pipeline optimize-level gate lives in `pass.cpp`
- unlike some neighboring passes, the pass body itself **also** insists on `--closed-world`

So if you invoke `--gto` directly without `--closed-world`, the pass does **not** silently no-op.
It errors out with:

- `GTO requires --closed-world`

That direct-invocation fatal is part of the real contract.

## Phase-by-phase reading of the official implementation

## Phase 0: hard gates

`GlobalTypeOptimization::run(Module* module)` begins with two strong gates:

- if `!module->features.hasGC()` -> return immediately
- if `!getPassOptions().closedWorld` -> `Fatal() << "GTO requires --closed-world"`

So the pass has two different kinds of entry rule:

- a cheap semantic GC no-op gate
- a hard closed-world requirement

That makes `gto` stricter than several nearby passes whose default closed-world placement is mainly a scheduler choice.

## Phase 1: scan field traffic with `FieldInfoScanner`

The pass defines a tiny per-field summary:

- `FieldInfo { bool hasWrite; bool hasRead; }`

and then a derived shared-scanner pass:

- `FieldInfoScanner : StructUtils::StructScanner<FieldInfo, FieldInfoScanner>`

The scanner implements five key facts:

- `noteExpression(...)` -> write
- `noteDefault(...)` -> write
- `noteCopy(...)` -> write
- `noteRead(...)` -> read
- `noteRMW(...)` -> read **and** write

It also has one special JS-related visitor:

- `visitRefAs(RefAs* curr)`
  - when the op is `ExternConvertAny`
  - and the value type is a ref type whose descriptor may have a JS-visible prototype field
  - mark descriptor field `0` as read in the `functionSetGetInfos` map

### The shared scanner infrastructure matters more than the small derived methods suggest

`StructScanner` provides three important behaviors that are easy to miss if you only skim `FieldInfoScanner`:

- `struct.new` writes are tracked in a separate `functionNewInfos` map under **exact** heap types
- `struct.set` / `struct.get` / atomic RMW traffic is tracked in `functionSetGetInfos` under the reference's observed exactness
- `noteExpressionOrCopy(...)` first asks `Properties::getFallthrough(...)` for tee/`br_if`-style fallthrough values, and then treats a `struct.get` source specially as a copy

That means the scanner is slightly broader than “visit literal children directly.”
It already understands some fallthrough and copy shapes.

### Big beginner correction: constructor traffic does not drive the optimization decision

This is one of the most important source-backed surprises in the file.

The pass creates both:

- `functionNewInfos`
- `functionSetGetInfos`

but only **combines** and reasons over:

- `functionSetGetInfos.combineInto(combinedSetGetInfos)`

The constructor map is never combined into the actual decision data.

That explains a lot of the lit behavior:

- `struct.new` and `struct.new_default` do **not** keep a field alive
- constructor operands do **not** prevent immutability
- the pass still has to rewrite constructor operands later if a field is removed, but constructor traffic is not itself evidence that the field must stay mutable or readable

That distinction is easy to misunderstand from the pass name alone.
The source says it clearly once you follow the data flow.

## Phase 2: run the scanner on functions and module code

The pass then instantiates:

- `StructUtils::FunctionStructValuesMap<FieldInfo> functionNewInfos(*module)`
- `StructUtils::FunctionStructValuesMap<FieldInfo> functionSetGetInfos(*module)`
- `FieldInfoScanner scanner(functionNewInfos, functionSetGetInfos)`

and runs both:

- `scanner.run(getPassRunner(), module)`
- `scanner.runOnModuleCode(getPassRunner(), module)`

That means the pass explicitly looks at:

- function bodies
- module-level code such as global initializers

This module-code scan is crucial later for trap-preservation when removed constructor operands appear in global initializers.

## Phase 3: combine runtime set/get facts and analyze JS interface exposure

After scanning:

- `functionSetGetInfos.combineInto(combinedSetGetInfos)`

and then:

- `SubTypes subTypes(*module)`
- `analyzeJSInterface(*module, subTypes)`

### What `analyzeJSInterface(...)` really does

This helper is only active when:

- `wasm.features.hasCustomDescriptors()`

Inside it, the pass uses:

- `JSUtils::hasPossibleJSPrototypeField(...)`
- `JSUtils::iterJSInterface(...)`

to conservatively protect descriptor field `0` when values may flow out to JS and JS might read that field as a prototype.

The logic is:

- if a descriptor's field `0` is an immutable extern-like reference that could act as a JS prototype, mark that field as read
- values flowing **out** to JS via exports, imports, JS-called functions, tables, or globals can expose such descriptors
- inexact exposure propagates to subtypes as well, because a boundary use of a supertype may actually carry a subtype value
- exact exposure does **not** trigger subtype propagation, because `(ref exact T)` does not mean arbitrary subtypes of `T`

The lit files teach the concrete consequences:

- descriptor prototype fields with `externref` or non-null `(ref extern)` can be kept alive
- shared-extern descriptor fields are also conservatively kept
- `anyref`, `nullexternref`, and `stringref` descriptor fields are not treated as live JS prototype carriers here
- mutable descriptor fields are not treated as exposed-prototype fields here
- if a supertype flows out to JS, a subtype descriptor's prototype field may be kept alive too

So this is not ordinary wasm-level field liveness.
It is a specific JS-interop boundary rule layered on top of it.

## Phase 4: propagate usage facts across the type hierarchy

The next stage builds two propagated maps using:

- `StructUtils::TypeHierarchyPropagator<FieldInfo> propagator(subTypes)`

### Map A: `dataFromSubsAndSupersMap`

Starting from `combinedSetGetInfos`, the pass runs:

- `propagator.propagateToSuperAndSubTypes(dataFromSubsAndSupersMap)`

This gives a per-field answer to:

- did any read or write happen anywhere in the relevant super/subtype family?

That is the map used for the most conservative unread-field and immutability checks.

### Map B: `dataFromSupersMap`

Starting from the original runtime set/get info, the pass runs:

- `propagator.propagateToSubTypes(dataFromSupersMap)`

Despite the method name, the effect is:

- information from a type and its supertypes is made visible in subtypes

This gives a per-field answer to:

- did any read or write happen in ourselves or our supertypes?

That second question is exactly what the pass needs for the “field is only needed in strict subtypes” removal rule.

### Why the pass needs two different propagated maps

This split is easy to miss and very important:

- `dataFromSubsAndSupersMap` answers whether a field is read anywhere in the compatible family
- `dataFromSupersMap` answers whether the field is actually used above us, or whether only strict subtypes care about it

Without both maps, Binaryen could not distinguish:

- “the field is dead everywhere”
- from
- “the field is live only in stricter children, so the parent may drop it after reordering but the child must keep it”

## Phase 5: freeze public types entirely

Before optimizing anything, the pass asks:

- `ModuleUtils::getPublicHeapTypes(*module)`

and puts the result in a `publicTypesSet`.

Then, in the main type-processing loop, it immediately skips any type that is:

- not a struct
- or public

That means `gto` only rewrites **private struct types**.

This is a hard boundary, not a soft heuristic.

The lit files show the visible consequences:

- public rec groups stay untouched
- a public parent can block optimization of shared inherited fields in private children
- but a private child-only field can still sometimes optimize when the public parent does not contain that field at all

That public/private split is one of the easiest places for a future port to go subtly wrong.

## Phase 6: walk private structs in supertypes-first order

The pass iterates:

- `HeapTypeOrdering::supertypesFirst(propagator.subTypes.types)`

This order is not an implementation detail.
It is how Binaryen makes parent layout a fixed constraint before children decide what they can append.

For each private struct type, it uses the **exact** entry:

- `auto ht = std::make_pair(type, Exact);`

and pulls:

- `dataFromSubsAndSupers = dataFromSubsAndSupersMap[ht]`
- `dataFromSupers = dataFromSupersMap[ht]`

The exact-entry choice matters because the inexact map has one-way propagated information that would blur some of the parent/self distinctions.

## Phase 7: decide which fields can become immutable

For each field:

- if already immutable -> skip
- if any write exists anywhere in the relevant family -> skip
- if the parent has the same field index, the parent must also be markable immutable -> otherwise skip
- else mark `canBecomeImmutable[type][i] = true`

The parent check is essential.
Even if a child has no writes, Binaryen cannot make a child field immutable while the same inherited parent field stays mutable.
That would break subtype compatibility.

This explains multiple lit behaviors:

- a field with only `struct.get` traffic can become immutable
- a field with only `struct.new` traffic can still become immutable because constructor writes are not part of the decision map
- a child-only field can become immutable even when the parent has no such field
- a shared inherited field cannot become immutable if the parent is public and therefore frozen

So the real rule is not simply “no sets means immutable.”
It is:

- **no runtime family writes, and parent-compatible subtype layout still allows the same immutability choice.**

## Phase 8: decide which fields can be removed

For each field the pass computes two booleans:

- `hasNoReadsAnywhere = !dataFromSubsAndSupers[i].hasRead`
- `hasNoReadsOrWritesInSupers = !dataFromSupers[i].hasRead && !dataFromSupers[i].hasWrite`

Then it marks the field removable if either is true.

### Case A: no reads anywhere

If the field is never read anywhere in the compatible family, Binaryen can remove it even if writes exist.
That is how it deletes purely write-only fields.

### Case B: no reads or writes in ourselves and supertypes

If only strict subtypes use the field, the parent can remove it.
The subtype will keep or re-add the field later, appended after the parent's surviving fields.

This is the hardest part of the pass to teach correctly.
The lit file examples around parent/child reorderings are not cosmetic.
They are the core safety proof.

## Phase 9: compute a field permutation/removal map that preserves subtype layout

If a type has removable fields, or its parent already reordered/removed fields, Binaryen computes:

- `indexesAfterRemoval`

with a sentinel:

- `RemovedField = Index(-1)`

The algorithm preserves four layout rules at once:

1. if the parent kept a field, the child must keep it at the same new index
2. if the parent removed a field but the child still needs it, the child must append it later
3. fields defined only in the child can be removed or appended freely after inherited fields
4. a field may need to move earlier in the parent so that now-removable fields can fall off the end instead of punching holes in the middle

This is why `gto` can do things like:

- reorder a parent field from index `1` to index `0`
- then drop the now-trailing dead field
- and let the child append its still-needed copy after the new parent prefix

That is also why the pass walks supertypes first.
The parent's new order becomes the child's fixed prefix.

## Phase 10: rewrite instructions before rewriting types

If any fields are removed:

- `updateInstructions(*module)`

runs **before** type rewriting.

The source comment is explicit about why:

- while rewriting instructions we still need the old heap types to identify which original fields are being removed or reindexed

Only after that does the pass do:

- `updateTypes(*module)`

if there are any removals or any immutability changes.

That instruction-before-type order is not incidental.
A future port must preserve it.

## Phase 11: instruction rewriting preserves side effects and traps

The `updateInstructions(...)` phase creates a nested function-parallel `FieldRemover` walker and also runs it on module code.

This is where many of the non-obvious safety rules live.

### `visitStructNew(...)`

If a removed/reordered mapping exists for the constructor's type:

- inside functions:
  - run `ChildLocalizer` first so side-effectful children become locals and can be safely reordered or dropped
  - mark `needEHFixups = true` because localization may insert blocks
- then reorder/remove constructor operands according to `indexesAfterRemoval`
- in module-level code:
  - locals cannot be inserted
  - if a removed operand might trap, save it in `removedTrappingInits` so the pass can later materialize a fresh global and preserve instantiation-time traps

Important consequences shown by the lit files:

- kept fields may still be localized for simplicity when nearby removed fields make reordering easier
- immutable `global.get` children may avoid localization because their effects do not interact with later operations
- mutable `global.get` children do need localization because later calls could in theory mutate that global
- unreachable constructor operands are preserved carefully rather than silently discarded

### `visitStructSet(...)`

If the field survives:

- reindex it

If the field was removed:

- drop the value
- still null-check the reference using `ref.as_non_null`
- preserve the order so the value's side effects happen **before** the null trap on the ref
- do not emit a fence for removed atomic sets, because removed fields have no reads and therefore no synchronization partner to preserve

This is a very subtle but very real semantic rule.
The pass is not allowed to say “the field is dead, so the whole set disappears.”
It must still preserve child effects and null-trap timing.

### `visitStructGet(...)`, `visitStructRMW(...)`, `visitStructCmpxchg(...)`

These are much simpler:

- they only reindex surviving fields
- they assert that the field was not removed

This is the clearest source proof that reads, RMWs, and cmpxchgs keep a field alive.

### EH nested-pop repair

If localization inserted blocks inside functions:

- `EHUtils::handleBlockNestedPops(...)`

runs afterward on those functions.

The dedicated lit cases with `pop` in a constructor confirm this is part of the pass contract, not generic cleanup luck.

### New globals to preserve removed module-initializer traps

After the whole walk, the pass creates fresh immutable globals named like:

- `gto-removed-0`
- `gto-removed-1`

for any removed module-initializer expressions that might still trap.

This is the mechanism that preserves instantiation-time trapping even when an unread field disappears from a global initializer.
The descriptor-focused lit file exercises this explicitly.

## Phase 12: type rewriting updates private struct layout and field names

If there were any removals or immutability changes, the pass builds a local `TypeRewriter : GlobalTypeRewriter`.

Its `modifyStruct(...)` hook does two things:

1. set fields immutable according to `canBecomeImmutable`
2. apply `indexesAfterRemovals` to reorder/remove the actual struct field list

Then it does one extra thing that `GlobalTypeRewriter` cannot do for it automatically:

- repair `wasm.typeNames[oldStructType].fieldNames`

The source comment is explicit:

- the generic type rewriter can preserve names in sequence
- but it does not know the old-field -> new-field permutation
- so `gto` must remap field names manually when fields move or disappear

That field-name repair is part of the real user-visible contract.
The lit file with partial field names checks it directly.

## Phase 13: `GlobalTypeRewriter` is the real whole-module rewrite engine

`TypeRewriter(...).update()` delegates the broader heap-type remapping to shared code in `type-updating.*`.

Important consequences of that helper, visible from the source:

- only **private** types are rebuilt
- rebuilt types are topologically ordered by private predecessor constraints
- code expressions, locals, tables, element segments, globals, and tags all have their types remapped
- type names and preserved type indices are updated consistently

That is why the pass can safely mutate struct field mutability/layout while still leaving things like:

- tag parameter types
- function signatures mentioning the struct type
- locals of ref-to-struct type
- `call_indirect` signature users involving the changed struct type

in a valid state afterward.

This is one more reason the pass is bigger than its name implies.
The field mutability/removal decision is only half the job.
The type-graph rewrite is the other half.

## What the official tests prove

The lit surface is broad enough to teach the real contract well.

### `gto-mutability.wast`

This file proves that:

- no runtime `struct.set` traffic can make a field immutable
- constructor writes alone do not prevent immutability
- type updates must reach tags, locals, and call signatures too
- subtype/publicity rules matter for inherited fields
- child-only fields can still optimize when absent from the public parent

### `gto-removals.wast`

This file proves that:

- unread fields and write-only fields can disappear
- removed writes preserve value effects and null-trap ordering
- side-effectful constructor operands are localized before removal/reorder
- mutable vs immutable globals matter during localization
- subtype reordering is part of the real algorithm, not pretty-print noise
- public rec groups and public ancestors block some removals
- field names must be remapped correctly
- removed atomic sets need special handling
- EH `pop` cases require block-nested-pop repair

### `gto-removals-rmw.wast`

This file proves that:

- atomic RMW and cmpxchg count as both read and write
- they keep fields alive and mutable
- surviving atomic field operations must still have their indexes updated when earlier sibling fields disappear

### `gto-desc.wast`

This file proves that:

- descriptor-adjacent constructor traffic is still handled during field removal
- removed module-initializer operands that may trap are preserved through fresh globals
- descriptor optimization itself is not done here; a later comment points to `unsubtyping`

### `gto-jsinterop.wast`, `gto-shared-jsinterop.wast`, `gto-strings-jsinterop.wast`

These files prove that:

- descriptor prototype exposure to JS is a real liveness rule
- exposure can propagate from public supertypes to private subtypes
- exact boundary types do not imply subtype exposure the same way inexact ones do
- only prototype-capable extern-like descriptor fields are kept alive here
- strings and null-only extern refs are treated as removable prototype fields

### `gto_and_cfp_in_O.wast`

This file proves that:

- closed-world `-O` scheduling is not the same as open-world `-O`
- `gto` is part of the closed-world `-O` cluster
- later RUME/CFP wins can depend on `gto` field removal happening first

### `signature-refining_gto.wat`

This file proves one subtle robustness rule:

- after earlier signature refinement can turn a parameter into something like `ref none`, later `gto` scans and type updates must still avoid crashing when it sees dead or bottom-typed struct traffic in that neighborhood

## What the pass sounds like versus what it actually is

What it sounds like:

- a broad GC type optimizer

What it actually is in `version_129`:

- a closed-world, private-struct-only mutability/removal pass with:
  - set/get/RMW field-traffic scanning
  - JS prototype exposure handling for descriptors
  - subtype-safe layout reordering
  - instruction-before-type rewrite ordering
  - explicit side-effect and trap preservation
  - field-name repair and whole-module type remapping

That is the behavior a future Starshine port would need to preserve.

## Easy misconceptions to avoid

### Misconception 1: this is `type-refining` for globals

It is not.
`type-refining` narrows field value types.
`gto` changes only:

- mutability
- field existence
- field ordering

### Misconception 2: constructor traffic keeps a field alive

It does not, in the actual decision phase.
Constructor traffic matters later for rewrite safety, but not for the liveness/mutability decision itself.

### Misconception 3: unread field removal is local to one struct

It is not.
Subtype compatibility means the pass reasons across parents and children and may reorder parent fields first.

### Misconception 4: once a field is dead, all its writes can disappear completely

They cannot.
Removed writes still preserve:

- child side effects
- null-trap timing on the reference
- instantiation-time traps for removed module-initializer operands

### Misconception 5: descriptor fields are just ordinary fields here

They are not.
Ordinary descriptor optimization is deferred to `unsubtyping`, while `gto` only protects JS-visible prototype fields from accidental removal.

## Porting checklist for future Starshine work

A future Starshine port would need to preserve at least these behaviors:

- module-pass scope, not a local HOT-only peephole
- hard closed-world requirement and GC gate
- the upstream/local naming split (`gto` vs `global-type-optimization`)
- hierarchy-aware field immutability and removal reasoning
- JS prototype descriptor exposure handling
- instruction rewrite before type rewrite
- side-effect/trap preservation for removed `struct.set` and `struct.new` operands
- module-initializer trap preservation via fresh globals or a semantically equivalent mechanism
- field-name remapping after field permutation/removal
- whole-module type remapping for tags, signatures, locals, tables, globals, and expressions

Any port that only removes unread fields syntactically will miss the real Binaryen contract.

## Bottom line

Binaryen `global-type-optimization` in `version_129` is a specialized closed-world struct-layout cleanup pass.

It is not generic GC type inference.
It is not just dead-field stripping.
And it is not safe without careful hierarchy, JS-boundary, and trap-order reasoning.

The small public summary in `pass.cpp` hides all of that.
The source and tests do not.

## Sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`
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
- Narrow freshness-check sources:
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
