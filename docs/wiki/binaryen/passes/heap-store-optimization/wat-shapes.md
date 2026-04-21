---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./swap-safety-and-control-flow.md
  - ../../no-dwarf-default-optimize-path.md
---

# `heap-store-optimization` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `heap-store-optimization` pass.

## Read this page with one mental model

Binaryen is usually trying to do one thing:

- take a value that is being written with `struct.set`,
- move that value back into the `struct.new` that created the same struct,
- and remove the redundant `struct.set`.

Everything else on this page is about why that sometimes works and sometimes does not.

## Quick glossary

- **fresh struct**: a struct value produced by a nearby `struct.new` that the pass is still tracking
- **tee form**: the immediate `(struct.set (local.tee ... (struct.new ...)) VALUE)` pattern
- **subsequent form**: the later `(local.set X (struct.new ...))` then `(struct.set (local.get X) VALUE)` pattern
- **moved value**: the `VALUE` that Binaryen wants to place into the constructor instead
- **blocker**: an instruction between the fresh constructor and a later matching `struct.set`

## Shape family 1: immediate tee fold

Before:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 10)))
  (i32.const 20))
```

After:

```wat
(local.set $x
  (struct.new $S
    (i32.const 20)))
```

This is the clearest positive shape.

The pass deletes the `struct.set` entirely and downgrades the tee to a plain `local.set`.

## Shape family 2: subsequent local-set fold

Before:

```wat
(local.set $x
  (struct.new $S
    (i32.const 10)))
(struct.set $S 0
  (local.get $x)
  (i32.const 20))
```

After:

```wat
(local.set $x
  (struct.new $S
    (i32.const 20)))
(nop)
```

Why the `nop` remains:

- Binaryen expects later cleanup passes to erase it.

## Shape family 3: repeated subsequent stores on the same local

Before:

```wat
(local.set $x
  (struct.new $S
    (i32.const 10)))
(struct.set $S 0
  (local.get $x)
  (i32.const 20))
(struct.set $S 0
  (local.get $x)
  (i32.const 30))
```

After, conceptually:

```wat
(local.set $x
  (struct.new $S
    (i32.const 30)))
(nop)
(nop)
```

Important lesson:

- once the chain stays valid, later matching `struct.set`s can keep overwriting the constructor field
- the last surviving value wins

## Shape family 4: old field side effects are kept

Before:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (call $helper-i32 (i32.const 0))))
  (i32.const 20))
```

After, conceptually:

```wat
(local.set $x
  (struct.new $S
    (block (result i32)
      (drop
        (call $helper-i32 (i32.const 0)))
      (i32.const 20))))
```

Important lesson:

- Binaryen does **not** erase the old field expression if it still has unremovable side effects
- it preserves the side effects and only changes the final value

## Shape family 5: later constructor operands can block the fold

Positive case:

```wat
(struct.set $S2 1
  (local.tee $x
    (struct.new $S2
      (call $helper-i32 (i32.const 0))
      (i32.const 10)))
  (call $helper-i32 (i32.const 1)))
```

This is okay because the moved value is replacing the **last** field.
It does not need to cross a conflicting later operand.

Negative case:

```wat
(struct.set $S2 0
  (local.tee $x
    (struct.new $S2
      (i32.const 10)
      (call $helper-i32 (i32.const 0))))
  (call $helper-i32 (i32.const 1)))
```

This is not okay because the moved value would have to cross the later side-effectful second field.

## Shape family 6: `struct.new_default` can be materialized

Before:

```wat
(struct.set $S3 1
  (local.tee $x
    (struct.new_default $S3))
  (i32.const 33))
```

After:

```wat
(local.set $x
  (struct.new $S3
    (i32.const 0)
    (i32.const 33)
    (i32.const 0)))
```

Important warning:

- this can make the constructor longer
- Binaryen still does it because removing the later `struct.set` is usually worth it

## Shape family 7: safe swaps across simple blockers

Before:

```wat
(local.set $x
  (struct.new $S
    (i32.const 10)))
(drop (memory.size))
(struct.set $S 0
  (local.get $x)
  (i32.const 20))
```

After, conceptually:

```wat
(drop (memory.size))
(local.set $x
  (struct.new $S
    (i32.const 20)))
(nop)
```

Why this can work:

- the blocker can be reordered safely with the fresh constructor set
- after the swap, the matching `struct.set` becomes adjacent enough to fold

The same basic story appears in test families that swap across:

- `nop`
- unrelated `local.set`
- unrelated `global.set`
- `drop(memory.size)`
- `drop(table.size)`

## Shape family 8: wrong local or wrong pattern means no optimization

Before:

```wat
(local.set $x
  (struct.new $S
    (i32.const 10)))
(struct.set $S 0
  (local.get $other)
  (i32.const 20))
```

After:

```wat
;; unchanged
```

Important lesson:

- the pass is not proving aliasing through arbitrary dataflow
- it wants the exact fresh-local pattern

## Shape family 9: moved value touching the target local blocks the fold

Negative read case:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 10)))
  (block (result i32)
    (drop (local.get $x))
    (i32.const 20)))
```

Negative write case:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 10)))
  (block (result i32)
    (local.set $x (ref.null $S))
    (i32.const 20)))
```

Why both are rejected:

- moving the value earlier would change when it observes or mutates the ref local

## Shape family 10: internal control flow can be unsafe

Unsafe outer-branch case:

```wat
(block $out
  (struct.set $S 0
    (local.tee $x
      (struct.new $S
        (i32.const 1)))
    (if (result i32)
      (i32.const 1)
      (then (br $out))
      (else (i32.const 42)))))
(struct.get $S 0
  (local.get $x))
```

This is unsafe because the branch can bypass the moved `local.set` and later code still reads `$x`.

Unsafe caught-call case:

```wat
(block $label
  (try_table (catch $tag $label)
    (struct.set $S 0
      (local.tee $x
        (struct.new $S
          (i32.const 1)))
      (call $helper-i32 (i32.const 42)))))
```

This is unsafe because the call can transfer control to a catch **inside the same function**.

## Shape family 11: internal control flow can also be safe

Safe in-value loop case:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 1)))
  (loop $loop (result i32)
    (br_if $loop
      (local.get $cond))
    (i32.const 42)))
```

Why this can be safe:

- the loop's control flow stays contained inside the moved value itself
- it does not create a path that skips the `local.set` and then later exposes the wrong local state inside the function

Safe return case:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 1)))
  (if (result i32)
    (i32.const 1)
    (then (return (i32.const 42)))
    (else (i32.const 42))))
```

Why this can be safe:

- the `return` exits the function entirely
- later in-function local observers do not happen on that path

## Shape family 12: later control flow does not retroactively poison an earlier fold

Before:

```wat
(struct.set $S 0
  (local.tee $x
    (struct.new $S
      (i32.const 1)))
  (i32.const 42))
(block $out
  (br_if $out (local.get $cond)))
```

Binaryen can still optimize the earlier `struct.set`.

Important lesson:

- the pass cares about control flow that interacts with the moved value and moved `local.set`
- unrelated later control flow does not automatically cancel an already-safe fold

## Shape family 13: unreachable code is left for other passes

Negative case:

```wat
(local.set $x
  (struct.new $S
    (unreachable)))
(struct.set $S 0
  (local.get $x)
  (i32.const 10))
```

Binaryen does not optimize this pair.

Important lesson:

- HSO deliberately leaves unreachable weirdness for DCE / later cleanup instead of trying to repair types itself

## Shape family 14: non-goals

These shapes are outside the real `version_129` contract:

- `array.set` into fresh `array.new`
- ordinary `memory.store`
- `table.set`
- generic dead store elimination on mutable GC state
- generic load forwarding

The pass name sounds broad enough for those ideas.
The actual pass does not do them yet.

## Scheduler interaction to remember

The dedicated upstream test suite runs `remove-unused-names` before `heap-store-optimization`.

That means some block/control-flow shapes become easier for HSO to accept only after useless labels are gone.

So if a named-block shape looks surprisingly stubborn in isolation, that may be a real pass-order issue, not a contradiction in the rule set.
