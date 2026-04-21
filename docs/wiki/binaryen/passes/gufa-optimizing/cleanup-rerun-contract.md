---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../gufa/index.md
---

# `gufa-optimizing`: cleanup rerun contract

## Why this page exists

The easiest part of `gufa-optimizing` to misunderstand is also the entire reason the sibling exists.

People often summarize it as:

- “GUFA, but stronger.”

That hides the real source-backed lesson:

- GUFA's proof-based rewrites can create cleanup debt
- `gufa-optimizing` exists to pay that debt immediately with nested `dce` and `vacuum`

This page is the dedicated home for that exact contract.

## What cleanup debt GUFA creates

Plain GUFA is careful about correctness.
When it proves a new value or proves a site unreachable, it must still preserve any child work that had effects.
That can leave behind:

- `drop` wrappers
- extra `block` wrappers
- repeated constants in nested expression shells
- explicit `unreachable` whose consequences have not yet been harvested

Those shapes are not bugs.
They are the normal residue of a proof-first rewrite pass.

## Why `dce` is one of the nested passes

Once GUFA has inserted explicit `unreachable` or simplified result sites, later code may become dead:

- dead tails
- dead result traffic
- dead wrappers whose values no longer matter

`dce` is the local cleanup pass that removes that newly dead structure.

So `dce` is here because GUFA creates **new deadness**.

## Why `vacuum` is the other nested pass

Even after `dce`, GUFA may leave simple value-cleanup residue:

- extra `drop`
- empty or trivial wrappers
- preserved effect-only children around now-known values

`vacuum` is the local cleanup pass that trims that residue.

So `vacuum` is here because GUFA creates **new wrapper noise**.

## Why the order is `dce` then `vacuum`

Binaryen adds the passes in this order:

1. `dce`
2. `vacuum`

That order makes sense for the source-backed shape story:

- first remove bigger dead subtrees and dead result traffic
- then clean up the smaller trivial wrappers and dropped values that remain

A future port should preserve the ordering unless it has a source-backed reason not to.

## The canonical teaching example

The dedicated `gufa-optimizing.wast` file gives the best beginner example.
A nested block structure returns the same value that a helper call always returns.

Plain `gufa` proves the answer, but leaves a noisy chain of nested blocks and drops.
`gufa-optimizing` then cleans that result to:

- `drop (call $foo)`
- `i32.const 1`

This is the shortest “what changes?” summary of the sibling.

## What this sibling does **not** change

It does **not**:

- add new inference power
- widen the rewrite surface beyond plain GUFA
- insert the extra casts from `gufa-cast-all`
- rerun cleanup on unchanged functions
- become part of the default no-DWARF optimize scheduler

Those boundaries matter because otherwise the sibling sounds much broader than it really is.

## What a future Starshine port must preserve

Keep these rules explicit:

1. run the same whole-program GUFA proof phase first
2. only run the nested cleanup when that phase actually changed the function
3. refinalize before running cleanup
4. repair EH nested pops before running cleanup
5. run `dce` then `vacuum`
6. keep the split from `gufa-cast-all` explicit

## Best beginner summary

If plain `gufa` is:

- prove and rewrite

then `gufa-optimizing` is:

- prove, rewrite, then immediately clean up the proof residue
