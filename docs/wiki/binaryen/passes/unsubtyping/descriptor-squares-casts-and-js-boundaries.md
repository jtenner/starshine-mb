---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `unsubtyping`: descriptor squares, casts, and JS boundaries

This page exists because the hardest part of `unsubtyping` is **not** “remove a declaration edge.”
It is the interaction between:

- ordinary and exact casts
- descriptor/described relations
- JS exposure through `any` and `extern.convert_any`
- allocation fixups that preserve traps when descriptor edges disappear

The source provenance for these claims is now captured in [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md), and the Starshine-specific port boundary is summarized in [`./starshine-strategy.md`](./starshine-strategy.md).

If you understand this page, you understand the real pass much better.

## The one mental model to keep

Binaryen is trying to keep the **smallest relation graph that is still observable**.

Observable here means more than just declaration validity.
The pass must preserve all of these:

1. wasm validation constraints
2. cast success or failure behavior
3. descriptor relationships that `ref.get_desc` or descriptor-aware casts can observe
4. JS prototype behavior for exposed descriptors
5. nullable-descriptor traps that would still happen at runtime or instantiation time

That is why this pass is much more than a type-section cleanup.

## Why descriptors live in this pass at all

The source comment in `Unsubtyping.cpp` explains the key square:

- `A -> A.desc`
- `B -> B.desc`
- `B <: A`
- `B.desc <: A.desc`

If enough of that square exists, the validation rules can force the rest.

That means subtype edges and descriptor edges are **not independent**.
They recursively imply one another.

This is why `unsubtyping` owns descriptor optimization directly instead of leaving it to `gto` or some other pass.
`gto` is about private struct field layout.
`unsubtyping` is about the **relation graph itself**.

## The descriptor-square rule in plain English

If Binaryen knows three of these four things:

- subtype edge between the described types
- subtype edge between the descriptor types
- described -> descriptor on the super pair
- described -> descriptor on the sub pair

then it may need to keep the fourth thing too.

`completeDescriptorSquare(...)` is the helper that keeps enforcing that until the graph stops changing.

### What this means for a beginner

You cannot safely think:

- “I only need `B <: A`, so the descriptor edges are separate”

or:

- “I only need `B.desc <: A.desc`, so the described-type relation is separate”

Both are wrong often enough to matter.

## Ordinary casts versus exact casts

`Noter::noteCast(...)` is one of the most important functions in the pass.

## Ordinary casts

For an ordinary downcast like:

- cast source `src`
- cast destination `dst`
- where `dst <: src` originally

Binaryen does **not** immediately keep `dst <: src` and all related declaration edges.
Instead it stores the cast pair and waits.

Later, when some concrete type `v` is known to remain a subtype of `src`, the pass asks:

- did `v <: dst` originally?

If yes, then that success case was observable before, so it must remain observable now.
That is when the pass keeps the required subtype relation.

### Why this matters

A cast can be completely harmless if nothing concrete can flow into it that would have succeeded.
That is why some cast-only examples in `unsubtyping-casts.wast` optimize much more aggressively than beginners expect.

## Exact casts

Exact casts are narrower.

If the destination is exact, the pass only needs to preserve:

- the exact destination type as a subtype of the source

Subtypes of the destination do **not** matter for the success condition of an exact cast.

This is a major source-backed correction.
It is not optional nuance.
The official cast test file has dedicated exact-cast coverage because this difference changes which declaration edges survive.

## Guaranteed-success versus guaranteed-fail casts

The pass also distinguishes two easy edge cases.

### Guaranteed success

If `src <: dst` already, the cast is effectively an upcast.
To keep that guaranteed success, the pass preserves:

- `src <: dst`

### Guaranteed failure

If source and destination are incompatible in the original graph, the cast proves nothing useful.
The pass should not invent new subtype edges just because the cast exists.

This is another place beginners often over-preserve relations.

## Non-flow constraints are deliberately weaker than flow constraints

`ref.eq` is the clearest example.
It requires both operands to validate as subtypes of `eqref`, but those values do not flow onward to another user-defined location.

So `Collector::noteNonFlowSubtype(...)` ignores basic-type non-flow constraints when deciding what user-defined subtype edges need to survive.

That means:

- `ref.eq` can matter for validation
- but it should not block unrelated user-type unsubtyping the way a real flow into a local, block result, call param, or cast source would

The official cast test file has a focused comment explaining exactly this.

## JS boundary flow matters twice

`analyzeJSInterface(...)` uses `JSUtils::iterJSInterface(...)`, which models JS boundary flow in both directions.

## Flow in from JS: implicit cast from `any`

For boundary inputs coming from JS, Binaryen treats the situation like a cast from:

- `any` -> expected wasm type

So JS inputs can make cast-success behavior observable even when the ordinary wasm body alone would not.

This is why exported functions, imported functions, JS-called functions, imported globals, and tables can keep subtype edges alive in ways that are not obvious from local function bodies.

## Flow out to JS: implicit flow into `any`

For boundary outputs sent to JS, the pass treats the type as flowing into:

- `any`

That can keep subtype edges alive too, because a value that flows out and later comes back in through a cast-from-`any` path must still behave compatibly.

## JS prototype keepalive is descriptor-specific

When a type flows out to JS, `noteExposedToJS(...)` may also keep its descriptor alive.
But only if:

- the type has a descriptor
- descriptor field `0` exists
- field `0` is immutable
- field `0` is a subtype of `externref`

That is the precise `hasPossibleJSPrototypeField(...)` rule.

So JS exposure does **not** keep arbitrary descriptors alive.
It only keeps descriptors that might still configure a JS-visible prototype.

### Exact versus inexact exposure

If the exposed type is inexact, Binaryen marks the type so that later-discovered subtypes may also count as exposed.
That is why an exported or JS-called supertype can force descriptor retention on a subtype in some of the official JS-interop examples.

Exact exposure does not imply the same subtype propagation.

## `extern.convert_any` is another JS keepalive path

`extern.convert_any` is not just another ref op here.
The collector treats it as making the operand type visible to JS.

So even without exports/imports or `@binaryen.js.called`, a purely internal use of:

- `extern.convert_any`

can keep a descriptor relation alive if that descriptor could configure a JS prototype.

That is another easy point to miss if you only read the pass name.

## Why `struct.new_desc` usually does **not** keep descriptors

This is one of the best scope corrections in the entire pass.

Normally, a `struct.new_desc` allocation does **not** mean Binaryen must keep the described/descriptor relation forever.
If the descriptor is only allocated and never observed, `unsubtyping` is happy to remove the relation.

That is why there must be a separate allocation-fixup phase later.
The pass expects some descriptor-bearing allocations to survive after the descriptor relation itself is gone.

## Trap preservation when descriptor edges disappear

Descriptor relations can disappear while the old code still contains descriptor-bearing allocations.
That is where `fixupAllocations(...)` comes in.

## Function-local nullable descriptors

Inside functions, when a removed descriptor operand could still trap on null and traps matter, Binaryen:

- wraps it in `ref.as_non_null`
- uses `ChildLocalizer` to preserve evaluation order
- then drops the descriptor operand from `struct.new_desc`

So the **trap** survives even though the **descriptor relation** is gone.

That is why some function-local descriptor examples grow extra block/local scaffolding in the official tests.

## Module-level nullable descriptors

Outside functions, Binaryen cannot use locals.
So if a removed descriptor initializer still contains a guaranteed trap, the pass saves it and emits a fresh global named like:

- `unsubtyping-removed-0`

This preserves the instantiation-time trap even though the descriptor-bearing allocation site no longer needs the descriptor relation.

## `trapsNeverHappen` changes the rule

If `trapsNeverHappen` is enabled, many of those preservation steps disappear.
The dedicated `unsubtyping-desc-tnh.wast` file exists precisely to prove that.

So trap-preservation is not just implementation detail here.
It is a real mode-dependent semantic boundary.

## The three easiest wrong mental models

### Wrong model 1: “A cast means keep the declaration edge.”

No.
An ordinary cast only keeps relations that matter for concrete flowing inhabitants, and exact casts are smaller still.

### Wrong model 2: “Descriptors are just metadata.”

No.
Descriptors participate in validation through squares with subtype edges, and some of them are observable through `ref.get_desc`, descriptor-aware casts, or JS prototypes.

### Wrong model 3: “If the descriptor edge disappears, the descriptor allocation can just vanish.”

No.
Potential traps and evaluation order may still need explicit preservation.

## What a future Starshine port must preserve here specifically

The hardest concept cluster a future port must get right is:

- ordinary-vs-exact cast distinction
- non-flow basic-type constraint weakening
- descriptor-square completion
- JS `any`-boundary flow rules
- JS prototype-field keepalive rules
- allocation fixups for removed descriptor edges
- `trapsNeverHappen` differences

A port that gets only declaration reparenting right but misses this cluster will not match Binaryen's real behavior.

## Bottom line

The real secret of `unsubtyping` is:

- **the pass minimizes a relation graph that is still observable through casts, descriptors, JS boundaries, and traps**

Once that clicks, the strange-looking descriptor and cast tests make much more sense.

## Sources

- [`../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`](../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtype-exprs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
