---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/README.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../remove-unused-brs/index.md
  - ../merge-blocks/index.md
---

# Control names, implicit blocks, and delegates in `remove-unused-names`

## Why this page exists

The hardest part of `remove-unused-names` is not the C++ syntax.
It is the mental model.

A lot of confusion comes from thinking “name” means one of these things instead:

- a debug name
- the wasm name section
- a printed label that is nice for humans but semantically optional

That is **not** what this pass is about.

## In Binaryen IR, these names are control-flow semantics

Binaryen README makes three rules explicit:

- blocks and loops may have names
- branch targets in Binaryen IR are resolved by **name**, not by nesting depth
- names are required to be unique in the IR

So when `remove-unused-names` edits a block, loop, or try name, it is editing control-flow structure, not just presentation.

## Why nameless blocks matter so much

README also says:

- blocks without names may not be branch targets
- nameless blocks can be emitted implicitly instead of as explicit `block` structure

That means there are two very different but connected effects:

1. **Label removal**
   - the pass clears a dead control label
2. **Structural disappearance later**
   - because the block is now nameless, Binaryen may not emit it as a visible block anymore

That second step is why this pass can look stronger in printed output than its source code alone suggests.

## The key beginner distinction

### What the pass directly rewrites

Direct source-level rewrites are small:

- clear a dead label
- retarget branches from a parent block label to a child block label during same-type single-child merges
- replace a dead-label loop with its body when types match

### What often happens afterward

After labels are cleared:

- blocks become implicit
- nearby cleanup passes see simpler structure
- printed WAT may show fewer explicit wrappers

Do not blur those two stories together.

## Why unique names simplify the implementation

Because Binaryen IR enforces unique scope names, `remove-unused-names` can track label uses in a global:

- `map<Name, set<Expression*>>`

It does **not** need a stack of shadowed labels like a raw depth-index implementation would.

That is why the pass can stay tiny.

A future port on an IR without unique names must preserve the **semantic** property somehow, even if the data structure changes.

## Same-type parent/child block merge

This is the most visible explicit control rewrite.

When Binaryen sees:

- a named block
- containing exactly one child
- where that child is also a named block
- and both blocks have the same type

it can rewrite every branch targeting the parent so that it instead targets the child.
Then the parent block can disappear.

### Why this is safe

In that exact shape:

- breaking to the parent lands in the same place as breaking to the child
- as long as the result type is the same

### Why this is not generic flattening

Binaryen does **not** flatten arbitrary nested named blocks here.
It needs:

- one child only
- same type
- a real named child to receive the retargeted branches

If those are not true, the explicit merge does not happen.

## Child already nameless? Different story

A subtle but important case is when the child name has already been removed.
Then:

- `child->name.is()` is false
- the explicit merge path does not fire

That does **not** mean the pass failed.
It often means the child is already on the simpler path:

- nameless child
- implicit block later
- less visible structure on emission anyway

So explicit merge and implicit-block disappearance are siblings, not synonyms.

## Loop names mean continue targets

A loop label is only semantically useful if something branches to it as a continue target.

So when Binaryen clears the loop name and sees:

- the body type equals the loop type

it can replace the loop with the body directly.

### Why the type check matters

Even an unused-label loop is not always replaceable.
If the body type does not match the loop type, the wrapper still carries type information and must stay.

This is why the official tests include a deliberate negative case.

## Delegate targets are part of the real contract

The pass is not just about `br` and `br_table`.

Binaryen also has delegate-style scope-name uses.
That is why:

- `visitTry(...)` explicitly calls the generic expression visitor after handling the try's own label
- `visitFunction(...)` erases `DELEGATE_CALLER_TARGET` before asserting the map is empty

The caller-delegate sentinel is a pseudo-target outside ordinary in-function scopes.
A faithful port must preserve that distinction.

## Labeled inference: syntactic, not reachability-sensitive

This is an inference from the official source layout, not a direct Binaryen comment:

- `branch-utils.h` offers `isBranchReachable(...)`
- `RemoveUnusedNames.cpp` does not use it

So the practical rule appears to be:

- if a scope-name use is syntactically present, this pass treats it as keeping the label alive
- stronger proof about whether that exit can actually happen belongs to other passes nearby

That matches the surrounding scheduler:

- `remove-unused-brs`
- `precompute`
- `vacuum`

all open fresh opportunities that `remove-unused-names` then consumes cheaply.

## Why this pass is not a name-section pass

The wasm name section is metadata for humans and tools.
`remove-unused-names` does not operate there.

Instead it operates on:

- `Block.name`
- `Loop.name`
- `Try.name`
- branch / delegate target fields that refer to those scope names

That is why the pass can change emitted control structure and validation behavior.
It is editing IR semantics.

## Porting rule for Starshine

If the host IR uses:

- numeric labels
- region ids
- explicit target handles
- or another non-name representation

then a future port should preserve the real contract in semantic form:

- know which control scopes are still targetable
- remove the dead ones
- retarget equivalent parent/child scopes when safe
- keep delegate-to-caller special
- separate direct rewrites from downstream implicit-structure cleanup

## Bottom line

The right beginner sentence is:

- in Binaryen, `remove-unused-names` removes dead **control labels**, and a lot of the structural simplification you see afterward comes from Binaryen's implicit-block rules rather than from some hidden giant block-flattener.
