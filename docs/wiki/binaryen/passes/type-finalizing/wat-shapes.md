---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0192-2026-04-21-type-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
---

# `type-finalizing` WAT shapes

This pass is more **module-shape-driven** than expression-shape-driven.
So the examples here focus on type declarations and the places that mention them.

## Reading note

The examples are beginner-friendly sketches of the shapes Binaryen's official lit file proves.
They are meant to teach the contract, not reproduce the full test file verbatim.

## Positive shape 1: private open leaf becomes final

Before:

```wat
(module
  (type $leaf (sub (struct (field i32))))
)
```

After `--type-finalizing`:

```wat
(module
  (type $leaf (struct (field i32)))
)
```

Why it changes:

- the type is private
- it has no subtypes
- so Binaryen can finalize it

## Positive shape 2: private final leaf becomes open under the sibling

Before:

```wat
(module
  (type $leaf (sub final (struct (field i64))))
)
```

After `--type-unfinalizing`:

```wat
(module
  (type $leaf (sub (struct (field i64))))
)
```

Why it changes:

- the sibling is reopening private types
- it does not require the leaf-only proof

## Positive shape 3: function heap type participates too

Before:

```wat
(module
  (type $sig (sub final (func)))
  (func (type $sig))
)
```

After `--type-unfinalizing`:

```wat
(module
  (type $sig (sub (func)))
  (func (type $sig))
)
```

Why it matters:

- the pass is not only about struct declarations
- function heap types are part of the nominal type graph too

## Positive shape 4: globals and locals keep following the rewritten types

Before:

```wat
(module
  (type $leaf (sub (struct (field i32))))
  (global (ref null $leaf) (ref.null $leaf))
  (func
    (local (ref $leaf))
  )
)
```

After `--type-finalizing`, the rewritten module stays coherent because Binaryen updates the type graph through the global helper.

Beginner point:

- the pass is not just changing the `type` line and hoping everything else still works

## Preserved shape 1: public type stays unchanged

Before:

```wat
(module
  (type $public (sub (struct (field i32))))
  (global $g (ref null $public) (ref.null $public))
  (export "g" (global $g))
)
```

After either sibling pass:

```wat
(module
  (type $public (sub (struct (field i32))))
  ...
)
```

Why it stays:

- public types are outside the pass's modification set

## Preserved shape 2: non-leaf private parent stays open

Before:

```wat
(module
  (rec
    (type $parent (sub (struct)))
    (type $child (sub $parent (struct)))
  )
)
```

After `--type-finalizing`:

```wat
(module
  (rec
    (type $parent (sub (struct)))
    (type $child (sub final $parent (struct)))
  )
)
```

Why the parent stays open:

- it has an immediate subtype
- so it is not a finalizable leaf

## Preserved shape 3: no GC means no rewrite

If the module does not use GC heap types, the pass does nothing.

That is a hard gate, not a profitability choice.

## Bailout shape 1: this is not type deletion

Before:

```wat
(module
  (type $unused (sub (struct)))
)
```

After `--type-finalizing`:

- the pass may toggle the type's final/open state if it is private and eligible
- but it does **not** delete the type for being unused

That is `remove-unused-types`, not `type-finalizing`.

## Bailout shape 2: this is not type merging

Before:

```wat
(module
  (type $a (sub (struct (field i32))))
  (type $b (sub (struct (field i32))))
)
```

After `--type-finalizing`:

- the pass may finalize one or both if eligible
- it does **not** merge them into one type

That is `type-merging`, not `type-finalizing`.

## Bailout shape 3: this is not subtype-edge pruning

Before:

```wat
(module
  (rec
    (type $parent (sub (struct)))
    (type $child (sub final $parent (struct)))
  )
)
```

After `--type-finalizing`:

- the parent remains open
- the child may stay or become final
- the subtype edge itself is still there

That is `unsubtyping`, not `type-finalizing`.

## Best beginner summary

If you want one teaching sentence for the whole page, use this:

- `type-finalizing` changes whether safe private heap types are open or final; it does not infer, merge, delete, or reorder them.
