---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `unsubtyping` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/Unsubtyping.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `SubtypingDiscoverer` in `src/ir/subtype-exprs.h`
- `JSUtils::iterJSInterface(...)`
- `JSUtils::hasPossibleJSPrototypeField(...)`
- `ModuleUtils::getPublicHeapTypes(...)`
- `ModuleUtils::ParallelFunctionAnalysis`
- `GlobalTypeRewriter`
- `ChildLocalizer`
- `EffectAnalyzer`
- `HeapType::isSubType(...)`
- `HeapType::getDescriptorType()` / `getDescribedType()`

The shipped lit surface is also part of the contract:

- `test/lit/passes/unsubtyping.wast`
- `test/lit/passes/unsubtyping-casts.wast`
- `test/lit/passes/unsubtyping-cmpxchg.wast`
- `test/lit/passes/unsubtyping-desc.wast`
- `test/lit/passes/unsubtyping-desc-tnh.wast`
- `test/lit/passes/unsubtyping-jsinterop.wast`
- `test/lit/passes/unsubtyping-stack-switching.wast`

## High-level intent

Binaryen uses `unsubtyping` to compute the **minimal remaining subtype and descriptor graph** needed by the already-optimized closed-world module.

That sounds abstract, but the real contract is concrete.
The pass only stays correct because it preserves all of these at once:

1. only GC-enabled modules are eligible
2. only closed-world runs are eligible
3. public types remain frozen
4. initial requirements come from validation, descriptors, JS boundaries, and public edges
5. ordinary casts keep relations only when actual flowing inhabitants make cast success observable
6. exact casts are handled as a smaller special case
7. descriptor edges recursively imply subtype edges and vice versa through descriptor squares
8. descriptor-bearing allocations are fixed up before types are rewritten
9. private type declarations are rebuilt to match the minimized graph
10. final refinalization repairs the surrounding IR after the type graph changes

That is why this is a module pass even though much of the visible evidence comes from local WAT shapes.

## Where the pass runs

In `pass.cpp`, Binaryen registers the pass under the CLI name:

- `unsubtyping`

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, `unsubtyping` is **absent**.

The open-world path still ends its GC prepass cluster at:

- `... -> global-refining -> remove-unused-module-elements -> gsi`

So the repo's main no-DWARF orientation page should continue to omit `unsubtyping`.

### Closed-world Binaryen path

When Binaryen runs in closed world, the neighborhood grows:

- before `unsubtyping`:
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
- then:
  - `unsubtyping`

That means `unsubtyping` is the **late relation-pruning step in the closed-world GC/type cluster**, not an early type-inference pass.

## Phase 0: hard GC + closed-world gates

`Unsubtyping::run(Module* wasm)` begins by returning immediately when:

- `!wasm->features.hasGC()`

and then throws a fatal error when:

- `!getPassOptions().closedWorld`

This is one of the most important differences from some neighboring closed-world passes.
`unsubtyping` does not merely *tend* to run in closed world.
The pass body itself insists on it.

## Phase 1: seed the worklist with directly required relations

The pass has a worklist of required edges:

- `Kind::Subtype`
- `Kind::Descriptor`

and a `TypeTree` that stores the minimized graph discovered so far.

The first half of the algorithm is finding the **initial** edges that must survive even before fixed-point propagation begins.

### 1A. Public types

`analyzePublicTypes(...)` uses `ModuleUtils::getPublicHeapTypes(...)`.

For every public type, it preserves:

- the declared supertype edge, if any
- the descriptor edge, if any

This is the first reason the pass only really rewrites private types.

### 1B. JS interface

`analyzeJSInterface(...)` uses `JSUtils::iterJSInterface(...)`.

That helper treats the JS boundary as two flows:

- values flowing **in** from JS are like implicit casts from `any`
- values flowing **out** to JS are like flowing into `any`

The pass therefore does two different things.

#### Flow in from JS

For a ref type flowing in from JS, the pass notes:

- `noteCast(HeapType::any, type)`

So imported or JS-called boundary inputs can make casts-from-`any` observable even if the ordinary wasm body alone would not.

#### Flow out to JS

For a ref type flowing out to JS, the pass notes:

- `type <: any`
- and maybe `noteExposedToJS(type)`

`noteExposedToJS(...)` keeps descriptors only when they can configure a JS prototype:

- the type has a descriptor
- descriptor field `0` exists
- field `0` is immutable
- field `0` is a subtype of `externref`

That is deliberately narrow.
JS boundary flow does **not** keep arbitrary descriptors alive.

#### Inexact exposure matters more than exact exposure

If the exposed type is inexact, `noteExposedToJS(...)` marks:

- `subtypesExposedToJS = true`

in the `TypeTree`.

That means when a later subtype edge is discovered, JS exposure can propagate downward to subtypes too.
Exact exposure does not imply the same subtype propagation.

### 1C. IR validation and descriptor analysis

`analyzeModule(...)` is the broadest initial-analysis phase.
It uses:

- `ControlFlowWalker`
- `SubtypingDiscoverer`
- `Noter`

inside a `Collector` that runs:

- in parallel over functions
- over module code
- and directly over globals, tables, and element segments

The collected info includes:

- observed subtype constraints
- observed casts
- observed descriptor requirements
- observed `extern.convert_any` exposures to JS

## Phase 2: discover validation constraints with `SubtypingDiscoverer`

Most of the initial subtype requirements are not handwritten in `Unsubtyping.cpp`.
They come from the shared `SubtypingDiscoverer` helper in `subtype-exprs.h`.

That helper records subtype constraints for a surprisingly broad surface, including:

- function body result -> declared result
- global init -> declared global type
- table init / segment type -> table type
- block/if/loop value flow
- branch values (`br`, `br_if`, `br_table`)
- direct calls and indirect calls
- local/global/table sets and fills
- `select`
- returns and multivalue returns
- try/catch value flow
- tag payloads and throws
- `call_ref`
- `struct.new`, `struct.set`, atomic struct ops
- `array.new*`, `array.set`, array copy/fill/atomic ops
- continuation instructions like `cont.new`, `cont.bind`, `suspend`, and resume handlers

This is one of the biggest beginner corrections in the whole pass.
The pass is not just scanning declaration uses.
It is scanning **validation surfaces across the IR**.

### Non-flow subtype constraints are deliberately weakened

The collector overrides `noteNonFlowSubtype(...)` for special cases like `ref.eq`.

If the required supertype is a **basic** ref type, such as `eqref`, the pass ignores that constraint for user-type unsubtyping purposes.
The reason is:

- the value must validate against the basic type
- but the value does not flow anywhere new
- and the pass only removes user-defined subtype edges, not basic-type relationships

That is why `ref.eq` does not block the same optimizations that a real value-flowing use would.

## Phase 3: descriptor-specific initial constraints

The collector adds several descriptor rules that the generic subtype walker does not know.

### `ref.get_desc`

`visitRefGetDesc(...)` preserves the described/descriptor relation of the operand type.

### Explicit descriptor operands on cast-like ops

`visitRefCast(...)` and `visitBrOn(...)` note descriptor requirements when those instructions carry an explicit descriptor operand of struct type.

### `struct.new_desc`

This is subtle.

Ordinarily, `struct.new_desc` does **not** force the described type to keep its descriptor relation.
Binaryen is happy to remove descriptors that are only allocated and then never observed.

The one source-backed exception is:

- module-level nullable descriptor allocations when traps matter

If a nullable descriptor could trap during instantiation and we are outside a function context, the pass must keep enough information to preserve that trap later.

### `extern.convert_any`

`visitRefAs(...)` treats:

- `ExternConvertAny`

as exposing the operand type to JS.

This is the other big non-obvious JS-keepalive path besides exports/imports/`@binaryen.js.called` boundaries.

## Phase 4: ordinary casts are stored, not solved immediately

The `Noter` CRTP helper contains the central cast rule in `noteCast(...)`.

### Ordinary casts to inexact destinations

If the destination type is a subtype of the source type and the cast is inexact, the pass records:

- `(src, dst)`

in `casts`

for later fixed-point processing.

It does **not** immediately note `dst <: src` or every intermediate relation.

### Exact casts

If the destination is exact, the pass only notes:

- `dst <: src`

That is a much smaller requirement surface.

### Guaranteed upcasts

If the source is already a subtype of the destination, the pass keeps:

- `src <: dst`

because otherwise the cast would stop being a guaranteed success.

### Guaranteed failures are ignored

If the cast is incompatible in the original graph, the pass records nothing.
It should not invent subtype edges just because a cast exists.

## Phase 5: fixed point over a mutable minimized forest

After initial analysis, the pass repeatedly pops subtype or descriptor edges from `work` and grows the minimal graph in `TypeTree` until no new requirements appear.

## `TypeTree`

`TypeTree` is not a passive snapshot.
It is a mutable forest that supports:

- constant-time parent changes
- efficient subtype and supertype iteration
- optional described / descriptor links
- a `subtypesExposedToJS` mark

That representation is the key reason the pass can repeatedly refine which supertype a type actually needs.

## `processSubtype(sub, super)`

When a subtype edge is required, the pass:

1. checks whether `sub` already has a recorded supertype
2. compares the old and new supertype if so
3. can recurse to relate those supertypes first
4. reparents `sub` under the more specific required supertype
5. propagates JS exposure from the new supertype to the subtree if needed
6. completes descriptor squares around the new edge
7. infers new subtype constraints from the type definitions
8. evaluates the impact on recorded casts

### Why reparenting matters

A type may first be known to need a shallow supertype and later a more specific one.
The pass tries to keep the **minimal** surviving forest, so it reparents rather than blindly accumulating all old declaration edges.

## `processDefinitions(sub, super)`

A kept declared subtype edge can imply more subtype edges through the definitions.
Binaryen handles all heap-type kinds it supports here:

- `func`:
  - params are contravariant
  - results are covariant
- `struct`:
  - each inherited field type of the subtype must stay a subtype of the corresponding super field type
- `array`:
  - element type must stay compatible
- `cont`:
  - continuation signature type must stay compatible

So declaration-level unsubtyping is never just about the outer heap types.

## `processCasts(sub, super, oldSuper)`

This is where ordinary casts become real subtype requirements.

The pass walks:

- every type in the affected `sub` subtree
- against every newly relevant supertype
- against every stored cast destination of those supertypes

If a concrete type would have satisfied the cast before, it keeps the corresponding subtype relation now.

This is the source-backed reason cast constraints can propagate in several rounds instead of all at once.
The later chain examples in `unsubtyping-casts.wast` are about exactly this fixed-point behavior.

## `processDescriptor(described, descriptor)`

Descriptor processing records the edge and then completes descriptor squares:

- above the edge
- below the edge through subtype and descriptor-subtype relations

Descriptors are therefore recursive constraints, not inert metadata.

## `completeDescriptorSquare(...)`

This helper encodes the central square rule.

If enough of this pattern exists:

- `sub <: super`
- `sub -> subDesc`
- `super -> superDesc`
- `subDesc <: superDesc`

then the missing pieces are inferred and added conservatively.

The only type allowed to be absent is the optional missing `superDesc` case.

This is the main reason descriptor removal and subtype removal cannot be explained separately.

## Phase 6: fix allocation sites before rewriting types

Once the minimized relation is known, the pass calls:

- `fixupAllocations(...)`

before rewriting type declarations.

### Function-local dropped descriptor operands

When a `struct.new_desc` no longer needs its descriptor edge and we are in a function:

- if nullable descriptors can still trap and traps matter, wrap the descriptor in `ref.as_non_null`
- use `ChildLocalizer` to preserve any required evaluation order
- clear `curr->desc`

That is why function-local nullable descriptor examples grow `block` and local scaffolding in the tests.

### Module-level dropped descriptor operands

When outside a function, the pass cannot use locals.
So it clears the descriptor operand directly.

If the removed descriptor initializer is itself a `StructNew` with a guaranteed trap effect, it records it and later emits a fresh immutable global named like:

- `unsubtyping-removed-0`

so the instantiation-time trap is still preserved.

### `trapsNeverHappen` changes this story

If `trapsNeverHappen` is enabled, many of those fixups disappear.
The dedicated `unsubtyping-desc-tnh.wast` file exists to make that boundary explicit.

## Phase 7: rewrite private declared supertypes and descriptor links

`rewriteTypes(...)` uses a tiny `GlobalTypeRewriter` subclass.

It overrides:

- `getDeclaredSuperType(...)`
  - keep the new non-basic supertype from `TypeTree`, or none
- `modifyTypeBuilderEntry(...)`
  - remove `describes` when the type no longer describes anything
  - remove `descriptor` when the type no longer has one

Then shared `GlobalTypeRewriter` infrastructure rebuilds the private type graph and updates remaining type uses consistently.

### Public/private boundary is still real here

`GlobalTypeRewriter` only rebuilds private types.
So even in closed world, `unsubtyping` is not allowed to silently mutate public type declarations.

## Phase 8: final refinalization

After rewriting types, the pass runs:

- `ReFinalize()`

The pass comment is explicit:

- cast types may be refinable if their source and target types are no longer related

This is also why some continuation and `call_ref` oddities in the official tests end up as side-effect-preserving unreachable wrappers rather than handwritten pass-local rewrites.
The changed type graph can force shared finalization logic to legalize or sharpen those instructions.

## What the pass does **not** do

Binaryen `unsubtyping` in `version_129` does **not** do any of these:

- it does not run in open world
- it does not refine field payload types or signature bodies the way earlier cluster passes do
- it does not optimize public types
- it does not do generic structural type merging
- it does not use a perfect whole-program cast-flow oracle; the file comment is explicit that the result is minimal only under this conservative fixed-point analysis
- it does not by itself guarantee that all newly dead heap types disappear from the printed module, because the official test harness often pairs it with `remove-unused-types`

Those boundaries are just as important as the positive rewrites.

## What the pass sounds like versus what it actually is

What it sounds like:

- a declaration cleanup pass that deletes some subtype arrows

What it actually is in `version_129`:

- a closed-world subtype/descriptor minimization pass with validation-driven seeding, cast-driven fixed-point propagation, descriptor-square completion, JS-boundary keepalive rules, allocation trap preservation, private-type rewriting, and final shared type repair.

That is the behavior a future Starshine port would need to preserve.

## Bottom line

Binaryen `unsubtyping` is really:

- **minimal subtype + descriptor graph computation under validation, cast, descriptor, and JS-boundary constraints**

The public one-line summary in `pass.cpp` hides that entire story.

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
