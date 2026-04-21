---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - ../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_precompute.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_vacuum_ignore-implicit-traps.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_remove-unused-brs_vacuum.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_code-folding.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names_merge-blocks_all-features.txt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./control-names-implicit-blocks-and-delegates.md
  - ../remove-unused-brs/index.md
  - ../vacuum/index.md
  - ../merge-blocks/index.md
---

# `remove-unused-names` WAT and IR shape catalog

This page is the beginner-friendly answer to:

- what shapes does Binaryen actually rewrite here?
- what shapes merely become easier for later passes?
- what shapes stay untouched?

The key reminder for every example below is:

- these are **control-label** shapes, not debug-name shapes

And the compact proof-surface rule is:

- the dedicated `remove-unused-names.wast` / `.txt` pair proves the core block / loop / `br_table` families directly
- the larger `*_precompute`, `*_vacuum`, `*_remove-unused-brs_vacuum`, `*_code-folding`, and `*_merge-blocks_all-features` files prove the surrounding cleanup-cluster interactions
- the delegate-caller sentinel story is source-confirmed mainly from owner files rather than from a dedicated standalone lit filename

## How to read these examples

- The examples are schematic WAT, not byte-for-byte copies of Binaryen tests.
- They describe the durable shape families the official tests prove.
- “May disappear” often means:
  - the pass cleared a label
  - the block became implicit
  - later printing or nearby cleanup stopped showing the wrapper

## Positive shape 1: dead named outer block

### Before

```wat
(block $top
  (i32.const 0)
)
```

### After

```wat
(i32.const 0)
```

### Why

No branch targets `$top`, so the name can disappear.
Once the block is nameless, Binaryen may emit the body directly.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Positive shape 2: named parent and named child of the same type

### Before

```wat
(block $a
  (block $b
    (br $a)
    (br $b)
  )
)
```

### After

```wat
(block $b
  (br $b)
  (br $b)
)
```

### Why

- the parent has exactly one child
- the child is also a block
- both have the same type
- branches that used to target `$a` can target `$b` instead

This is the pass's clearest explicit branch-retargeting rewrite.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Positive shape 3: `br_table` target collapse through parent/child merge

### Before

```wat
(block $a
  (block $b
    (br_table $a $b (i32.const 3))
  )
)
```

### After

```wat
(block $b
  (br_table $b $b (i32.const 3))
)
```

### Why

The same single-child same-type rule works for multi-target branch forms too.
The pass uses `replacePossibleTarget(...)`, so all parent-target uses can be rewritten, not just plain `br`.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Positive shape 4: typed block merge still works in an unreachable-heavy shape

### Before

```wat
(block $outer (result i32)
  (block $inner (result i32)
    ... branches carrying i32 values ...
  )
)
```

### After

```wat
(block $inner (result i32)
  ... same carried-value exits, retargeted to `$inner` ...
)
```

### Why

The pass does not require the body to be simple.
It only requires:

- one child block
- child still named
- equal types

The official typed / unreachable-heavy test exists precisely to prove that this rewrite is about label equivalence, not about body prettiness.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Positive shape 5: loop with no continue users

### Before

```wat
(loop $again
  (nop)
)
```

### After

```wat
(nop)
```

### Why

If nobody branches to `$again`, the loop label is semantically dead.
When the body type matches the loop type, the wrapper can collapse into the body.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Positive shape 6: parent unused, child used

### Before

```wat
(block $outer
  (block $inner
    (br $inner)
  )
)
```

### After

```wat
(block $inner
  (br $inner)
)
```

### Why

Even if no branch targets the parent label, the explicit parent/child merge is still useful when the child label survives.
The pass can simply drop the parent layer and keep the child target.

### Source grounding

- official merge-focused tests in `remove-unused-names.wast`
- broader structural families in `remove-unused-names_merge-blocks_all-features.wast`

## Positive shape 7: after `precompute`, a switch/default label may become dead

### Before

```wat
(block $default
  (block $case
    (br_table $case $default (i32.const 0))
  )
  ...
)
```

### After the nearby cleanup cluster

```wat
(block $default
  (nop)
  ...
)
```

### Why

`precompute` can make the branch choice constant.
Then `remove-unused-names` can strip the now-dead label layer that was only needed for the old dynamic branch shape.

### Source grounding

- `remove-unused-names_precompute.wast` / `.txt`

## Positive shape 8: after `remove-unused-brs`, more labels become removable

### Before

A large branch-heavy function with many nested named blocks and loops whose labels existed only to support exits that `remove-unused-brs` later deletes or retargets.

### After the `remove-unused-names -> remove-unused-brs -> remove-unused-names -> vacuum` cluster

- fewer live labels
- more implicit blocks
- loops or block layers that now collapse safely

### Why

This is the real scheduler story:

- branch cleanup opens label-cleanup opportunities
- label cleanup exposes inert structure
- vacuum removes the leftover garbage

### Source grounding

- `remove-unused-names_remove-unused-brs_vacuum.wast` / `.txt`

## Positive shape 9: later `code-folding` and `merge-blocks` like fewer named wrappers

### Before

```wat
(block $named
  (block
    ...
  )
)
```

### After `remove-unused-names` plus later cleanup

- named wrappers disappear or collapse
- later passes can treat the remaining structure as ordinary nameless block shape

### Why

Names are a real structural constraint in Binaryen IR.
Removing unneeded ones can expose later tail-sharing or block-splice opportunities.

### Source grounding

- `remove-unused-names_code-folding.wast` / `.txt`
- `remove-unused-names_merge-blocks_all-features.wast` / `.txt`

## Negative shape 1: child type mismatch blocks the merge

### Before

```wat
(loop (result i32)
  (block $l
    (unreachable)
  )
)
```

### After

The loop wrapper stays.

### Why

Unused labels alone are not enough.
Binaryen still requires the loop body type to match the loop type before demoting the loop.

### Source grounding

- dedicated `remove-unused-names.wast` / `.txt`

## Negative shape 2: still-targeted label means no peel

### Before

```wat
(block $outer
  (block $inner
    (if (cond)
      (then (br $outer))
    )
  )
)
```

### After

The outer label cannot simply disappear while the branch still targets it.

### Why

This is the core liveness rule of the pass.
A syntactically present scope-name use keeps the label alive.

### Source grounding

- dedicated merge / non-merge families
- current in-tree Starshine tests that mirror the same bailout idea

## Negative shape 3: not a generic branch-deletion pass

### Before

```wat
(block $l
  (br $l)
)
```

### After

The pass does **not** delete the branch itself.
It only reasons about whether the target label is still needed.

### Why

Deleting or retargeting dead / redundant exits is the neighboring job of `remove-unused-brs`, not this pass.

### Source grounding

- official scheduler placement in `pass.cpp`
- combo tests with `remove-unused-brs`

## Negative shape 4: not a trap / effects cleanup pass

### Before

```wat
(block $l
  (drop (if (result f64) ... (f64.load ...) ...))
)
```

### After

Label removal may simplify the wrapper story, but trap-sensitive cleanup still belongs to `vacuum` and friends.

### Why

`remove-unused-names` does not use effect analysis.
It only tracks scope-name uses.

### Source grounding

- `remove-unused-names_vacuum.wast` / `.txt`
- `remove-unused-names_vacuum_ignore-implicit-traps.wast` / `.txt`

## Negative shape 5: not name-section cleanup

### Before

A function has human-readable symbols in the wasm name section.

### After

This pass does not target that metadata.

### Why

The official implementation edits control-scope names referenced by branches and delegates.
That is a different surface entirely.

## Easy misunderstanding: “the pass flattened the block”

Often the more accurate explanation is:

- the pass removed the label
- the block became implicit
- the emitted WAT stopped printing it

That distinction matters when porting the pass.
If your IR or writer does not have the same implicit-block rule, you must recreate the semantic result by some other means.

## Bottom line

The shortest accurate shape summary is:

- positive: dead control labels, same-type single-child named blocks, and dead-label loops
- negative: type-mismatch wrappers, still-targeted labels, trap/effect cleanup, and generic branch deletion

That is the shape contract a future Starshine port must preserve.
