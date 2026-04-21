# Binaryen `untee` research

Date: 2026-04-21
Status: source-backed upstream-only dossier seed
Pass: `untee`
Local registry status: `removed` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/Untee.cpp`, `test/lit/passes/untee.wast`, and the `pass.cpp` registration are unchanged on `main`

## Why this note exists

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered.
That means this thread had to either justify a major-gap fallback or add another genuinely eligible upstream-only registry pass.

`untee` is a good source-backed expansion target because:

- it is still explicitly named in the local removed-pass registry in `src/passes/optimize.mbt`
- it is a real public Binaryen pass in `src/passes/pass.cpp`
- it has a dedicated upstream implementation file and a dedicated lit file
- it teaches a real beginner-facing distinction that the current wiki still lacks: removing existing `local.tee`s is **not** the same thing as the `simplify-locals` family variants that merely forbid creating new tees
- its own source comment explicitly ties it to nearby passes like `code-pushing`, which makes it useful as a bridge between already-covered locals cleanup and control-motion dossiers
- `agent-todo.md` currently has **no dedicated `untee` slice**

## Executive summary

Binaryen `untee` is a tiny function-parallel pass that walks `LocalSet` nodes after their children have already been processed.
Whenever a `local.set` is actually a `local.tee`, it rewrites that one node in one of two ways:

1. if the tee's value is `unreachable`, delete the tee wrapper and leave the `unreachable` child behind
2. otherwise, turn the tee into an ordinary `local.set`, then return the value again with a `local.get` in a small sequence/block wrapper

A good beginner summary is:

- `untee` removes `local.tee` syntax sugar from Binaryen IR
- by spelling every tee as **"do the set, then read the local back"**
- so later passes see flatter, more explicit side effects

The pass is **not**:

- the main `simplify-locals` optimizer
- a no-DWARF default-preset slot in this repo
- a value-numbering pass
- a dead-store pass
- a generic control-flow simplifier

## Source files reviewed

### Primary implementation

- `src/passes/Untee.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/untee.wast`

### Important supporting surface

- `src/passes/passes.h`
  - proves `createUnteePass()` is a first-class public pass constructor
- `src/passes/SimplifyLocals.cpp`
  - useful neighbor source for explaining why `untee` is different from `simplify-locals-notee` and `simplify-locals-nonesting`
- local docs already in-tree:
  - `docs/wiki/binaryen/passes/code-pushing/`
  - `docs/wiki/binaryen/passes/simplify-locals/`
  - `docs/wiki/binaryen/passes/simplify-locals-notee/`
  - `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/`

## Public registration and naming

`pass.cpp` registers:

- `untee`
- summary text: `removes local.tees, replacing them with sets and gets`

That public description is unusually honest.
The local Starshine registry also uses the same public name, but still tracks it only as a removed pass.

Important scheduler fact:

- the reviewed `version_129` no-DWARF default optimize path in `pass.cpp` does **not** schedule `untee`

So this dossier is about a real public upstream pass that still matters for teaching and possible explicit future use, not a missing default-path parity slot.

## What the implementation actually does

## 1. Walk only `LocalSet` nodes

The pass class is:

- `WalkerPass<PostWalker<Untee>>`

and its only custom visitor is:

- `visitLocalSet(LocalSet* curr)`

That tells us the real scope immediately:

- `untee` does not inspect arbitrary expressions
- it does not need CFG analysis, effects analysis, or local-graph helpers
- it only cares about nodes that may be tees already

Because it is a **post-walk**, inner tees are rewritten before outer tees.
That matters for nested tee chains in the test file.

## 2. Filter to real tees only

The first semantic check is simply:

- `if (curr->isTee())`

So ordinary `local.set` stays untouched.
This sounds obvious, but it is an important teaching boundary:

- `untee` is not a locals cleanup pass in the broad sense
- it is a syntax-normalization pass for one exact IR node family

## 3. Special-case `unreachable`

If the tee's value already has type `unreachable`, the pass does **not** build a `set + get` wrapper.
Instead it replaces the whole tee with just the child value.

Why that matters:

- if control never reaches the tee, there is no meaningful write to preserve
- emitting a `local.get` after an unreachable child would be nonsense
- the dedicated test file locks this exact behavior with `(drop (local.tee ... (unreachable))) -> (drop (unreachable))`

That is the most important negative/bailout shape in the pass.

## 4. Normal rewrite: set first, then get

For reachable tees, Binaryen does four tiny steps:

1. create a `LocalGet` for the same local index and the function's declared local type
2. build a sequence from the current node plus that `LocalGet`
3. replace the current expression with that sequence
4. mutate the original node from tee form into plain set form with `curr->makeSet()`

The ordering is subtle but important.
Binaryen first builds the outer sequence around the original `curr`, then mutates `curr` into a plain set.
That way the sequence ends up containing:

- the original write, now as `local.set`
- followed by an explicit `local.get`

In printed WAT this typically appears as a `block (result T)` shell whose body is:

- `local.set $x ...`
- `local.get $x`

## 5. Preserve the local's declared type

The synthetic `local.get` uses:

- `getFunction()->getLocalType(curr->index)`

So the pass does not re-infer the type from the child value.
It returns the local's declared value type.

This is exactly what a real `local.tee` means semantically, so a future port must preserve it.

## 6. Function-parallel and otherwise tiny

The implementation explicitly reports:

- `bool isFunctionParallel() override { return true; }`

That fits the reviewed source surface:

- no module-level state
- no helper synthesis
- no cross-function reasoning
- no nested cleanup runner

`untee` is one of the smallest genuine public passes in the Binaryen registry.

## Important rewrite shapes

## Shape A: dropped tee becomes dropped set/get shell

Input idea:

```wat
(drop (local.tee $x (i32.const 1)))
```

Output idea:

```wat
(drop
  (block (result i32)
    (local.set $x (i32.const 1))
    (local.get $x)))
```

Meaning:

- the pass removes tee syntax
- but preserves the fact that the expression still produces the assigned value

## Shape B: tee inside `local.set`

Input idea:

```wat
(local.set $x (local.tee $x (i32.const 3)))
```

Output idea:

```wat
(local.set $x
  (block (result i32)
    (local.set $x (i32.const 3))
    (local.get $x)))
```

This looks redundant to beginners, but it is correct.
The inner tee's value still has to feed the outer `local.set`.

## Shape C: nested tee chains expand inside-out

Input idea:

```wat
(local.set $x (local.tee $x (local.tee $x (i32.const 3))))
```

Because of the post-walk, the inner tee expands first, then the outer tee expands around the result.
The official lit file checks exactly this family.

## Shape D: unreachable tee disappears instead of expanding

Input idea:

```wat
(drop (local.tee $x (unreachable)))
```

Output idea:

```wat
(drop (unreachable))
```

That is not just an optimization; it is part of the correctness contract.

## What is easy to misunderstand

## Misunderstanding 1: "this is just `simplify-locals-notee`"

It is not.

- `untee` removes **existing** `local.tee` nodes unconditionally, except for the unreachable fast path
- `simplify-locals-notee` is still a broader locals optimizer that may sink values, form structured results, and do late copy cleanup, but it refuses transformations that would need to **create** a new tee

Those are different contracts.

## Misunderstanding 2: "this is always a win"

Not necessarily.

`untee` deliberately makes side effects more explicit and often adds visible wrapper structure.
That may help some later passes, but it can also make code temporarily bigger or more block-heavy.
The source comment explicitly frames it as an enabler for passes like `code-pushing`, not as a universal shrink or speed pass by itself.

## Misunderstanding 3: "the pass rewrites arbitrary uses of locals"

No.

It does not analyze get/set chains or liveness.
It rewrites one exact IR node family: `local.tee`.

## Misunderstanding 4: "the block wrapper is incidental printer noise"

Not in the reviewed contract.
The dedicated lit file checks the explicit `block (result T)` style output.
So a future port must preserve the semantic `set-then-get` wrapper shape even if its internal IR builder spells sequences differently.

## Interactions with nearby passes

## `code-pushing`

This interaction is explicit in the source comment.
Binaryen says removing tees makes code flatter and can help passes like `code-pushing`.
The intuition is beginner-friendly:

- tee hides "write and value result" inside one node
- untee spells that out as separate side effects
- motion-oriented passes can reason about explicit set boundaries more directly

## `simplify-locals*`

The `simplify-locals` family often creates or preserves tees because tees are useful for sinking values without duplicating computation.
`untee` goes in the opposite direction:

- make the write explicit now
- leave later passes free to re-simplify from that flatter form if desired

So the two pass families are neighbors, not synonyms.

## `flatten`

Inference from reviewed sources:

- `flatten` and `simplify-locals-nonesting` care about explicit locals and flatness
- `untee` similarly prefers explicit set/get sequencing over tee sugar

But unlike the flatten-era passes, `untee` does **not** claim or enforce the formal Flat IR contract.
That distinction matters.

## Current-main drift check

A narrow 2026-04-21 drift check compared:

- `src/passes/Untee.cpp`
- `test/lit/passes/untee.wast`
- the `pass.cpp` registration lines

between `version_129` and `main`.

Result:

- no diff in the reviewed implementation or dedicated test surface

So `version_129` is a reliable oracle for this pass right now.

## Porting checklist for future Starshine work

A future Starshine port should preserve:

- exact public name: `untee`
- removed-registry status until it is really implemented
- function-parallel scope
- postorder nested-tee behavior
- ordinary-tee rewrite as set + get, not as duplicated value computation
- local declared-type reuse for the synthetic get
- special-case unreachable deletion instead of set/get expansion
- the explicit distinction from `simplify-locals-notee` and `simplify-locals-nonesting`
- the fact that this is an optional public pass, not a current no-DWARF parity slot

## Open questions

- The reviewed official surface is tiny and stable, so there are no major algorithmic unknowns left here.
- A future implementation question for Starshine is mostly scheduler-related: whether `untee` should remain only an explicit pass or also become a useful helper/cleanup surface around future motion passes.
- That scheduler question is an inference from neighboring Binaryen pass comments, not something `version_129` resolves by default-preset placement.

## Sources

- Local registry and campaign context:
  - `src/passes/optimize.mbt`
  - `agent-todo.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- Official Binaryen `version_129` sources:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast`
- Freshness-check sources:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Untee.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/untee.wast`
