---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# `gufa-cast-all` WAT and IR shapes

This page gives beginner-friendly before/after sketches for the main source-backed shapes in Binaryen `gufa-cast-all`.
They are simplified teaching examples, not exact copied lit-file excerpts.

## How to read these examples

- “Before” means the kind of IR shape Binaryen can see before the pass.
- “After” means the important semantic direction of change, not byte-for-byte output.
- The real pass is whole-program and oracle-driven, so these examples are intentionally small teaching sketches.

## Shape 1: plain GUFA still does the first rewrite work

Before:

```wat
(ref.eq
  (call $makeA)
  (ref.null none)
)
```

Possible conceptual after:

```wat
i32.const 0
```

Why:

- the family still includes plain GUFA's ordinary rewrites first
- `gufa-cast-all` is not only about brand-new casts

## Shape 2: a new cast is inserted on a value with a broader static type

Before:

```wat
(local.get $x) ;; static type: (ref null $Top)
```

After under `gufa-cast-all`, conceptually:

```wat
(ref.cast (ref null $Narrower)
  (local.get $x)
)
```

Why:

- the oracle can prove that the reachable contents are inside a narrower cone
- plain `gufa` may know that fact without directly materializing it
- `gufa-cast-all` makes the fact explicit

## Shape 3: existing-cast refinement and new-cast insertion are different

Before:

```wat
(ref.cast (ref null $Mid)
  (local.get $x)
)
```

Possible after, conceptually:

```wat
(ref.cast (ref null $Narrower)
  (local.get $x)
)
```

Why:

- the shared GUFA family can sharpen an existing cast target
- the sibling's extra value is that it can also add a cast where none existed before

## Shape 4: cast-all can expose sharper downstream information without changing the producer

Before:

```wat
(struct.get $A 0
  (local.get $x)
)
```

Possible conceptual after:

```wat
(struct.get $A 0
  (ref.cast (ref $A)
    (local.get $x)
  )
)
```

Why:

- the pass is making already-proved type knowledge explicit
- later GC/cast-aware passes can then see that sharper type directly

## Shape 5: exactness is feature-sensitive

Before:

```wat
(local.get $x)
```

Possible conceptual after on a feature-rich target:

```wat
(ref.cast (ref (exact $B))
  (local.get $x)
)
```

Possible conceptual after on a stricter feature surface:

```wat
(ref.cast (ref $B)
  (local.get $x)
)
```

Why:

- the reviewed GUFA-family sources and lit surface show that exactness may need to be downgraded
- the pass emits the narrowest valid cast, not always the narrowest imaginable cast

## Shape 6: some candidate values stay unchanged

Before:

```wat
(local.get $x)
```

Possible after:

```wat
(local.get $x)
```

Why:

- the dedicated lit file includes preserved no-op cases too
- the oracle knowing more is not by itself enough
- castability, legality, and feature rules still filter the insertion step

## Shape 7: this sibling does not own cleanup reruns

Before plain GUFA can produce wrappers that leave simplification debt.
`gufa-optimizing` owns the nested cleanup for those cases.
`gufa-cast-all` does not.

So conceptually, if the pass adds a cast but also leaves structure around it, you should **not** expect this sibling alone to run:

- `dce`
- `vacuum`

That absence is part of the contract.

## Shape 8: the pass is not generic cast spraying

Before:

```wat
(local.get $x)
(local.get $y)
(call $use-both ...)
```

Possible after:

```wat
(local.get $x)
(local.get $y)
(call $use-both ...)
```

Why:

- not every place with narrower oracle knowledge is turned into a cast
- Binaryen keeps a deliberate conservative boundary

## Short checklist for future ports

Keep these rules visible in tests and docs:

- plain GUFA rewrites happen first
- the distinctive sibling step is new `ref.cast` insertion
- refinalize before inserting those casts
- exactness is feature-sensitive
- preserved no-op cases are part of the contract
- nested cleanup belongs to `gufa-optimizing`, not here
