---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./content-oracle-variants-and-boundaries.md
  - ./starshine-strategy.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
---

# `gufa` WAT shapes

This page gives beginner-friendly before/after sketches for the main source-backed shapes in Binaryen `gufa`.
They are simplified teaching examples, not exact copied lit-file excerpts.
The source-backed provenance for these families is now captured in [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md).

## How to read these examples

Think in four questions:

1. what contents can reach this location?
2. can Binaryen emit a direct replacement node for those contents?
3. if it can, does that replacement still validate at the original type?
4. is this plain `gufa`, or one of the sibling-only shapes owned by `gufa-optimizing` / `gufa-cast-all`?

If the answers line up, GUFA rewrites.
If not, it often preserves the original code.

## Shape 1: never-called parameter becomes unreachable

Before:

```wat
(func $never-called (param $x i32) (result i32)
  (local.get $x)
)
```

After, conceptually:

```wat
(func $never-called (param $x i32) (result i32)
  (unreachable)
)
```

Why:

- the oracle sees no contents reaching `$x`
- `None` means unreachable

## Shape 2: one known helper result flows through a caller

Before:

```wat
(func $foo (result i32)
  (i32.const 1)
)

(func $bar (result i32)
  (call $foo)
)
```

After, conceptually:

```wat
(func $foo (result i32)
  (i32.const 1)
)

(func $bar (result i32)
  (i32.const 1)
)
```

Why:

- the oracle knows the call result in `$bar` is always `1`
- the replacement is directly materializable and type-compatible

## Shape 3: block / select result collapses to one known value

Before:

```wat
(func (result i32)
  (block (result i32)
    (drop (call $side))
    (i32.const 7)
  )
)
```

After, conceptually:

```wat
(func (result i32)
  (block
    (drop (call $side))
    (i32.const 7)
  )
)
```

Or, if wrapper structure must be preserved for effects, closer to:

```wat
(func (result i32)
  (block
    (drop
      (block (result i32)
        (drop (call $side))
        (i32.const 7)
      )
    )
    (i32.const 7)
  )
)
```

Why:

- GUFA may know the result value exactly
- but it still preserves child side effects with drop wrappers
- this is one reason `gufa-optimizing` exists

## Shape 4: impossible `ref.eq` becomes `0`

Before:

```wat
(ref.eq
  (local.get $a)
  (local.get $b)
)
```

After, conceptually:

```wat
(i32.const 0)
```

Why:

- the possible contents of the two sides have no intersection
- so they can never be the same reference

## Shape 5: guaranteed `ref.test` becomes `1`

Before:

```wat
(ref.test (ref $A)
  (local.get $x)
)
```

After, conceptually:

```wat
(i32.const 1)
```

Why:

- the operand contents are a subset of the target type cone

## Shape 6: impossible `ref.test` becomes `0`

Before:

```wat
(ref.test (ref $B)
  (local.get $x)
)
```

After, conceptually:

```wat
(i32.const 0)
```

Why:

- the operand contents and target cone do not intersect

## Shape 7: existing `ref.cast` gets a narrower type

Before:

```wat
(ref.cast (ref $A)
  (local.get $x)
)
```

After, conceptually:

```wat
(ref.cast (ref (exact $B))
  (local.get $x)
)
```

Why:

- GUFA may prove the cast result is always a narrower subtype
- plain GUFA can refine an existing cast even when it would not insert a brand-new one elsewhere

## Shape 8: `gufa-cast-all` inserts a new cast where plain GUFA would not

Before:

```wat
(local.get $x) ;; static type is wider than actual contents
```

After under `gufa-cast-all`, conceptually:

```wat
(ref.cast (ref $Narrower)
  (local.get $x)
)
```

Why:

- the oracle knows a narrower type
- the cast-all variant makes that knowledge explicit for downstream passes

Plain `gufa` would usually leave this alone if there were no existing cast to refine.
In current Starshine this entire family is still a future-port surface: `RefCast` exists in the instruction/HOT layers, but no GUFA oracle decides where to insert or refine casts.

## Shape 9: plain `gufa` can leave ugly wrapper code behind

Before:

```wat
(block $out (result i32)
  (block $in (result i32)
    (call $foo)
  )
)
```

After plain `gufa`, conceptually:

```wat
(block
  (drop
    (block $out (result i32)
      (drop
        (block $in (result i32)
          (call $foo)
        )
      )
      (i32.const 1)
    )
  )
  (i32.const 1)
)
```

After `gufa-optimizing`, conceptually closer to:

```wat
(i32.const 1)
```

Why:

- GUFA preserves effects first
- the optimizing sibling then runs `dce` and `vacuum` to clean up the leftover scaffolding

## Shape 10: known runtime value but wrong emitted type => no direct replacement

Before:

```wat
(ref.as_non_null
  (global.get $nullable-global)
)
```

Possible runtime fact:

- the global's runtime contents may always be one specific non-null value

But plain GUFA may still keep the original structure.

Why:

- the emitted `global.get` has the global's static nullable type
- that may not validate as a direct replacement for a non-null result site
- Binaryen currently bails out in this family instead of forcing extra repair nodes

This is one of the most important negative shapes in the pass.

## Shape 11: ordered atomics stay untouched

Before:

```wat
(i32.atomic.load
  (i32.const 0)
)
```

After:

```wat
(i32.atomic.load
  (i32.const 0)
)
```

Why:

- the pass bails out when memory order is not `Unordered`
- synchronization semantics are preserved

## Shape 12: tuple-typed values stay untouched

Before:

```wat
(call $multi)
```

where the result type is multivalue / tuple.

After:

```wat
(call $multi)
```

Why:

- `visitExpression` explicitly skips tuple types

## Shape 13: exported or open-world-sensitive cases stay conservative

Before:

```wat
(func $public (param $x i32) (result i32)
  (local.get $x)
)
(export "public" (func $public))
```

After:

```wat
(func $public (param $x i32) (result i32)
  (local.get $x)
)
(export "public" (func $public))
```

Why:

- the whole-program proof is weaker when outside callers may exist
- the official tests keep this distinction explicit with `--closed-world`

## Shape 14: nonmaterializable cone information still helps, even without direct replacement

Before:

```wat
(local.get $x) ;; wide ref type in IR
```

After under plain `gufa`:

```wat
(local.get $x)
```

But elsewhere, GUFA may still use the narrower cone to optimize:

- `ref.test`
- `ref.cast`
- `gufa-cast-all`

Why:

- the oracle can know more than the current direct replacement surface can emit

## Shape 15: exactness is feature-sensitive

Before:

```wat
(ref.cast (ref $A)
  (local.get $x)
)
```

Potential after, only when feature rules allow it:

```wat
(ref.cast (ref (exact $B))
  (local.get $x)
)
```

Possible preserved outcome instead:

```wat
(ref.cast (ref $B)
  (local.get $x)
)
```

Why:

- exact refinement is downgraded when custom descriptors are unavailable

## Short checklist for future ports

A future Starshine port should keep these shape rules explicit:

- `None` => `unreachable`
- one literal / global / `ref.func` value => direct replacement only when type-compatible
- `ref.eq` uses intersection, not syntax
- `ref.test` uses cone inclusion, not syntax
- existing `ref.cast` can be refined
- new casts belong to `gufa-cast-all`
- nested cleanup belongs to `gufa-optimizing`
- tuples and ordered atomics stay conservative
- current Starshine has many emitted instruction forms but no GUFA-family contents oracle yet; see [`./starshine-strategy.md`](./starshine-strategy.md)

## Sources

- [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md)
- [`../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md`](../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md`](../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md)
