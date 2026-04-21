# 0150 - Binaryen `type-refining` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `remove-unused-types` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `type-refining`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/type-refining/`
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

- the main no-DWARF / saved-`-O4z` queue no longer had any pass with wiki status `none`
- the implemented-landing queue was already closed
- the recently documented major-gap fallbacks named in the tracker were already closed
- the prompt explicitly excluded the parity-queue dossiers that recent threads had just refreshed
- `agent-todo.md` still had **no dedicated `type-refining` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `type-refining` for six source-backed reasons:

- It is the first pass named in the tracker's current suggestion list of still-`none` upstream-only candidates.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- The current living `global-refining` dossier already records it as the first closed-world GC/type-tightening neighbor before `signature-pruning`, `signature-refining`, and `global-refining`.
- It still had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official Binaryen implementation is much more specific than the name suggests: this is not generic type tightening everywhere, but a closed-world, GC-only **struct-field** refinement pass with a small direct scanner mode and a separate GUFA-backed whole-program mode.
- The implementation hides multiple beginner traps that are worth documenting explicitly:
  - normal `type-refining` and `type-refining-gufa` are different passes with different information sources
  - the pass body itself requires `--closed-world` and will `Fatal()` if you run it without that option
  - the default no-DWARF open-world path in this repo does **not** include it
  - Binaryen refines only **private** struct types here
  - reads do not constrain inference, so Binaryen must repair invalidated `struct.get` / `struct.new` / `struct.set` shapes afterward
  - the normal variant deliberately ignores some tee / `br_if` fallthroughs to avoid expensive or invalid cast repair

So this thread is not re-opening an old parity item.
It is the first explicit living dossier for the closed-world `type-refining` pass that sits immediately before the repo's existing `global-refining` / `gsi` cluster docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit files checked on reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `TypeRefining.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed surfaces that matter most here:
  - same `hasGC()` early gate
  - same `--closed-world` requirement with `Fatal()` on direct misuse
  - same normal-vs-GUFA split
  - same `StructScanner` / `ContentOracle` two-path design
  - same public-type freeze in `useFinalInfos`
  - same `ReadUpdater -> GlobalTypeRewriter -> ReFinalize -> WriteUpdater` repair sequence
- the checked `pass.cpp` registration still exposes both `type-refining` and `type-refining-gufa`
- the checked dedicated lit files still match the reviewed `version_129` families on the important surfaces used in this note

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
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `type-refining`
- the local registry tracks the base pass name `type-refining`, but not the upstream companion pass name `type-refining-gufa`
- the current living `global-refining` docs already treat `type-refining` as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `type-refining` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `type-refining` is not a generic whole-IR type optimizer.

The real `version_129` contract is much narrower and more concrete:

1. require GC features and a closed-world module
2. infer what values can reach **struct fields**
3. combine those writes with subtype-aware LUB logic
4. refuse to edit public struct types
5. preserve field-subtyping rules across the struct hierarchy
6. rewrite the private struct declarations to the more precise field types
7. repair reads and writes that would otherwise stop validating after those refinements

A better short summary is:

- **Binaryen tightens private struct field types based on whole-module writes, then repairs the affected reads and writes so the rewritten module still validates.**

The two biggest beginner corrections are:

- `type-refining` and `type-refining-gufa` are not the same inference engine
- the pass is not safe to think of as “just edit the type declarations” because the repair pipeline is part of the real algorithm

## Upstream naming and variant surface

`pass.cpp` registers two closely related upstream pass names:

- `type-refining`
- `type-refining-gufa`

The summaries are:

- `type-refining`: `apply more specific subtypes to type fields where possible`
- `type-refining-gufa`: same idea, but `(using GUFA)`

That split matters a lot.

### The base pass

The base pass is the one this thread chose because:

- it is the locally tracked registry name
- it is the closed-world scheduler neighbor already mentioned by the existing docs
- it is the simpler first dossier target

### The upstream GUFA companion

The official Binaryen source and tests show that `type-refining-gufa` is not just a debug alias.
It is a stronger variant that uses `ContentOracle` / GUFA to infer field contents through locals, globals, calls, and other whole-program flows that the normal pass does not model directly.

The new living dossier therefore needs to mention GUFA clearly even though the tracker row is for the base pass.
Otherwise the reader will not understand why upstream ships extra `type-refining-gufa*` tests or why some examples optimize only in GUFA mode.

## Scheduler placement

`type-refining` is not part of the repo's main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default prepass cluster is:

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

That teaches three durable things:

- this pass is a **closed-world pre-`global-refining`** type-tightening pass
- it belongs to the early GC/type cluster, not the later function-pass cluster
- its default-pipeline optimize-level gate lives in `pass.cpp`, while the pass body itself only checks GC + closed-world

That last point is easy to miss.
If you run `--type-refining` directly, the pass body does **not** check `optimizeLevel >= 2`; it only checks:

- `hasGC()`
- `closedWorld`

So the optimize-level gate is a **scheduler rule**, not a pass-local semantic gate.

## Phase-by-phase reading of the official implementation

## Phase 0: hard GC and closed-world gates

`TypeRefining::run(Module* module)` begins by doing exactly two gates itself:

- if `!module->features.hasGC()` -> return immediately
- if `!getPassOptions().closedWorld` -> `Fatal() << "TypeRefining requires --closed-world"`

This is an important teaching point.
The pass does not silently no-op in open world.
If invoked directly without `--closed-world`, it errors out.

That tells us the intended proof boundary is strict.
This pass is not a best-effort open-world cleanup.

## Phase 1: the pass splits into normal and GUFA inference modes

`TypeRefining` stores a boolean `gufa` and then does:

- `computeFinalInfos(module, propagator)` in normal mode
- `computeFinalInfosGUFA(module, propagator)` in GUFA mode
- then `useFinalInfos(module, propagator)` in either case

So both upstream pass names share the same back half:

- public/private legality checks
- subtype repair
- read repair
- type rewriting
- write repair

They differ mainly in **how they fill `finalInfos`**.

That is a clean teaching model:

- **different inference front ends, shared rewrite/fixup back end**

## Phase 2: normal mode scans concrete struct operations, not general flow

The normal pass uses `FieldInfoScanner`, which subclasses:

- `StructUtils::StructScanner<FieldInfo, FieldInfoScanner>`

Important helper facts from `struct-utils.h`:

- the tracked key is `(HeapType, Exactness)`, not just `HeapType`
- `struct.new` information is stored separately from `struct.set` / `struct.get` information
- the scanner visits:
  - `struct.new`
  - `struct.set`
  - `struct.get`
  - `struct.atomic.rmw`
  - `struct.atomic.rmw.cmpxchg`
  - descriptor reads through `ref.cast`, `br_on*`, and `ref.get_desc`
- `noteExpressionOrCopy(...)` uses `Properties::getFallthrough(...)` to peek through some wrappers and decide whether a write is really a copy from a `struct.get`

So the normal pass is not flow-insensitive in the sense of ignoring exactness or subtype direction.
But it is still much narrower than GUFA.
It tracks **direct struct traffic plus some simple fallthrough copies**, not arbitrary local/global/call dataflow.

## Phase 3: field facts are really `LUBFinder`s

The pass uses:

- `using FieldInfo = LUBFinder;`

`LUBFinder` is tiny:

- `note(type)` folds a new type into the least upper bound
- `noted()` says whether anything reachable was seen
- `getLUB()` returns the current accumulated type

The important beginner correction is:

- the pass is not keeping a full set of all written types forever
- it is keeping the **current best LUB summary** for each field position

That makes the algorithm smaller and more conservative than the pass name might suggest.

## Phase 4: `FieldInfoScanner` records writes, but reads usually do not constrain inference

In the normal path:

- `noteRead(...)` is empty

That means ordinary reads do **not** constrain the inferred field type.
The pass deliberately assumes it can optimize based on writes alone and repair the reads later if needed.

This is one of the most important misunderstandings to prevent.
A reader might assume a field read of type `anyref` blocks refining that field to `(ref $T)`.
Binaryen does **not** work that way here.
Instead it:

- ignores ordinary reads during inference
- then uses `ReadUpdater` later to replace now-invalid reads with trap-equivalent unreachable code or updated result types

## Phase 5: default values matter mostly for nullability

`noteDefault(...)` shows another subtle rule.

For ref-typed fields, default values do **not** teach the pass an exact heap type.
Instead they only preserve nullability by noting a bottom nullable value:

- `Type(fieldType.getHeapType().getBottom(), Nullable)`

That means:

- `struct.new_default` can force a field to remain nullable
- but it does not by itself pin the field to a wide heap type like `anyref`

This is why the tests can refine fields all the way to things like:

- `nullref`
- `nullfuncref`
- `(ref null $child)`

when the only meaningful reachable writes are null-like defaults plus more specific non-null values.

## Phase 6: identical field-to-same-field copies do not block refinement

`noteCopy(...)` checks whether a write is really just copying a field to itself:

- same source heap type
- same destination heap type
- same field index

If so, it ignores that copy.

That is why tests like:

- `struct.set $T 0 ... (struct.get $T 0 ...)`

can still optimize.

But the surrounding scanner logic matters.
The pass is willing to look through only some fallthrough wrappers.
The custom `getFallthroughBehavior()` returns:

- `Properties::FallthroughBehavior::NoTeeBrIf`

and the long source comment explains why.
A `local.tee` fallthrough can leave the tee itself typed too broadly after the field becomes more precise, which would require later expensive or invalid fixups.
So the normal pass deliberately refuses to treat tee/`br_if` fallthroughs as transparent here.

This directly explains the lit contrast between:

- `local.tee` copy families that block refinement
- `if` / block fallthrough families that still refine and rely on `ReFinalize`

## Phase 7: normal mode separates exact `struct.new` writes from broader writes

The normal mode computes two maps:

- `functionNewInfos`
- `functionSetGetInfos`

Then it combines them with different propagation rules:

- `combinedNewInfos` -> `propagateToSuperTypes(...)`
- `combinedSetGetInfos` -> `propagateToSuperAndSubTypes(...)`

This is an important shape rule.

### Why `struct.new` propagates only upward

A `struct.new $Child (...)` knows the exact created type.
Its values must fit into the fields of:

- `$Child`
- any supertypes that share those fields

but that does **not** force sibling or subtype fields downward.
If it did, subtypes could never become more specific than their parents.

### Why `struct.set` traffic propagates both upward and downward

A `struct.set` sees only the reference type at the write site.
That may be:

- an inexact supertype
- the exact same type
- a field copy that semantically affects other related types

So Binaryen propagates this information in both directions across the hierarchy to keep field relationships valid.

The implementation support for exact vs inexact entries in `StructValuesMap` is part of how that remains precise enough.

## Phase 8: GUFA mode uses `ContentOracle` instead of scanning direct ops

The GUFA variant does not use `FieldInfoScanner` as its primary inference engine.
Instead it does:

- `ContentOracle oracle(*module, getPassOptions());`
- iterate all heap types with `ModuleUtils::collectHeapTypes(*module)`
- for each struct field query `oracle.getContents(DataLocation{type, i}).getType()`

This is a much more powerful information source.
It can see through locals, globals, calls, and other whole-program flows that the normal scanner never models directly.
That is why the dedicated `type-refining-gufa.wast` file includes examples where:

- normal mode refines only one field partially
- GUFA refines a second field further
- even repeated `-O3 -O3` runs still do not necessarily match GUFA because the information is cyclic or cross-pass-sensitive

So GUFA is not just “normal mode but more passes.”
It is a different inference engine.

## Phase 9: GUFA still keeps several conservative escape hatches

The GUFA front end is stronger, but not reckless.
The source shows three important conservative rules.

### 1. Do not invent new exact fields when that would require invalid exact casts

If a field is not already exact, GUFA uses:

- `withInexactIfNoCustomDescs(module->features)`

This matches the dedicated `type-refining-gufa-exact.wast` coverage:

- with custom descriptors enabled, GUFA may refine to exact fields and repair writes with `ref.cast`
- with custom descriptors disabled, it must stay inexact in cases where the later exact cast would not be valid
- fields that were already exact stay exact

### 2. Do not use continuation types that later fixups cannot cast to

If GUFA infers a continuation type for a field, the pass refuses to use that refined continuation type and instead falls back to the original field type.

The code comment is explicit:

- we cannot add the needed casts later for continuations

This matches the continuation-focused coverage in:

- `type-refining-gufa-exact.wast`
- `type-refining-gufa.wast`

### 3. Take global initializers into account because casts are not available there

After the main GUFA queries, the pass explicitly scans non-imported globals for `StructNew` initializers and notes each child operand type.

Why?
Because the later `WriteUpdater` only fixes **function** writes.
It does not rewrite module-level global initializers by inserting casts there.
So GUFA must ensure that any refined field type remains directly compatible with global initializer operands.

This is one of the most non-obvious contracts in the entire pass.

## Phase 10: public types are frozen

The shared back end begins `useFinalInfos(...)` by computing:

- `auto publicTypes = ModuleUtils::getPublicHeapTypes(*module);`

and then skipping any public type in the main refinement walk.

That means:

- this pass edits only **private** struct types
- public type boundaries are protected here
- if a child type is public, helper visibility analysis can make important ancestors effectively public too

The dedicated `type-refining.wast` file has explicit public-type tests showing that:

- a public child can force the parent to remain unrefined
- a private immutable child below that public structure may still refine if it can do so without violating the supertype relationship

This public/private split is a major part of the real contract, not a tiny edge case.

## Phase 11: unused or never-written types still need valid field types

Inside `useFinalInfos(...)`, Binaryen walks the struct hierarchy from roots downward.
For each non-public type it first fills any never-noted field with its old type.

This is crucial for two families:

- a type that is referenced but never instantiated
- a child type whose parent refined due to writes elsewhere

If Binaryen left those fields as `unreachable`, later rewriting would create nonsense.
Instead it picks a safe fallback and then enforces subtype correctness against the parent field.

That is why tests can cover cases like:

- unused child types whose parent still needs a refined field
- child types that already have a more specific immutable field than the parent and should not be widened unnecessarily

## Phase 12: field-subtyping and mutability rules are enforced after inference

After filling missing entries, the pass compares each subtype field against its supertype field.

If the refined child field is **not** a subtype of the refined super field:

- it copies the super's field type down into the child

This handles cases where a child never had direct writes but the parent did.

Then there is a separate mutability rule:

- if the field is mutable, the child field type is forced to equal the super field type

That is a big beginner correction.
A mutable field cannot be specialized in a subtype relative to its super here.
Immutable fields can differ more.
The public-type lit coverage makes this very visible.

## Phase 13: if anything changed, Binaryen repairs reads before rewriting types

When `canOptimize` is true, Binaryen does:

1. `updateInstructions(*module)`
2. `updateTypes(*module)`

The order is meaningful.

### `ReadUpdater`

`updateInstructions(...)` installs a `ReadUpdater` that visits `StructGet` in both:

- function bodies
- module code via `runOnModuleCode(...)`

For each read it computes the new field type and then has three outcomes.

#### Outcome A: the read is now logically impossible or uninhabitable

If:

- the reference is null
- or the new field type is `unreachable`
- or the new field type is not a subtype of the current `struct.get` result type

then Binaryen replaces the read with:

- `drop(ref)`
- `unreachable`

This is why the tests contain comments like:

- `block ;; (replaces unreachable StructGet we can't emit)`

The pass cannot literally emit an unreachable `struct.get`, so it emits trap-equivalent code instead.

#### Outcome B: the read is still valid but should return a more precise type

In the common case it simply sets:

- `curr->type = newFieldType`

and lets later refinalization update parents.

The source comment explains why it does this itself instead of relying only on `ReFinalize`:

- recursive cases involving blocks can temporarily bottom out in ways that would prevent `ReFinalize` from rediscovering the right `struct.get` type from scratch

So explicit read retagging is part of the algorithm, not an optional cleanup.

## Phase 14: `GlobalTypeRewriter` applies the actual private struct field rewrite

`updateTypes(...)` creates a `TypeRewriter` subclass of `GlobalTypeRewriter` and overrides only:

- `modifyStruct(...)`

For each ref-typed struct field it looks up the final LUB and writes that into the temporary type builder entry.

Then `GlobalTypeRewriter(...).update()` does the full-module heap-type remapping.

This is another important correction:

- the pass does **not** patch declarations in place with a few local string edits
- it uses Binaryen's whole-module type-rewrite helper for private heap types

## Phase 15: `ReFinalize` repairs surrounding expression types

After type rewriting, Binaryen immediately runs:

- `ReFinalize().run(getPassRunner(), &wasm);`

That propagates the refined field types through parent expressions.
This is what lets control-flow wrappers such as:

- `if`
- `block`
- `try`

pick up narrower types when the refined field value flows through them.

It also explains why the pass can optimize `if`-based fallthrough families that it refused to treat like transparent tee fallthroughs during the original copy scan.

## Phase 16: `WriteUpdater` adds casts or null/unreachable shims when wasm types are still too coarse

Even after `ReFinalize`, the module may still have write sites whose value type is too broad for the newly refined field.
So the pass runs `WriteUpdater` over function bodies and fixes:

- `StructNew`
- `StructSet`
- `StructRMW`
- `StructCmpxchg`

### Normal repair: insert `ref.cast`

If a value is not a subtype of the refined field type, Binaryen typically wraps it in:

- `ref.cast`

This is why GUFA exactness improvements often show up as new casts in the lit output.

### Bottom-type repair: emit null or unreachable instead of a cast

If the refined field type is a bottom heap type, Binaryen cannot rely on a cast.
It instead emits either:

- `drop(value); ref.null bottom` for nullable bottoms
- `drop(value); unreachable` for non-nullable bottoms

This is how the pass handles some continuation and uninhabited-type families.

### Refinalize only when needed

`WriteUpdater` tracks a `refinalize` flag and only re-runs `ReFinalize` on a function when one of those bottom/unreachable repairs changed the control-flow shape.

## Important test-surface conclusions

The official lit files are unusually good at teaching what this pass really does.

## `type-refining.wast`

This file covers the normal pass's real contract:

- direct struct-set and struct-new subtype narrowing
- nullability preservation from defaults and explicit null writes
- exact / inexact subtype propagation across parent and child structs
- copy detection that does not block optimization
- tee fallthrough cases that deliberately **do** block optimization
- block / `if` / `try` families that still optimize after refinalization
- manual `struct.get` type repair
- public-type freeze and mutable-supertype equality rules
- unreachable replacements for invalidated reads and writes
- bottom-type and uninhabited-field corner cases
- the public-type helper regression around issue `#7103`

## `type-refining-gufa.wast`

This file teaches the companion pass difference:

- GUFA can refine through locals, globals, calls, and cyclic whole-program flows that the normal pass misses
- even running `-O3 -O3` does not guarantee the same result because the pass interaction is not equivalent to GUFA's oracle
- global declared types can cap how far a refined struct field may go
- continuation and array-adjacent regression families must remain safe while unrelated struct opportunities still optimize

## `type-refining-gufa-exact.wast`

This file is the main source for exactness and cast legality:

- refine to exact when legal
- keep already-exact fields exact
- avoid introducing new exactness when custom descriptors are disabled
- avoid continuation exactness that later cast repair cannot express

## `type-refining-gufa-rmw.wast`

This file proves the pass stays conservative around atomic RMW / cmpxchg families and array-adjacent surfaces.
That matches the source comment at the top of `TypeRefining.cpp`:

- arrays are still TODO for actual refinement logic

So the pass today is a **struct field** refiner with extra regression coverage around nearby array / atomic surfaces, not a generic GC aggregate refiner.

## What this pass does **not** do

These non-goals are important to keep explicit.

- It does not run in open world.
- It does not refine public struct types.
- It does not refine arrays yet.
- It does not use ordinary reads as inference constraints.
- It does not do full local/global/call dataflow in the normal variant.
- It does not assume tee/`br_if` fallthrough copies are always safe to analyze.
- It does not rewrite function signatures; neighboring signature passes do that.
- It does not rely on `ReFinalize` alone; explicit read/write fixups are part of the contract.
- It does not support arbitrary continuation cast repair.

## What a future Starshine port must preserve

A future strict-parity Starshine port or broader boundary-only implementation would need to preserve at least these Binaryen-backed rules:

- closed-world hard requirement
- GC-only scope
- private-type-only rewriting
- normal-vs-GUFA inference split
- `struct.new` data propagated only upward
- `struct.set` / copy data propagated both upward and downward
- default-null handling that preserves nullability without forcing a wide heap type
- tee/`br_if` fallthrough conservatism
- explicit repair of invalidated `struct.get` nodes
- `GlobalTypeRewriter`-style full-module type remapping
- post-rewrite `ReFinalize`
- post-rewrite `StructNew` / `StructSet` / RMW / cmpxchg cast-or-null-or-unreachable repair
- exactness and continuation restrictions from the GUFA exact tests
- public-type freeze and mutable-supertype equality

If local implementation intentionally widens or narrows any of those rules, that divergence needs to be documented explicitly.

## Documentation filed back into the living wiki

This research is being crystallized into a new living folder:

- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`
- `docs/wiki/binaryen/passes/type-refining/wat-shapes.md`

Tracker/index/log updates are also part of this same change.

## Bottom line

Binaryen `type-refining` in `version_129` is best understood as:

- a closed-world GC struct-field rewrite pass
- with a direct-ops inference mode and a GUFA inference mode
- followed by a mandatory declaration/read/write repair pipeline

The pass sounds like a vague type-tightening cleanup.
The official source says something much sharper:

- **refine private struct fields from writes, then actively repair the code that those refinements would otherwise invalidate.**

## Sources

- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>
- Repo context:
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
  - `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
  - `src/passes/optimize.mbt`
  - `agent-todo.md`
