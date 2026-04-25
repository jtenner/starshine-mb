---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md
  - ../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/insert_ordered.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-binary.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
  - ./wat-shapes.md
---

# Binaryen strategy for `const-hoisting`

## What the pass really is

The reviewed implementation is a **tiny function-local code-size pass**.
It does not discover new constants and it does not reason about arbitrary equivalent expressions.

The pass walks one function, groups repeated `Const` nodes by literal value, estimates the inline byte cost of each literal group, and hoists only the groups where:

- one literal plus one `local.set` plus many `local.get`s
- is smaller than repeating the literal inline every time

That means the best mental model is:

- **raw-wasm literal deduplication through a temp local**
- not constant folding
- not CSE
- not global pooling

## Public surface and scheduler meaning

The reviewed official Binaryen GitHub release page for `version_129`, rechecked on 2026-04-23 through [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md), showed publish date **2026-04-01**.
A focused 2026-04-25 current-`main` recheck captured in [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md) did not surface teaching-relevant drift in `ConstHoisting.cpp`, `literal.h`, `pass.cpp`, `wasm-binary.h`, or `const-hoisting.wast`.

`src/passes/pass.cpp` registers `const-hoisting` as a public pass.
The registration text says:

- `hoist repeated constants to a local (necessary for the register allocator in some cases)`

That public summary is easy to overread.
The actual reviewed implementation does not talk to the register allocator directly.
Its concrete work is much smaller:

- gather repeated literals
- run a byte-based profitability test
- rewrite profitable groups through fresh locals

Unlike many other public Binaryen passes, this one is not part of the current no-DWARF default optimize path documented in this repo.
So a future Starshine port should treat it as an **optional explicit pass with a narrow size-oriented contract**, not as a hidden required parity slot.

## Core state

The implementation has one key field:

- `InsertOrderedMap<Literal, std::vector<Expression**>> uses`

This tells us several important things immediately.

### 1. Grouping is by exact literal identity

Two uses are grouped only when they have the same `Literal` key.
That means:

- `i32.const 0` groups with other `i32.const 0`
- `f32.const 0` is a different group from `i32.const 0`
- float literals group by typed bit identity, not broad numeric equality
- `+0.0` and `-0.0` are separate buckets
- distinct NaN payloads are separate buckets
- computed expressions do not matter unless they have already become `Const`

That bit-identity rule is source-backed by Binaryen's `literal.h`: `Literal` equality checks the type and the bits, and the float hash path uses `reinterpreti32()` / `reinterpreti64()` rather than numeric canonicalization.

### 2. Rewriting is by pointer to the original use site

The stored `Expression**` means the pass is prepared to replace the exact AST slot where each constant appears.
It does not need a second search pass later.

### 3. Hoist order is stable

`InsertOrderedMap` preserves first-insertion order.
That makes emitted temp-local ordering stable and predictable.

## Main algorithmic phases

## Phase 1: collect every `Const`

`visitConst(Const* curr)` is the entire analysis step:

- `uses[curr->value].push_back(getCurrentPointer())`

This is intentionally tiny.
There is no effect analysis, no liveness analysis, no CFG walk, and no context sensitivity.
That is safe because `Const` expressions are pure and cannot trap.

## Phase 2: decide which literal groups are profitable

In `visitFunction(Function* curr)`, Binaryen iterates over the grouped literals and calls `worthHoisting(value, num)`.

This function has two layers:

### Layer A: quick floor

If `num < MIN_USES`, return false.

The constant is:

- `MIN_USES = 2`

But this is only a coarse minimum.
Many two-use groups still fail the real byte test.

### Layer B: measure literal encoding size

The implementation computes `size` differently by type:

- `i32`: signed LEB width via `S32LEB`
- `i64`: signed LEB width via `S64LEB`
- `f32`: `4` bytes
- `f64`: `8` bytes
- `v128`: immediately rejected

This is the part that beginners usually miss: Binaryen is optimizing **serialized wasm size**, not AST node count.

### Layer C: compare before/after encoding cost

The profitability formula is:

- `before = num * size`
- `after = size + 2 /* local.set */ + 2 * num /* local.get */`

Binaryen hoists only if:

- `after < before`

So the exact contract is:

- keep one copy of the literal payload
- pay once for a `local.set`
- pay a cheap `local.get` at each use site
- require strict byte savings overall

## Phase 3: rewrite one profitable group

`hoist(std::vector<Expression**>& vec)` performs the rewrite:

1. read the type from the first use site
2. allocate a fresh local with `builder.addVar(getFunction(), type)`
3. create `local.set temp <first-const>`
4. replace every recorded use site with `local.get temp`
5. return the `local.set` expression for placement in the prelude

Important subtlety:

- the first recorded constant node becomes the initializer of the new `local.set`
- all use sites, including that first one, are replaced by `local.get`

So there is never a leftover inline copy at an original use position.
The only remaining literal lives in the new prelude set.

## Phase 4: insert a function-entry prelude

If any groups were hoisted, `visitFunction` builds:

- `sequence(block(prelude), curr->body)`

and assigns that as the new function body.

The implementation comment explicitly says:

- `merge-blocks can optimize this into a single block later in most cases`

So the extra wrapper block is intentional and part of the pass interaction story.

## Helper dependencies that really matter

### `InsertOrderedMap`

This guarantees stable ordering of profitable literal groups.
That stability is important for deterministic local numbering and exact lit-test output.

### `wasm-binary.h`

This gives the signed-LEB writers used to measure real inline encoding cost for integers.
Without those helpers, the pass would only have a fuzzy heuristic instead of byte-accurate size reasoning.

### `Builder`

The rewrite surface is entirely builder-based:

- add temp locals
- build `local.set`
- build `local.get`
- wrap in `block`
- wrap in `sequence`

### `pass.h` and the walker framework

The pass is declared as:

- `WalkerPass<PostWalker<ConstHoisting>>`
- `isFunctionParallel() == true`

This matches the observed contract that hoisting is per function and does not coordinate across the module.
That per-function reading is a high-confidence inference from the reviewed pass shape.

## Why no heavier analysis is needed

This pass is surprisingly safe because of what it moves.
It only relocates `Const` nodes, which means:

- no side effects
- no traps
- no reads or writes
- no control-flow dependence
- no aliasing questions
- no lifetime proof beyond fresh-local insertion

That is why the implementation is radically smaller than motion passes like `code-pushing` or `licm`.

## Important implementation boundaries

## 1. No non-literal expression sharing

The pass never looks at anything except `Const`.
If you have:

```wat
(drop (i32.add (i32.const 1) (i32.const 2)))
(drop (i32.add (i32.const 1) (i32.const 2)))
```

`const-hoisting` does nothing unless some earlier pass has already folded those to `i32.const 3`.

## 2. No module-wide sharing

The pass does not create globals, imports, or shared pools.
Everything is local to one function body.

## 3. No `v128`

`v128` always returns false in `worthHoisting`.
That is an explicit scope boundary in `version_129`.

## 4. No zero special case yet

The top comment has TODOs noting that zeros are extra interesting because they may avoid even the initializing set, especially for floats.
But the current implementation still uses the generic formula for all supported scalar constants.
That means the current pass does **not** merge `+0.0` and `-0.0` into one bucket just because both are numerically zero; grouping still follows exact `Literal` bit identity.

## 5. Objective is raw binary size, not gzip size

The source comment warns that the pass can shrink raw code size while increasing gzip size.
That warning is part of the strategy, not incidental trivia.

## Threshold intuition

The upstream tests make the byte model concrete:

- 1-byte and 2-byte signed-LEB integers never win
- 3-byte literals need 6 uses
- 4-byte literals need 4 uses
- 8-byte literals need 2 uses

That explains why repeated `i32.const 8192` is hoisted while repeated `i32.const 64` is not.

## Important pass interactions

## `precompute` and `precompute-propagate`

These passes can materialize more `Const` nodes.
`const-hoisting` can then compress repeated large literal payloads.

So the relationship is:

- `precompute*` makes constants appear
- `const-hoisting` decides whether repeated large constants are cheaper as a temp-local pattern

## `merge-blocks`

The implementation explicitly expects later structural cleanup here because it emits a prelude block plus the original body.
A future scheduler that includes both should preserve that cleanup story.

## `simplify-locals*`

Those passes may clean up surrounding local structure, but a future port must not forget that the new temp locals were created for byte savings, not because the original code was semantically redundant.

## Beginner-facing summary of the real contract

If you want the shortest accurate rule, it is this:

- find repeated literal constants inside a function
- measure how many bytes the literal itself costs inline
- compare that against one `local.set` and many `local.get`s
- hoist only the groups that strictly save bytes
- leave the wrapper-block polish to later cleanup passes

That is the real Binaryen strategy for `const-hoisting`.

## Sources

- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md)
- [`../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`](../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md)
- [`../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md`](../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/insert_ordered.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-binary.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h>
