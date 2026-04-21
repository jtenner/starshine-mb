---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0185-2026-04-21-untee-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./wat-shapes.md
---

# Binaryen strategy for `untee`

## What the pass really is

The reviewed implementation is a **tiny tee-desugaring pass**.
It does not do broad locals reasoning, and it does not try to prove a program smaller, faster, or flatter in every context.

The actual strategy is:

- walk `LocalSet` nodes after children have already been visited
- ignore anything that is not a tee
- if a tee's value is `unreachable`, delete the tee shell
- otherwise rewrite the tee into an ordinary set plus a synthetic get of the same local

So the best mental model is:

- **replace `local.tee` sugar with explicit `local.set` then `local.get` IR**
- not "run `simplify-locals` without tees"
- not "flatten the whole function"
- not "do locals optimization in general"

## Public surface and scheduler meaning

`src/passes/pass.cpp` registers the public pass name:

- `untee`

with the description:

- `removes local.tees, replacing them with sets and gets`

That summary is accurate.

Important scheduler fact:

- `untee` is **not** part of the reviewed `version_129` no-DWARF `-O` / `-Os` default optimize path used by this repo's canonical parity page

So a future Starshine implementation should treat `untee` as an explicit optional pass unless there is a separate source-backed decision to schedule it elsewhere.

## Core structure

The pass type is:

- `WalkerPass<PostWalker<Untee>>`

And it overrides:

- `bool isFunctionParallel() override { return true; }`

Those two details already explain most of the contract:

- **postwalk** means nested tees are handled from the inside out
- **function-parallel** means there is no cross-function/module analysis or shared state

## Core rewrite function

The only real visitor is:

- `visitLocalSet(LocalSet* curr)`

That is also a teaching point.
The pass does not inspect arbitrary expressions or search for abstract patterns.
It only acts when the current node itself is a `local.tee`.

## Main algorithmic phases

## Phase 1: reject ordinary sets

The first check is simply:

- `if (curr->isTee())`

Ordinary `local.set` is left alone.

This means a future port must preserve a very narrow scope:

- the pass is about explicit tee removal
- not about rewriting all local traffic

## Phase 2: special-case unreachable tees

If the tee's child value has type `unreachable`, Binaryen does:

- `replaceCurrent(curr->value)`

That is the only true bailout/special case in the implementation, but it matters a lot.

Why:

- the tee write does not happen on an unreachable path
- a synthetic trailing `local.get` would be meaningless
- this keeps the rewritten tree simple and valid

The dedicated lit file checks this exact family.

## Phase 3: construct the synthetic get

For a reachable tee, Binaryen creates:

- `builder.makeLocalGet(curr->index, getFunction()->getLocalType(curr->index))`

This is subtle in a good way.
The pass uses the **declared local type**, not the current child expression type.
That preserves the actual meaning of `local.tee`.

## Phase 4: wrap the current node in a sequence

Still in the reachable case, Binaryen does:

- `replaceCurrent(builder.makeSequence(curr, get))`

Conceptually this means:

1. perform the write
2. then read the local back as the expression result

In printed WAT, the sequence is typically rendered as a `block (result T)` with:

- a `local.set`
- then a `local.get`

## Phase 5: mutate the original node from tee to set

Immediately after building the wrapper, Binaryen calls:

- `curr->makeSet()`

That ordering is important.
The sequence was built around the original node pointer, and only then does the original node lose its tee flag.
So the wrapper ends up containing the same underlying write node, now spelled as a plain set.

That is why the pass is so small: it reuses the original node rather than rebuilding the whole subtree.

## Why postorder matters

Because the pass is a `PostWalker`, nested tees are already rewritten by the time an outer tee is processed.

Example idea:

```wat
(local.set $x (local.tee $x (local.tee $x (i32.const 3))))
```

The inner tee becomes:

- `block(result i32) -> local.set + local.get`

Then the outer tee expands around that result.
The lit file checks this nested expansion explicitly.

## Important positive shapes

## Dropped tee

Conceptual rewrite:

```wat
(drop (local.tee $x (i32.const 1)))
```

becomes

```wat
(drop
  (block (result i32)
    (local.set $x (i32.const 1))
    (local.get $x)))
```

## Tee feeding another set

Conceptual rewrite:

```wat
(local.set $x (local.tee $x (i32.const 3)))
```

becomes

```wat
(local.set $x
  (block (result i32)
    (local.set $x (i32.const 3))
    (local.get $x)))
```

## Nested tee chain

The nested chain expands inside-out, producing nested result blocks.
That visible nesting is part of the real contract, not a random printer artifact.

## Important negative shape

## Unreachable tee

Conceptual rewrite:

```wat
(drop (local.tee $x (unreachable)))
```

becomes

```wat
(drop (unreachable))
```

This is the pass's clearest correctness-preserving non-expansion rule.

## What the pass deliberately does not do

The reviewed source does **not**:

- create or remove ordinary `local.set`
- analyze local liveness
- fold redundant set/get pairs afterwards
- run a nested cleanup pass
- reason about CFG, dominance, effects, or use-def chains
- enforce Flat IR like `flatten` does
- behave like a `simplify-locals` family variant

That absence is a big part of the real contract.
`untee` is intentionally tiny.

## Pass interactions that matter

## `code-pushing`

The top comment in `Untee.cpp` says removing tees makes code "flatter" and can make passes like `CodePushing` more effective.

That does **not** mean `untee` enforces the formal Flat IR contract.
It means something simpler and more local:

- tee combines a side effect and a value result in one node
- untee spells those operations out explicitly
- later movement or segment-selection logic can reason about the write and read separately

## `simplify-locals-notee`

This distinction is easy to lose, so it should be stated bluntly.

- `untee` removes existing tees by desugaring them
- `simplify-locals-notee` is a broader optimizer that still sinks single-use values, still forms structured block/if/loop results, and still performs late equivalent-copy cleanup; it merely refuses transformations that would need to create a new tee

So `untee` is not a public alias for `simplify-locals-notee`.
It is a separate pass with a smaller, more literal contract.

## `simplify-locals-nonesting`

Inference from nearby official sources:

- `simplify-locals-nonesting` exists to preserve flatness / avoid new nesting
- `untee` may visibly introduce `block (result ...)` wrappers around former tees

So even though both can feel "flatter" in different senses, they are aiming at different invariants.

## Current-main drift check

A narrow 2026-04-21 drift check compared:

- `src/passes/Untee.cpp`
- `test/lit/passes/untee.wast`
- the `pass.cpp` registration lines

between `version_129` and current `main`.

Result:

- no diff in the reviewed implementation or dedicated test surface

So `version_129` is a reliable oracle here today.

## What a future Starshine port must preserve

- exact public name: `untee`
- explicit non-default status in current no-DWARF parity work
- function-parallel scope
- postorder nested-tee handling
- declared-local-type reuse for the synthetic get
- reachable-tee expansion into explicit set plus get
- unreachable-tee deletion instead of set/get fabrication
- the explicit split from `simplify-locals-notee` and other locals-family variants

## Sources

- [`../../../raw/research/0185-2026-04-21-untee-binaryen-research.md`](../../../raw/research/0185-2026-04-21-untee-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp>
