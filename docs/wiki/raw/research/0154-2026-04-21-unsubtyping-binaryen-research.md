# 0154 - Binaryen `unsubtyping` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `global-type-optimization` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes plus the new closed-world cluster dossiers, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `unsubtyping`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/unsubtyping/`
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
- the prompt still excluded the recently refreshed parity dossiers and the newly added `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, and `global-type-optimization` upstream-only dossiers
- the tracker's clearest still-`none` upstream-only candidates were `abstract-type-refining`, `unsubtyping`, `minimize-rec-groups`, and `reorder-types`
- `agent-todo.md` still had **no dedicated `unsubtyping` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `unsubtyping` for seven source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- It sits directly after `gsi` and optional `abstract-type-refining` in Binaryen's closed-world GC/type cluster, so documenting it now closes the largest remaining hole in that late cluster.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official implementation is more specific than the name suggests: it is not generic type merging or generic declaration shrinking, but a fixed-point pass that computes the smallest remaining **subtype** and **descriptor** relations needed to keep validation and cast behavior unchanged.
- The implementation hides several beginner traps that are worth documenting explicitly:
  - the pass body itself hard-requires `--closed-world`
  - descriptors are optimized here too, not only ordinary subtype edges
  - the analysis is driven by **validation constraints**, **cast success preservation**, **descriptor-square completion**, and **JS-boundary exposure**, not just by declaration reachability
  - exact casts impose a smaller requirement surface than ordinary casts
  - `ref.eq` and similar non-flow constraints are deliberately prevented from blocking unrelated user-type unsubtyping
  - many official visible shrink results are produced under the test harness combination `--unsubtyping --remove-unused-types`, so not every disappeared type in the test output is deleted by `unsubtyping` alone
  - allocation fixups and post-rewrite `ReFinalize()` are part of the real contract
- The official test surface is broad and teachable, with focused files for baseline validation constraints, casts, descriptor relations and trap preservation, traps-never-happen mode, JS interop, cmpxchg/shareability details, and stack-switching continuation shapes.

So this thread is not reopening an old parity item.
It is the first explicit living dossier for the closed-world-cluster `unsubtyping` pass that sits after the repo's newer `gsi` / `global-type-optimization` / `remove-unused-types` docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Unsubtyping.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtype-exprs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-stack-switching.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Unsubtyping.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit files checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-stack-switching.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `Unsubtyping.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed algorithmic surfaces that matter most here:
  - same GC gate
  - same hard `--closed-world` fatal
  - same `TypeTree` / worklist fixed-point structure
  - same `analyzePublicTypes` / `analyzeJSInterface` / `analyzeModule` split
  - same exact-vs-ordinary cast distinction in `Noter::noteCast(...)`
  - same descriptor-square completion logic
  - same `fixupAllocations(...) -> rewriteTypes(...) -> ReFinalize()` tail
- the only reviewed `Unsubtyping.cpp` diffs were tiny non-semantic cleanup:
  - `analyzeJSInterface(Module& wasm)` became `analyzeJSInterface(const Module& wasm)`
  - `collecing` was corrected to `collecting`
- the checked `pass.cpp` diff on the reviewed `unsubtyping` surfaces did not change the `unsubtyping` registration or its scheduler slot; the observed diff hunks were unrelated spelling fixes elsewhere in the registry
- the checked dedicated lit files above were unchanged on the reviewed surfaces

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
- `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `unsubtyping`
- the local registry tracks the pass only as the full boundary-only name `unsubtyping`
- the current living `global-refining`, `global-struct-inference`, `global-type-optimization`, `remove-unused-types`, and `type-refining` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `unsubtyping` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `unsubtyping` is not generic “remove extra subtype edges.”

The real `version_129` contract is narrower and more concrete:

1. require GC features and reject non-closed-world invocation
2. collect the **initial** subtype and descriptor relations that are directly required by:
   - public boundary types
   - JS interface flow
   - IR validation constraints
   - explicit descriptor users
3. record ordinary downcasts as a separate cast relation instead of immediately forcing every visible declaration edge
4. iterate to a fixed point where each required subtype or descriptor edge can imply further edges through:
   - type definitions
   - cast-success preservation
   - descriptor-square completion
5. represent the minimized relation as a mutable type forest rather than reusing the original declaration forest directly
6. drop unnecessary descriptor arguments from `struct.new_desc` allocations when the described type no longer needs a descriptor relation
7. preserve nullable-descriptor traps inside functions with `ref.as_non_null` plus localization, and preserve instantiation-time traps outside functions with fresh `unsubtyping-removed-*` globals when needed
8. rewrite private type declarations so they keep only the remaining declared supertype and descriptor/describes edges
9. refinalize afterward because the changed type graph can sharpen or invalidate surrounding cast and control shapes

A better short summary is:

- **Binaryen `unsubtyping` is a closed-world GC module pass that computes the smallest remaining subtype and descriptor graph needed to preserve module validity, cast behavior, and relevant JS-observable descriptor semantics.**

The four biggest beginner corrections are:

- the pass owns **descriptor** cleanup too, not only ordinary subtyping
- ordinary `ref.cast` / `ref.test` do **not** automatically require the target relation unless a concrete flowing subtype makes cast success observable
- exact casts are cheaper than ordinary casts because they only require the exact destination type to remain a subtype of the source
- much of the visible type-section shrink in the shipped tests comes from the common harness pairing `--unsubtyping` with `--remove-unused-types`

## Upstream naming and scheduler surface

`pass.cpp` registers the pass with the public CLI name:

- `unsubtyping`

and the summary:

- `removes unnecessary subtyping relationships`

That summary is accurate, but too small.
It hides several central details:

- the pass is a **module pass**, not a local peephole
- it optimizes **descriptor** relations as well as subtype edges
- it is a **fixed-point** pass rather than a one-shot declaration scan
- it preserves **cast behavior**, not just structural validity
- it preserves some JS-observable descriptor behavior too

### Relation to nearby passes

The most useful cluster model is:

- `type-refining` and the signature passes tighten field and function types earlier in the closed-world cluster
- `global-refining` and `gto` shrink global/field facts before `gsi`
- `gsi` cleans up global-struct usage and can expose more redundant late type relations
- `abstract-type-refining` can collapse never-created abstract types before the final relation minimization step
- `unsubtyping` then removes unnecessary declared subtype and descriptor edges while keeping only what the final module still needs
- `remove-unused-types` can afterwards erase now-unreferenced heap types more aggressively if it is run

So `unsubtyping` is not the first type-tightening step in the cluster.
It is the **late relation-pruning step**.

### Scheduler placement

`unsubtyping` is not part of the repo's main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default global-prepass cluster is:

- if `wasm->features.hasGC()` and `options.optimizeLevel >= 2`
- and if `options.closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That teaches four durable things:

- `unsubtyping` is a **closed-world late GC/type-cluster cleanup**, not an open-world parity pass
- it runs after `gsi`, which means it sees the already-tightened type graph from several earlier neighbors
- the default placement is purely in the global prepass cluster, not in the function-pass loop
- unlike some neighboring passes, the pass body itself **also** insists on `--closed-world`

## Core algorithm: fixed-point relation minimization

The key implementation idea is very different from passes like `remove-unused-types` or `gto`.

Binaryen does **not** begin by asking:

- which declared supertype edges or descriptor edges look unused syntactically?

It begins by asking:

- which relations must remain for the current code and boundary behavior to keep validating and keep behaving the same?

Then it computes the transitive closure of that requirement set under three families of implications.

### Family 1: validation constraints from IR and public boundaries

Some subtype or descriptor edges are directly needed just so the module still validates.
Examples include:

- function body result flowing to declared function result
- `local.set`, `local.tee`, `global.set`, `table.set`, `table.fill`, `table.copy`, and `table.init`
- `block`, `if`, `loop`, `br`, `br_if`, `br_table`, `return`, and tuple return flows
- direct `call`, `return_call`, `call_indirect`, `return_call_indirect`, and `call_ref`
- `throw`, tag payloads, `resume`, `suspend`, `cont.new`, and `cont.bind`
- `struct.new`, `struct.set`, `struct.atomic.rmw`, `struct.atomic.rmw.cmpxchg`
- `array.new*`, `array.set`, `array.copy`, `array.fill`, `array.atomic.rmw.cmpxchg`
- explicit descriptor users such as `ref.get_desc`, `ref.cast`/`br_on_cast*` descriptor operands, and some module-level `struct.new_desc` trap cases
- public types, which keep their declared supertype and descriptor edges frozen

Most of this is discovered by the shared `SubtypingDiscoverer` walker in `subtype-exprs.h`, with `Unsubtyping.cpp` adding the descriptor- and JS-specific special cases.

### Family 2: type-definition implications

If we keep:

- `sub <: super`

then the contents of those definitions may force more relations.

Examples:

- function params are contravariant and results covariant
- struct field types of the subtype must still be subtypes of the corresponding super fields
- array element types must remain compatible
- continuation payload signatures must remain compatible

So a single kept declaration edge can force many more edges between child heap types.

### Family 3: cast-success preservation

This is the most important non-obvious piece.

A cast from `$src` to `$dst` does **not** automatically mean `$dst <: $src` must remain.
What matters is whether values of some concrete subtype that can flow into `$src` would have succeeded before and would fail after removing some relation.

Binaryen therefore stores ordinary casts separately and later says, roughly:

- for every currently known remaining subtype `v` of the cast source `src`
- if `v <: dst` in the original type graph
- then we must keep `v <: dst` in the optimized graph too

That is why a cast can be harmless in one module and relation-preserving in another.
A cast only blocks edge removal once actual flowing inhabitants make the success condition observable.

### Exact casts are cheaper

`Noter::noteCast(...)` makes a particularly important distinction:

- for an ordinary cast to an inexact destination, keep the cast pair and reason about all possible remaining subtypes later
- for an **exact** cast, only require:
  - `dst <: src`

because subtypes of the destination do not matter for exact matching.

That is a major beginner trap, and the official `unsubtyping-casts.wast` file has dedicated exact-cast coverage for it.

### Descriptor squares make descriptors recursive

Descriptors are not independent metadata here.
They interact with subtyping in a square:

- `A -> A.desc`
- `B -> B.desc`
- `B <: A`
- `B.desc <: A.desc`

If enough of that square remains, the validation rules can force the rest.
`completeDescriptorSquare(...)` is the central helper that keeps adding the missing edges until the square stops expanding.

This is the main reason the pass owns descriptors directly instead of delegating them to another pass.

## Initial analysis phases

## 1. Public types

`analyzePublicTypes(...)` seeds the worklist with:

- any declared supertype edge of a public heap type
- any descriptor edge of a public heap type

That is the first source-backed reason the pass only rewrites private types meaningfully.

## 2. JS interface

`analyzeJSInterface(...)` uses `JSUtils::iterJSInterface(...)`.

That helper models JS boundary flow like this:

- values flowing **in** from JS are treated like implicit casts from `any`
- values flowing **out** to JS are treated like flowing into `any`
- exported and `@binaryen.js.called` functions contribute params/results
- imported functions do the inverse
- tables and globals contribute flows too, with mutability-sensitive differences for globals

Two durable consequences follow.

### JS boundary can keep subtype edges

If a type can flow in from JS, `unsubtyping` may need to preserve cast-like behavior from `any` to that type.
If a type can flow out to JS, it may need to preserve a subtype edge to `any`.

### JS boundary can keep descriptors

`noteExposedToJS(...)` keeps a descriptor only when:

- the type has a descriptor
- and `JSUtils::hasPossibleJSPrototypeField(...)` says field `0` could configure a JS prototype

That helper is very narrow:

- descriptor field `0` must exist
- it must be immutable
- it must be a subtype of `externref`

So JS exposure does **not** keep arbitrary descriptor fields alive.
It only preserves the possible prototype-carrying case.

## 3. Module analysis walker

`analyzeModule(...)` uses a parallel function analysis plus extra module-code walking.

The `Collector` class mixes:

- `ControlFlowWalker`
- `SubtypingDiscoverer`
- `Noter`

and records four things:

- observed subtype constraints
- observed casts
- observed descriptor requirements
- types exposed to JS via `extern.convert_any`

### Special descriptor cases in the collector

The collector extends the shared subtype walker with pass-specific cases:

- `ref.get_desc` requires the operand's described/descriptor relation
- `ref.cast` and `br_on_cast*` with an explicit descriptor operand require that descriptor relation too
- `struct.new_desc` normally does **not** force the descriptor relation to remain
- but a **module-level** nullable descriptor allocation can force the relation if traps must still be preserved and we cannot localize it with function temps
- `extern.convert_any` exposes its operand type to JS

### Non-flow subtype constraints are deliberately weakened

`Collector::noteNonFlowSubtype(...)` contains a subtle but important relaxation.

For non-flow constraints whose required supertype is a basic heap type, such as the `eqref` requirement in `ref.eq`, the pass ignores them for cast-propagation purposes.
The reason is:

- those constraints matter for validation
- but they do **not** imply user-defined values flow anywhere new
- and the pass is only changing user-defined subtype edges anyway

This is why `ref.eq` coverage in `unsubtyping-casts.wast` is a negative/bailout family rather than a blocker that keeps unrelated user edges alive.

## Fixed-point processing details

## TypeTree is the mutable minimized forest

The pass stores the current minimal relation in `TypeTree`, which keeps:

- a parent pointer for each type
- child lists for each type
- optional described / descriptor links
- a `subtypesExposedToJS` bit

The crucial thing here is that this is **not** a copy of the original declaration forest.
It is the growing minimized forest under construction.

## `processSubtype(...)`

When the worklist says `sub <: super` is needed, `processSubtype(...)`:

1. checks whether `sub` already has a recorded supertype
2. if yes, compares the old and new supertype and can recurse to relate them first
3. reparents the subtree in `TypeTree`
4. propagates JS exposure if the new supertype was already marked as JS-exposed inexactly
5. completes descriptor squares left and right of the new edge
6. adds further requirements from type definitions
7. adds further requirements from stored casts

### Why reparenting matters

A type may first be known to need a shallow supertype and later a deeper one.
The pass does not blindly keep both edges.
It tries to keep the minimal tree by reparenting `sub` under the most specific required remaining supertype and then preserving only the relations that still matter above that.

That is the source-backed reason the pass is not just “delete some edges and keep the rest.”
It is actively rebuilding a smaller forest.

## `processDescriptor(...)`

When the worklist says a described/descriptor edge is needed, `processDescriptor(...)`:

1. records the edge in `TypeTree`
2. completes descriptor squares above it
3. completes descriptor squares below it through immediate subtypes and descriptor subtypes

This is the recursive piece that makes descriptor retention surprisingly sticky in some test cases.

## `completeDescriptorSquare(...)`

This helper is the core rule:

- if three of the four relevant corners of a subtype/descriptor square are present
- and the missing corner is not the one optional missing super-descriptor case
- then add all four edges conservatively

That is the correct mental model for why a required `ref.get_desc` on one type can indirectly keep subtype and descriptor edges alive on related types.

## Cast propagation details

`processCasts(...)` handles both:

- attaching one previously separate subtree under a supertype in another tree
- reparenting a type inside the same tree

It then walks:

- every type in the affected `sub` subtree
- against every newly relevant supertype
- against every cast destination recorded for those supertypes

If the original Binaryen type graph says the concrete type is a subtype of the cast destination, the pass keeps that relation.

This fixed-point loop is why casts can produce chains of required relations across several layers rather than only one immediate target edge.
The later chain examples in `unsubtyping-casts.wast` are directly about this iterative behavior.

## Rewriting phase and allocation fixups

Once the fixed point is done, the pass performs two different kinds of rewriting.

## 1. Drop removed descriptor operands from allocations

`fixupAllocations(...)` walks functions and module code looking for `struct.new_desc` where the described type no longer keeps a descriptor relation.

If the descriptor relation is gone:

- inside a function:
  - if nullable descriptors can still trap and traps matter, wrap the descriptor in `ref.as_non_null`
  - use `ChildLocalizer` so any necessary evaluation order is preserved before dropping the descriptor operand
  - then clear `curr->desc`
- outside a function:
  - just clear the descriptor operand
  - but if the removed descriptor initializer was a nested `StructNew` with a guaranteed trap effect, record it so a fresh global can preserve the instantiation-time trap

At the end the pass emits fresh globals named like:

- `unsubtyping-removed-0`

for those removed trapping initializers.

This is one of the most important details to preserve in a future port.
The pass is not allowed to make a nullable descriptor trap disappear just because it also made the descriptor relation unnecessary.

## 2. Rewrite declared supertype and descriptor edges

`rewriteTypes(...)` uses a small `GlobalTypeRewriter` subclass that overrides:

- `getDeclaredSuperType(...)`
- `modifyTypeBuilderEntry(...)`

The rewriter keeps only:

- the remaining non-basic declared supertype from `TypeTree`
- the remaining `describes` / `descriptor` edges from `TypeTree`

and removes the rest.

Then shared type-updating machinery rewrites the private type graph and all remaining uses consistently.

### Important boundary: public types stay public and unmodified

`GlobalTypeRewriter` only rebuilds private types.
So `unsubtyping` is not allowed to silently mutate module-boundary ABI types even in closed world.

## Final repair step

After rewriting types, `unsubtyping` always runs:

- `ReFinalize()`

The pass comment explains why:

- cast types may be refinable if source and target types are no longer related

Practically, this is why some odd test outputs involving unreachable `call_ref`, `cont.bind`, or `resume` shapes end up as side-effect-preserving `block` wrappers after the type graph changes.
Not every visible output oddity in the tests is handwritten in `Unsubtyping.cpp`; some belong to shared finalize and type-repair logic after the relation graph is minimized.

## What the pass does **not** do

Binaryen `unsubtyping` in `version_129` does **not** do any of these:

- it does not run in open world
- it does not refine field contents or function signatures directly the way earlier cluster passes do
- it does not optimize public heap types
- it does not do generic structural type merging
- it does not use a precise per-cast dataflow analysis of actual value sets; it uses a conservative fixed point over validation constraints and known remaining subtypes
- it does not by itself promise the smallest possible final type section, because many official tests pair it with `remove-unused-types` to erase newly dead heap types immediately afterward

Those boundaries are just as important as the positive rewrites.

## Official test map and durable takeaways

## `unsubtyping.wast`

This is the broad validation-surface file.
It proves all of these at once:

- dead purely-declarative supertype chains can collapse to smaller trees
- public types do not change
- function results, global initializers, active element segments, and table initializers directly require subtype edges
- type-definition implications propagate through structs, arrays, and function types
- block, `br`, `if`, loop, `br_table`, call, local/global/table set, `select`, try/catch, tag payload, return, multivalue return, and `call_ref` families all contribute validation constraints
- stack-sensitive shapes like unreachable `call_ref` must not crash the pass even when later finalize produces wrapper blocks

## `unsubtyping-casts.wast`

This is the cast-behavior file.
It proves:

- an isolated downcast does not by itself keep a relation if no relevant concrete subtype can flow in
- once a concrete subtype is shown to flow into the cast source, the cast may keep intermediate edges alive
- `ref.test`, `br_on_cast`, and `br_on_cast_fail` use the same cast-preservation logic
- exact casts are narrower and do not require preserving destination-subtype families
- guaranteed-success upcasts keep the direct relation they depend on
- guaranteed-fail casts should not introduce new subtype edges
- `ref.eq` non-flow constraints should not block optimization of unrelated user-type edges
- some examples require several fixed-point rounds before the full relation chain is discovered

## `unsubtyping-cmpxchg.wast`

This tiny file exists for a real reason.
It proves that cmpxchg expected-value typing must still respect:

- `eqref` for unshared ref fields/elements
- `(ref null (shared eq))` for shared ref fields/elements

So the pass's shared type-rewrite / refinalize story must keep those shareability-sensitive expected-value types valid.

## `unsubtyping-desc.wast`

This is the hardest file.
It proves:

- descriptor relations can be removed independently of ordinary subtype edges
- some cases keep a type relation but not its descriptor-supertype relation
- some cases keep descriptor relations because `ref.get_desc` or `ref.cast_desc_eq` can observe them
- module-level nullable descriptor allocations can force descriptor retention for trap preservation
- function-level nullable descriptor traps can instead be preserved by rewriting the allocation site
- descriptor squares can require both structural and descriptor edges to remain together

## `unsubtyping-desc-tnh.wast`

This file teaches the `trapsNeverHappen` boundary clearly:

- if we assume traps never happen, nullable-descriptor trap-preservation no longer blocks descriptor removal
- function-local `ref.as_non_null` fixups disappear in those cases
- module-level nested allocation helpers are not needed when the only reason to keep them was a never-happening trap

## `unsubtyping-jsinterop.wast`

This file proves the JS boundary model is real.
It covers:

- descriptor prototype keepalive when types flow out to JS
- descriptors that cannot hold a prototype being removable even when types cross the JS boundary
- implicit `any` boundary casts keeping subtype edges alive
- `extern.convert_any` as a direct JS-exposure source
- subtypes exposed through an inexact exported supertype keeping descriptor relations alive too

## `unsubtyping-stack-switching.wast`

This file proves the pass is not just about classic struct and function calls.
It covers:

- `cont.new`
- `cont.bind` operand, parameter, and result constraints
- `suspend`
- `resume`
- unreachable or null continuation special cases that still must not crash after type rewriting

A future port that ignores stack-switching and continuation shapes would be incomplete.

## Durable beginner-facing conclusions for the living wiki

The new living dossier should preserve at least these conclusions:

- `unsubtyping` is a **late closed-world GC/type-cluster relation minimizer**, not a first-pass type refiner.
- It computes the minimal remaining relation by fixed point over **validation constraints**, **type definitions**, **casts**, and **descriptor squares**.
- It owns descriptor optimization because descriptors and subtype edges recursively force one another.
- JS boundary flow matters twice:
  - as implicit cast pressure through `any`
  - as descriptor keepalive pressure for possible JS prototypes
- Exact casts are a special smaller case and should be taught separately from ordinary casts.
- Many official visible shrink wins are shown under the harness pairing:
  - `--unsubtyping --remove-unused-types`
  so the living docs must not incorrectly attribute every disappeared type definition to `unsubtyping` alone.
- Allocation fixups plus final refinalization are part of the pass contract, not implementation noise.

## What a future Starshine port must preserve

A future Starshine `unsubtyping` port would need to preserve all of this:

- boundary-only **module-pass** scheduling rather than HOT-only local rewriting
- a hard GC + `--closed-world` gate
- public-type freezing via the module boundary helper story
- validation-constraint discovery across the broad expression surface, including stack-switching forms
- the distinction between flow constraints and non-flow basic-type constraints (`ref.eq`-style)
- exact-cast versus ordinary-cast behavior
- descriptor-square completion logic
- JS prototype-field keepalive rules through both exports/imports and `extern.convert_any`
- descriptor-allocation fixups with trap preservation and `trapsNeverHappen` differences
- private-type rewriting through a shared type-rebuild path
- post-rewrite refinalization

Anything less would likely preserve validation but not Binaryen's source-backed cast or descriptor behavior.

## Open questions and uncertainty

I do **not** see evidence in the reviewed sources that `unsubtyping` tries to compute the mathematically smallest possible relation under an exact whole-program dataflow model.
The file comment is explicit that this is the minimal relation it can find **without a more precise analysis of types that might flow into each cast**.

So the safe wording for the living docs is:

- Binaryen computes a conservative minimal relation under its chosen fixed-point analysis
- not an omniscient whole-program optimum

That distinction matters if future Starshine work ever considers a stronger cast-flow oracle.

## Recommended living-page split

The living dossier should be split so that readers can approach the pass in layers:

- landing page:
  - what the pass really is, why it matters, and the biggest beginner corrections
- `binaryen-strategy.md`:
  - fixed-point algorithm, scheduler placement, helper dependencies, and porting contract
- `implementation-structure-and-tests.md`:
  - file map, helper map, combo-harness caveat, and what each official lit file proves
- focused page on descriptors/casts/JS boundaries:
  - because that is the hardest conceptual cluster and easiest thing to misread from the pass name
- `wat-shapes.md`:
  - beginner-friendly positive, negative, bailout, and interaction shapes

## Files to update in this change

- add `docs/wiki/raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`
- add `docs/wiki/binaryen/passes/unsubtyping/index.md`
- add `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
- add `docs/wiki/binaryen/passes/unsubtyping/implementation-structure-and-tests.md`
- add `docs/wiki/binaryen/passes/unsubtyping/descriptor-squares-casts-and-js-boundaries.md`
- add `docs/wiki/binaryen/passes/unsubtyping/wat-shapes.md`
- update `docs/wiki/binaryen/passes/index.md`
- update `docs/wiki/binaryen/passes/tracker.md`
- update `docs/wiki/index.md`
- update `docs/wiki/log.md`

## Bottom line

Binaryen `unsubtyping` is really:

- **closed-world subtype/descriptor graph minimization with validation constraints, cast-success preservation, JS-boundary descriptor keepalive, descriptor-allocation trap fixups, and final shared type repair**

That is far more precise than the simple phrase “remove unnecessary subtyping relationships,” and it is the contract the new living wiki pages should preserve.
