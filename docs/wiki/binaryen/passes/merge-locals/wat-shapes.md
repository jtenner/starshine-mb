---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# `merge-locals` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `merge-locals`.
Examples are intentionally small and conceptual; exact final WAT can differ after later cleanup passes.

## Correct mental model

Binaryen asks:

- does a local have exactly one set?
- is that set's value simple?
- do all graph-influenced gets for that local trace back to that same set?
- can the pass reuse a small source local, or should it create one fresh temp?

It does not ask whether arbitrary locals can share storage.
That is [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

## Shape 1: direct source-local reuse

Before:

```wat
(local $src i32)
(local $tmp i32)
(local.set $tmp (local.get $src))
(drop (local.get $tmp))
```

After, conceptually:

```wat
(local $src i32)
(local $tmp i32)
(drop (local.get $src))
```

Why it rewrites:

- `$tmp` has one set
- the set value is a simple `local.get`
- the influenced get of `$tmp` is fed by that same set
- Binaryen can reuse `$src` directly

The unused declaration can remain until another cleanup removes it.

## Shape 2: simple non-local value uses a fresh temp

Before:

```wat
(local $a i32)
(local $b i32)
(local.set $a (i32.const 10))
(local.set $b (i32.const 10))
(drop (i32.add (local.get $a) (local.get $b)))
```

After, conceptually:

```wat
(local $fresh i32)
(local.set $fresh (i32.const 10))
(drop (i32.add (local.get $fresh) (local.get $fresh)))
```

Why it rewrites:

- the set values are simple constants
- a single temp can hold the shared simple value
- redundant local sets can be removed or neutralized during materialization

This shape is the important correction to the 2026-04-23 dossier: fresh-temp output is part of the source-backed pass.

## Shape 3: branching / arity shape can still rewrite

Before, conceptually:

```wat
(if (result i32)
  (local.get $cond)
  (then
    (local.set $tmp (local.get $src))
    (local.get $tmp))
  (else
    (local.get $src)))
```

After, conceptually:

```wat
(if (result i32)
  (local.get $cond)
  (then
    (local.get $src))
  (else
    (local.get $src)))
```

Why it can rewrite:

- structured control alone is not a bailout
- the relevant local still has one set and a clean influenced-get story

## Shape 4: DAG-like sharing can rewrite

Before, conceptually:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 7))
(local.set $c (i32.add (local.get $a) (local.get $b)))
(drop (local.get $c))
```

After, conceptually, part of the repeated simple value may be shared through one temp:

```wat
(local.set $fresh (i32.const 7))
(local.set $c (i32.add (local.get $fresh) (local.get $fresh)))
(drop (local.get $c))
```

Why it can rewrite:

- the pass is graph-guided and can see repeated simple set values across more than adjacent pairs

## Shape 5: loop-backedge copy is not automatically a bailout

Before, conceptually:

```wat
(loop $L
  (local.set $tmp (local.get $src))
  (drop (local.get $tmp))
  (br $L))
```

After, conceptually:

```wat
(loop $L
  (drop (local.get $src))
  (br $L))
```

Why it can rewrite:

- loop syntax alone does not break the pass
- the influence proof is what matters

## Shape 6: extra set blocks the candidate

Before and after stay the same in the important part:

```wat
(local.set $x (i32.const 1))
(if (local.get $cond)
  (then (local.set $x (i32.const 2))))
(drop (local.get $x))
```

Why Binaryen keeps it:

- `$x` has more than one set
- the pass is not a general value-equivalence solver

## Shape 7: complex or effectful value blocks the candidate

Before and after stay the same in the important part:

```wat
(local.set $x (call $impure))
(drop (local.get $x))
```

Why Binaryen keeps it:

- the set value is not simple
- moving or sharing it might change effects, traps, or ordering

## Shape 8: named locals make the whole function bail out

Before and after stay the same when the function has local names:

```wat
(func $f (local $named i32)
  (local.set $named (i32.const 1))
  (drop (local.get $named)))
```

Why Binaryen keeps it:

- current `MergeLocals.cpp` treats local names as useful debug-facing data
- the pass skips instead of rewriting local identity under those names

## Shape 9: unreachable-adjacent ambiguity is conservative

Before and after can stay the same around an unreachable boundary:

```wat
(local.set $x (i32.const 1))
unreachable
(drop (local.get $x))
```

Why this matters:

- the official lit file includes a `between-unreachable` conservative family
- do not assume unreachable code always unlocks a more aggressive merge

## One-sentence summary for each family

- **source-local reuse:** positive when one simple set is a small `local.get` source chain
- **fresh temp:** positive when the value is simple but cannot be reused directly
- **branch / arity:** positive when influence facts stay clean
- **DAG / loop:** can be positive because the pass is graph-guided
- **extra set:** negative
- **complex value:** negative
- **named locals:** function-level bailout
- **unreachable-adjacent ambiguity:** conservative

## Bottom line

`merge-locals` rewrites locals whose graph story is one simple set feeding all influenced gets.
It either retargets to an existing source local or creates a fresh temp.
Everything else is a bailout or a neighboring pass's job.
