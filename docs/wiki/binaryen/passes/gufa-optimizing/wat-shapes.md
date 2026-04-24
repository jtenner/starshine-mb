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
  - ./cleanup-rerun-contract.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
---

# `gufa-optimizing` WAT shapes

This page focuses on the shapes that make the optimizing sibling visibly different from plain `gufa`. For the broader GUFA proof surface, also read [`../gufa/index.md`](../gufa/index.md).

## Reading guide

Each family below answers three questions:

1. what shape plain GUFA can create,
2. what extra cleanup `gufa-optimizing` performs,
3. what a future Starshine port must preserve.

## Positive family 1: nested result wrappers collapse after constant proof

### Before

```wat
(func $foo (result i32)
  (i32.const 1)
)

(func $bar (result i32)
  (block $out (result i32)
    (block $in (result i32)
      (call $foo)
    )
  )
)
```

### Plain `gufa`-style outcome

Beginner summary:

- GUFA proves both result blocks always evaluate to `1`;
- it preserves the old call for effects;
- nested `drop` plus `block` wrappers may remain.

### `gufa-optimizing` outcome

```wat
(func $bar (result i32)
  (drop
    (call $foo)
  )
  (i32.const 1)
)
```

### Why it changes

- GUFA creates proof residue.
- Nested `dce` and `vacuum` remove that residue.

### Porting rule

Keep the effectful call alive, but do not keep the unnecessary wrapper stack.

## Positive family 2: impossible value site becomes `unreachable`, then dead tails disappear

### Before

```wat
(func (result i32)
  (block (result i32)
    ;; imagine GUFA proves this branch can never produce a value
    (call $effectful)
    (unreachable)
    (i32.const 99)
  )
)
```

### Shared GUFA step

- Replace the impossible value site with `unreachable`.
- Preserve earlier side effects.

### Optimizing sibling step

- `dce` removes the dead tail after the now-explicit `unreachable`.
- `vacuum` removes trivial wrapper residue that no longer matters.

### Porting rule

Do not confuse the proof step with the cleanup step. The sibling's visible win is often the cleanup of dead suffixes exposed by the proof.

## Positive family 3: preserved-effect `drop` scaffolding gets trimmed

### Before

```wat
(func (result i32)
  (block (result i32)
    (call $effectful-returning-i32)
  )
)
```

### Shared GUFA step

If the oracle proves the block's resulting value is known, GUFA may preserve the call only for effects and materialize the known result directly. That can temporarily leave:

- `drop` wrappers,
- wrapper `block`s,
- repeated known constants.

### Optimizing sibling step

`vacuum` trims unused-result residue after `dce` has already removed any larger dead traffic.

### Porting rule

The pass should still preserve effect ordering, but it should not leave every proof wrapper visible in final output.

## Positive family 4: cleanup scope is function-local after a module proof

The proof is module-wide, but the nested cleanup is per changed function. If GUFA only rewrites `$bar`, then only `$bar` gets the `dce` + `vacuum` rerun.

### Porting rule

A future Starshine port should not turn `gufa-optimizing` into a whole-module cleanup sweep after every analysis run. The cleanup scope is changed functions.

## Negative family 1: no extra cast insertion here

If the only possible improvement would be to add a fresh cast for a refined type, `gufa-optimizing` does **not** do that. That belongs to [`../gufa-cast-all/index.md`](../gufa-cast-all/index.md).

### Porting rule

Do not quietly merge the cast-all behavior into this sibling.

## Negative family 2: tuple values are still out of scope

Tuple-typed expressions are skipped by the shared GUFA engine. The optimizing sibling does not suddenly become a multivalue cleanup pass.

### Porting rule

Keep the tuple boundary explicit unless the shared GUFA implementation itself grows tuple support.

## Negative family 3: ordered memory operations still block rewrites

If the shared GUFA logic refuses to rewrite a site because its memory order is not safe for the value replacement, the optimizing sibling has nothing to clean up there because there was no GUFA rewrite in the first place.

### Porting rule

Do not let the existence of nested cleanup blur the original semantic barriers.

## Negative family 4: unchanged functions do not rerun cleanup

If GUFA makes no rewrite in a function, `gufa-optimizing` does not run nested `dce` and `vacuum` there.

### Porting rule

The sibling's cleanup scope is **modified functions only**. That is a real implementation detail, not just a performance footnote.

## Comparison cheat sheet

| Situation | Plain `gufa` | `gufa-optimizing` |
| --- | --- | --- |
| Prove a known constant through nested wrappers | May leave wrapper residue | Cleans wrapper residue on changed function |
| Prove a site unreachable | Emits `unreachable` and may expose dead tails | Also removes newly dead tails and wrappers |
| Infer narrower type that could use a new cast | Does not add new cast | Still does not add new cast |
| Function unchanged by GUFA | Stop | Stop |

## Best beginner summary

The visible WAT difference is usually not that `gufa-optimizing` proves something new. It is that it leaves **less proof residue behind**.
