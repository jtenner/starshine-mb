---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./variant-matrix-and-scheduler.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `simplify-locals` WAT shapes

## Scope

This page records the important **upstream Binaryen `version_129`** shape families for the `simplify-locals` pass family.

It focuses on four things:

- positive rewrite shapes
- negative / bailout shapes
- what differs by variant
- what beginners are most likely to overgeneralize

For Starshine-local raw-lane and artifact notes, keep using the other pages in this folder.
This page is the upstream-facing shape catalog.

## Reading rule

Each family below answers four questions:

1. what shape Binaryen sees
2. what Binaryen tries to rewrite it into
3. which variant gates matter
4. what safety rule keeps the rewrite honest

## 1. Single-use linear sink

### Input

```wat
(local.set $tmp
  value
)
...
(local.get $tmp)
```

### Typical output

```wat
...
value
```

### Variants

- allowed in every variant, including `-nonesting`, if the sink does not create forbidden nesting there

### Why it works

- the local has one remaining use
- the intervening code does not invalidate the value by effect ordering
- the consumer can read the value directly instead of round-tripping through the local

### Easy misunderstanding

This is not just adjacency.
Binaryen may sink across later code when the effect model still says the order is legal.

## 2. Multi-use sink through `local.tee`

### Input

```wat
(local.set $tmp
  value
)
...
(local.get $tmp)
...
(local.get $tmp)
```

### Typical output

```wat
...
(local.tee $tmp
  value
)
...
(local.get $tmp)
```

### Variants

- allowed only when `allowTee = true`
- therefore not allowed in `-notee`, `-notee-nostructure`, or `-nonesting`

### Why it works

- the first use can consume the value directly
- later uses still need the local
- tee preserves both meanings at once

### Easy misunderstanding

Binaryen does **not** do this on the first cycle.
The first cycle deliberately prefers only the single-use wins.

## 3. Overwritten pending set becomes side-effect-only cleanup

### Input

```wat
(local.set $tmp
  (call $side)
)
(local.set $tmp
  (i32.const 0)
)
```

### Typical output

```wat
(drop
  (call $side)
)
(local.set $tmp
  (i32.const 0)
)
```

### Variants

- all variants

### Why it works

- the earlier write can no longer be observed through `$tmp`
- its side effects still matter
- so Binaryen keeps the value evaluation but erases the now-dead store meaning

### Easy misunderstanding

This is not the final dead-set phase yet.
This overwrite cleanup happens during the main walk itself.

## 4. Dead tee cleanup under `drop`

### Input

```wat
(drop
  (local.tee $tmp
    value
  )
)
```

### Typical output

```wat
(local.set $tmp
  value
)
```

### Variants

- any variant that could have produced or encountered the tee

### Why it works

- the tee's produced value is immediately discarded
- only the write matters now

## 5. Block return formation from shared local exits

### Input

```wat
(block $out
  ...
  (local.set $x a)
  (br $out)
  ...
  (local.set $x b)
)
(local.get $x)
```

### Typical output shape

```wat
(local.set $x
  (block $out (result T)
    ...
    a-or-b-through-block-exits
  )
)
```

### Variants

- only structured variants (`allowStructure = true`)

### Why it works

- every relevant exit sets the same local
- Binaryen can reinterpret that local traffic as a real block result instead

### Important guard

Unsupported branch-target users such as `Switch` / `BrOn` poison this optimization for the named block.

## 6. `br_if` condition hazard blocks some block-return rewrites

### Input

```wat
(br_if $out
  condition-using-(local.set $x ...)
)
```

### Required outcome

- sometimes keep the original local/set structure
- do **not** blindly move that set into the branch payload position

### Why it is blocked

If the set is moved from the condition into the payload position, the value write may happen earlier than the condition expected.
The source performs an explicit `orderedBefore` hazard check for this case.

### Beginner lesson

Block return synthesis is not just pattern matching on labels.
The branch condition's evaluation order still matters.

## 7. If/else shared-local result formation

### Input

```wat
(if
  cond
  (then
    (local.set $x a)
  )
  (else
    (local.set $x b)
  )
)
(local.get $x)
```

### Typical output shape

```wat
(local.set $x
  (if (result T)
    cond
    (then a)
    (else b)
  )
)
```

### Variants

- only structured variants

### Why it works

- both arms are really computing one later value of `$x`
- Binaryen can expose that as an actual `if` result instead of a hidden local carrier

## 8. One-armed `if` speculative result formation

### Input

```wat
(if
  cond
  (then
    (local.set $x value)
  )
)
(local.get $x)
```

### Typical output shape

```wat
(local.set $x
  (if (result T)
    cond
    (then value)
    (else (local.get $x))
  )
)
```

### Variants

- only structured variants

### Why it works

- Binaryen speculates that exposing the value flow directly may help later passes

### Important guard

- the local type must be defaultable

### Easy misunderstanding

This is not always a clear size or speed win.
The source explicitly calls it a speculative optimization.

## 9. Nondefaultable locals block the one-armed `if` rewrite

### Input

```wat
(local $x (ref func))
(if
  cond
  (then
    (local.set $x (ref.func $f))
  )
)
(local.get $x)
```

### Required outcome

- keep the original non-result `if`
- do not synthesize a new else-arm `local.get`

### Why it is blocked

The new else-arm get might not be structurally dominated by a set.
Later fixups would repair validation with `ref.as_non_null`, which can introduce a real trap.
So Binaryen skips this rewrite instead.

## 10. Loop return formation in the narrow trailing-`nop` case

### Input

```wat
(loop
  ...
  (local.set $x value)
)
(local.get $x)
```

### Typical output shape

```wat
(local.set $x
  (loop (result T)
    ...
    value
  )
)
```

### Variants

- only structured variants

### Important guard

- the loop must currently be void
- the body must be or become a block with a trailing `nop` slot

### Beginner lesson

Binaryen's loop-return rewrite is real, but narrow.
It is not a generic loop value optimizer.

## 11. May-throw values do not sink into `try` / `try_table`

### Input

```wat
(local.set $x
  (call $might_throw)
)
(try
  (do
    (drop (local.get $x))
  )
  ...
)
```

### Required outcome

- keep the set outside the `try`

### Why it is blocked

Moving the call inside could change whether a thrown exception is caught.
The source explicitly invalidates sinkables that may throw at `try` / `try_table` entry.

## 12. Non-throwing values may sink into `try` / `try_table`

### Input

```wat
(local.set $x
  (i32.const 3)
)
(try_table ...
  (drop (local.get $x))
)
```

### Typical output

```wat
(nop)
(try_table ...
  (drop (i32.const 3))
)
```

### Variants

- all variants that otherwise allow the sink

### Why it works

- the value cannot throw
- moving it into the try region does not change catch semantics

## 13. Immutable global reads may move; mutable ones may not

### Positive input

```wat
(local.set $x
  (global.get $imm)
)
(call $helper)
(local.get $x)
```

### Positive output

```wat
(call $helper)
(global.get $imm)
```

### Negative input

```wat
(local.set $x
  (global.get $mut)
)
(call $helper)
(local.get $x)
```

### Negative outcome

- keep the local traffic

### Why the split exists

- immutable globals cannot be changed by the call
- mutable globals might be

`global-effects_simplify-locals.wast` extends this further by showing that generated global-effect summaries can distinguish read-only calls from writing calls.

## 14. Heap, table, and string ordering still matters

### Heap read vs heap write

A `struct.get` or array load cannot move past a conflicting heap write.
An immutable heap read may move past an unrelated write if the effect model says that write cannot change the read's meaning.

### Table read vs table write

`table.get` may move past inert code like `nop`, but not past `table.init`.

### String read/write-like ops

The official string tests show that Binaryen treats:

- `string.new_*_array` like a heap-array read family for ordering
- `string.encode_*_array` like a heap-array write family for ordering

Beginner lesson:

- string instructions are not magically outside the effect model

## 15. Shared/unshared and acquire/release atomic shapes matter

The atomic-effects lit file demonstrates that `simplify-locals` is sensitive to:

- whether memory is shared
- whether GC heaps are shared
- acquire vs ordinary read ordering
- acquire vs ordinary store ordering

So the pass is not just “same local, same value.”
Its motion model includes real synchronization boundaries.

## 16. `trapsNeverHappen` opens some motion, but not everything

### Positive TNH family

A trapping read may move past some later side effect when TNH says the trap is unreachable in practice.

### Negative TNH family

The pass still stays within its straight-line-trace model.
The TNH test file shows that Binaryen does **not** suddenly become a generic cross-control-flow mover.

## 17. Equivalent-copy late canonicalization

### Input

```wat
(local.set $b
  (local.get $a)
)
...
(local.get $b)
```

### Typical late output

```wat
...
(local.get $a)
```

or, if `$b` is the better representative:

```wat
...
(local.get $b)
```

### Why the outcome varies

The late phase chooses the best equivalent local by:

1. more refined type
2. otherwise more remaining gets

So the point is not simply “always collapse to the oldest local.”

## 18. Preserve the tee that later `rse` and fallthrough still need

The dedicated `simplify-locals_rse_fallthrough.wast` file exists to stop an easy overreach.

A tee that looks redundant in isolation may still be necessary once:

- branch payload timing
- fallthrough value meaning
- and later `rse` cleanup

are considered together.

Beginner lesson:

- not every duplicate-looking tee is dead just because one local currently mirrors another

## 19. `BrOn` / `Switch` and related target users are explicit bailouts

The source marks named blocks unoptimizable for structure-return purposes when it encounters unsupported target users.

So if a block looks like a good block-result candidate except for a `br_on_*` or `switch` family, the correct upstream answer today is usually:

- keep the local carrier
- do not half-port the block-result rewrite

## 20. `-nonesting` is stricter than the other reduced variants

### Input family

A sink is otherwise legal, but would create a new nested expression position.

### Outcome in `-nonesting`

- reject the sink

### Outcome in ordinary variants

- the sink may still be allowed

### Why this matters

The flatten/souper combo tests exist because this stronger flatness promise is part of a real aggressive scheduler surface, not dead option clutter.

## Maintenance rule

When updating this page, prefer the official Binaryen-backed question:

- what shapes does `version_129` actually rewrite or intentionally preserve?

Do not silently replace that with a Starshine-local raw-lane story.
Keep the upstream positive, negative, and bailout families explicit, especially when a future port is tempted to overgeneralize one of the structure or tee rewrites.
