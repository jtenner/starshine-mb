---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
---

# `duplicate-function-elimination` WAT and module shapes

This page is the beginner-friendly shape catalog for Binaryen's official `duplicate-function-elimination` pass.

## Read this page with one mental model

Binaryen DFE is trying to prove:

- these two **defined** functions are semantically identical enough to share one implementation,
- every function reference can be retargeted safely,
- and any further transitive duplicates exposed by that rewrite are only pursued if the current optimize/shrink settings allow more rounds.

If that proof fails, the functions stay separate.

## Quick glossary

- **survivor**: the earlier function Binaryen keeps
- **duplicate**: the later equal function Binaryen removes
- **hash bucket**: a candidate group found by fast hashing, not by final proof
- **transitive unlock**: a later duplicate opportunity that appears only after an earlier callee rewrite
- **semantics-altering annotation**: function annotation that blocks merging when it differs
- **non-semantic metadata**: branch hints or debug/source location information that does not block merging here

## Positive family 1: two identical defined functions

Before:

```wat
(module
  (func $a (result i32)
    i32.const 0)
  (func $b (result i32)
    i32.const 0))
```

After, conceptually:

```wat
(module
  (func $a (result i32)
    i32.const 0))
```

Why this is safe:

- same type
- same locals
- same body
- no semantic-annotation mismatch

## Positive family 2: ordinary callsites are retargeted

Before:

```wat
(module
  (func $dup (nop))
  (func $other (nop))
  (func $caller
    (call $other)))
```

After, conceptually:

```wat
(module
  (func $dup (nop))
  (func $caller
    (call $dup)))
```

This is the most basic rewrite surface.

## Positive family 3: `ref.func` keeps the duplicate live until it is rewritten

Before:

```wat
(module
  (func $a (result i32) i32.const 0)
  (func $b (result i32) i32.const 0)
  (func $test (result funcref)
    (ref.func $b)))
```

After, conceptually:

```wat
(module
  (func $a (result i32) i32.const 0)
  (func $test (result funcref)
    (ref.func $a)))
```

The all-features test exists to prove that DFE does not accidentally delete a still-referenced function.

## Positive family 4: global `ref.func` plus later `call_ref`

Before:

```wat
(module
  (type $sig (func (result i32)))
  (global $g (ref $sig) (ref.func $b))
  (func $a (result i32) unreachable)
  (func $b (result i32) unreachable)
  (func $use (result i32)
    (call_ref $sig
      (global.get $g))))
```

After, conceptually:

```wat
(module
  (type $sig (func (result i32)))
  (global $g (ref $sig) (ref.func $a))
  (func $a (result i32) unreachable)
  (func $use (result i32)
    (call_ref $sig
      (global.get $g))))
```

This is the best beginner example of “module code rewrite matters too.”

## Positive family 5: exports, start, and element users follow the survivor

Before, conceptually:

```wat
(export "left" (func $a))
(export "right" (func $b))
(start $b)
(elem (i32.const 0) $a $b)
```

After, conceptually:

```wat
(export "left" (func $a))
(export "right" (func $a))
(start $a)
(elem (i32.const 0) $a $a)
```

The optimize-level lit files use this kind of surface to prove that DFE is not just body deletion.

## Positive family 6: different branch hints still merge

Before:

```wat
(func $a (param i32)
  (@metadata.code.branch_hint "\00")
  (if (local.get 0) (then unreachable)))
(func $b (param i32)
  (@metadata.code.branch_hint "\01")
  (if (local.get 0) (then unreachable)))
```

After, conceptually:

```wat
(func $a (param i32)
  (@metadata.code.branch_hint "\00")
  (if (local.get 0) (then unreachable)))
```

Important lesson:

- branch hints do not block the merge
- the survivor's metadata remains simply because the survivor remains
- for Starshine-local fixture planning, `@metadata.code.branch_hint` is Core/Binaryen code-metadata evidence, not current Starshine WAST expression-annotation support; route local parser/lowerer claims through [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md)

## Positive family 7: debug/source location differences still merge

Before, conceptually:

```wat
(func $a
  ;;@ src.cpp:10:1
  ...)
(func $b
  ;;@ src.cpp:99:1
  ...)
```

After, conceptually:

```wat
(func $a
  ;;@ src.cpp:10:1
  ...)
```

This is another proof that DFE is willing to optimize through non-semantic metadata differences.

## Positive family 8: transitive unlock at higher optimize levels

Before, conceptually:

```wat
(func $leaf1 (nop))
(func $leaf2 (nop))
(func $caller1 (call $leaf1))
(func $caller2 (call $leaf2))
```

A first round can merge `leaf2 -> leaf1`.
A later round can then see that `caller2` became identical to `caller1` and merge those too.

This is why the pass has an iteration budget instead of always stopping after the first visible deduplication.

## Negative family 1: imports are not candidates

Conceptually:

```wat
(import "env" "f" (func $f))
(func $g ...same shape...)
```

Why this is not a DFE candidate:

- the real pass only buckets **defined** functions
- imported functions are not part of the candidate set

## Negative family 2: same body text but different function type

Before:

```wat
(type $A (func))
(type $B (func (param i32)))
(func $a (type $A) (nop))
(func $b (type $B) (param i32) (nop))
```

Why this does not merge:

- function type equality is part of the proof

## Negative family 3: same params but different non-param locals

Before:

```wat
(func $a (local i32) (nop))
(func $b (local f32) (nop))
```

Why this does not merge:

- local-type layout is part of the proof too

## Negative family 4: semantics-altering annotation mismatch

Before:

```wat
(@binaryen.js.called)
(func $a (param i32)
  (if (local.get 0) (then unreachable)))
(func $b (param i32)
  (if (local.get 0) (then unreachable)))
```

Why this does not merge:

- `js.called` changes semantics
- Binaryen compares semantics-altering annotations explicitly

The same teaching story holds for the other dedicated test annotations:

- `@binaryen.removable.if.unused`
- `@binaryen.idempotent`

## Negative family 5: low/default iteration budget can stop before full transitive cleanup

Before, conceptually:

```wat
(func $leaf1 (nop))
(func $leaf2 (nop))
(func $caller1 (call $leaf1))
(func $caller2 (call $leaf2))
```

At low/default settings, Binaryen may merge only the leaves and stop there.

Why this matters:

- “no full fixpoint” is an official behavior detail, not an implementation accident

## Negative family 6: name collisions outside function references are not generic rename work

The all-features test includes a function, memory, and global whose printed names collide.

Important lesson:

- DFE only retargets **function references**
- it does not act like a general symbol-renaming pass for every namespace in the module

## Decision-shape note: the survivor is the earlier function

Two equal functions do not merge into a neutral fresh function.
The earlier one survives.

That means:

- export retargeting points at the earlier function
- `start` retargeting points at the earlier function
- `ref.func` retargeting points at the earlier function
- the earlier function's non-semantic metadata surface is what you still see afterward

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic type-section compaction
- automatic name-section stripping
- global metadata normalization after every merge
- import deduplication
- HOT-IR local peephole work
- guaranteed full fixpoint at every optimization level

## Scheduler interaction to remember

DFE is intentionally a module pass and intentionally appears twice in the default no-DWARF optimizer.

So its job is not just:

- “remove exact duplicates now”

It is also:

- “remove cheap duplicates before everything else”
- and later “remove new duplicates exposed by bigger late transforms”

That two-slot story is part of the real shape of the pass.
