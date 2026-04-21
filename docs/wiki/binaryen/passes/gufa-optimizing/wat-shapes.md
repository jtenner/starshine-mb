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
  - ./cleanup-rerun-contract.md
  - ../gufa/index.md
---

# `gufa-optimizing` WAT shapes

This page focuses on the shapes that make the optimizing sibling visibly different from plain `gufa`.
For the broader GUFA proof surface, also read [`../gufa/index.md`](../gufa/index.md).

## Reading guide

Each family below answers three questions:

1. what shape plain GUFA can create
2. what extra cleanup `gufa-optimizing` performs
3. what a future Starshine port must preserve

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

- GUFA proves both result blocks always evaluate to `1`
- but it preserves the old call for effects
- so nested `drop` + `block` wrappers remain

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

- GUFA creates proof residue
- nested `dce` and `vacuum` remove that residue

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

- replace the impossible value site with `unreachable`
- preserve earlier side effects

### Optimizing sibling step

- `dce` removes the dead tail after the now-explicit `unreachable`
- `vacuum` removes trivial wrapper residue that no longer matters

### Porting rule

Do not confuse the proof step with the cleanup step.
The sibling's visible win is often the cleanup of dead suffixes exposed by the proof.

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

If the oracle proves the block's resulting value is known, GUFA may preserve the call only for effects and materialize the known result directly.
That can temporarily leave:

- `drop` wrappers
- wrapper `block`s
- repeated known constants

### Optimizing sibling step

`vacuum` trims unused-result residue after `dce` has already removed any bigger dead traffic.

### Porting rule

The pass should still preserve effect ordering, but it should not leave every proof wrapper visible in final output.

## Negative family 1: no extra cast insertion here

### Preserved shape

If the only possible improvement would be to add a fresh cast for a refined type, `gufa-optimizing` does **not** do that.
That belongs to `gufa-cast-all`.

### Porting rule

Do not quietly merge the cast-all behavior into this sibling.

## Negative family 2: tuple values are still out of scope

### Preserved shape

Tuple-typed expressions are skipped by the shared GUFA engine.
So the optimizing sibling does not suddenly become a multivalue cleanup pass.

### Porting rule

Keep the tuple boundary explicit unless the shared GUFA implementation itself grows tuple support.

## Negative family 3: ordered memory operations still block rewrites

### Preserved shape

If the shared GUFA logic refuses to rewrite a site because its memory order is not `Unordered`, the optimizing sibling has nothing to clean up there because there was no GUFA rewrite in the first place.

### Porting rule

Do not let the existence of nested cleanup blur the original semantic barriers.

## Negative family 4: unchanged functions do not rerun cleanup

### Preserved shape

If GUFA makes no rewrite in a function, `gufa-optimizing` does not run nested `dce` and `vacuum` there.

### Porting rule

The sibling's cleanup scope is **modified functions only**.
That is a real implementation detail, not a performance footnote.

## Comparison cheat sheet

| Situation | Plain `gufa` | `gufa-optimizing` |
| --- | --- | --- |
| prove a known constant through nested wrappers | may leave wrapper residue | cleans wrapper residue on changed function |
| prove a site unreachable | emits `unreachable` and may expose dead tails | also removes newly dead tails and wrappers |
| infer narrower type that could use a new cast | does not add new cast | still does not add new cast |
| function unchanged by GUFA | stop | stop |

## Best beginner summary

The visible WAT difference is usually not that `gufa-optimizing` proves something new.
It is that it leaves **less proof residue behind**.
