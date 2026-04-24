---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md
  - ../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../dead-code-elimination/index.md
  - ../vacuum/index.md
---

# `gufa-optimizing`: cleanup rerun contract

## Why this page exists

The easiest part of `gufa-optimizing` to misunderstand is also the entire reason the sibling exists.

People often summarize it as:

- “GUFA, but stronger.”

That hides the real source-backed lesson:

- GUFA's proof-based rewrites can create cleanup debt;
- `gufa-optimizing` pays that debt immediately with nested `dce` and `vacuum`;
- the cleanup runs only on functions whose GUFA rewrite phase changed them.

## What cleanup debt GUFA creates

Plain GUFA is careful about correctness. When it proves a new value or proves a site unreachable, it must still preserve child work that may have effects. That can leave behind:

- `drop` wrappers,
- extra `block` wrappers,
- repeated constants in nested expression shells,
- explicit `unreachable` whose consequences have not yet been harvested.

Those shapes are not bugs. They are normal residue from a proof-first rewrite pass.

## Why `dce` is one nested pass

Once GUFA inserts explicit `unreachable` or simplifies result sites, later code may become dead:

- dead tails,
- dead result traffic,
- dead wrappers whose values no longer matter.

`dce` removes that newly dead structure. So `dce` is here because GUFA creates **new deadness**.

## Why `vacuum` is the other nested pass

Even after `dce`, GUFA may leave simple value-cleanup residue:

- extra drops,
- empty or trivial wrappers,
- preserved effect-only children around now-known values.

`vacuum` trims that residue. So `vacuum` is here because GUFA creates **new wrapper noise**.

## Why the order is `dce` then `vacuum`

Binaryen adds the nested passes in this order:

1. `dce`,
2. `vacuum`.

That order matches the shape story:

- first remove bigger dead subtrees and dead result traffic,
- then clean up the smaller trivial wrappers and dropped values that remain.

A future port should preserve the order unless a new source-backed Binaryen change says otherwise.

## The canonical teaching example

The dedicated `gufa-optimizing.wast` file is the best beginner source. A nested block structure returns the same value that a helper call always returns.

Plain `gufa` proves the answer but leaves a noisy chain of nested blocks and drops. `gufa-optimizing` cleans that result to:

- preserve the call for effects,
- discard the call result,
- emit the known constant directly.

This is the shortest “what changes?” summary of the sibling.

## Ordering constraints

The nested cleanup does not run immediately after the first replacement. Binaryen first:

1. finishes the function visitor,
2. refinalizes the changed function,
3. repairs EH nested pops,
4. then runs the cleanup passes.

That protects the cleanup passes from seeing stale types after GUFA's value replacements.

## What this sibling does not change

It does **not**:

- add new inference power;
- widen the rewrite surface beyond plain GUFA;
- insert the extra casts from `gufa-cast-all`;
- rerun cleanup on unchanged functions;
- become part of the reviewed default no-DWARF optimize scheduler.

Those boundaries matter because otherwise the sibling sounds much broader than it really is.

## What a future Starshine port must preserve

Keep these rules explicit:

1. run the same whole-program GUFA proof phase first;
2. only run nested cleanup when that proof phase actually changed the function;
3. validate or refinalize before cleanup;
4. repair any EH / control-stack details before cleanup;
5. run local `dead-code-elimination` then `vacuum`;
6. keep the split from `gufa-cast-all` explicit.

## Best beginner summary

If plain `gufa` is:

- prove and rewrite,

then `gufa-optimizing` is:

- prove, rewrite, then immediately clean up the proof residue.
