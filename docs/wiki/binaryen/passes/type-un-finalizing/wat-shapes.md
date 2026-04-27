---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0193-2026-04-21-type-un-finalizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `type-unfinalizing` WAT shapes

This pass is more **module-shape-driven** than expression-shape-driven.
So the examples here focus on type declarations and the places that mention them.

## Reading note

The examples are beginner-friendly sketches of the shapes Binaryen's official lit file proves.
They are meant to teach the contract, not reproduce the full test file verbatim.
For local status and future-port code locations, read [`./starshine-strategy.md`](./starshine-strategy.md). For the future implementation validation matrix, read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Positive shape 1: private final leaf becomes open

Before:

```wat
(module
  (type $leaf (sub final (struct (field i32))))
)
```

After `--type-unfinalizing`:

```wat
(module
  (type $leaf (sub (struct (field i32))))
)
```

Why it changes:

- the type is private
- the sibling is reopening private types

## Positive shape 2: private final parent may reopen too

Before:

```wat
(module
  (rec
    (type $parent (sub final (struct)))
    (type $child (sub final $parent (struct)))
  )
)
```

After `--type-unfinalizing`:

```wat
(module
  (rec
    (type $parent (sub (struct)))
    (type $child (sub $parent (struct)))
  )
)
```

Why it matters:

- this sibling does **not** require the leaf-only proof used by `type-finalizing`
- reopening a private parent is legal even when it has children

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
  (type $leaf (sub final (struct (field i32))))
  (global (ref null $leaf) (ref.null $leaf))
  (func
    (local (ref $leaf))
  )
)
```

After `--type-unfinalizing`, the rewritten module stays coherent because Binaryen updates the type graph through the global helper.

Beginner point:

- the pass is not just changing the `type` line and hoping everything else still works

## Preserved shape 1: public type stays unchanged

Before:

```wat
(module
  (type $public (sub final (struct (field i32))))
  (global $g (ref null $public) (ref.null $public))
  (export "g" (global $g))
)
```

After `--type-unfinalizing`:

```wat
(module
  (type $public (sub final (struct (field i32))))
  ...
)
```

Why it stays:

- public types are outside the pass's modification set

## Preserved shape 2: no GC means no rewrite

If the module does not use GC heap types, the pass does nothing.

That is a hard gate, not a profitability choice.

## Bailout shape 1: this is not type deletion

Before:

```wat
(module
  (type $unused (sub final (struct)))
)
```

After `--type-unfinalizing`:

- the pass may reopen the type if it is private
- but it does **not** delete the type for being unused

That is `remove-unused-types`, not `type-unfinalizing`.

## Bailout shape 2: this is not type merging

Before:

```wat
(module
  (type $a (sub final (struct (field i32))))
  (type $b (sub final (struct (field i32))))
)
```

After `--type-unfinalizing`:

- the pass may reopen one or both if private
- it does **not** merge them into one type

That is `type-merging`, not `type-unfinalizing`.

## Bailout shape 3: this is not subtype-edge pruning

Before:

```wat
(module
  (rec
    (type $parent (sub final (struct)))
    (type $child (sub final $parent (struct)))
  )
)
```

After `--type-unfinalizing`:

- the parent and child may become open
- the subtype edge itself is still there

That is `unsubtyping`, not `type-unfinalizing`.

## Starshine implementation caveat

Current Starshine does not perform any of these rewrites. The local registry keeps only the boundary-only alias `type-un-finalizing`, and direct requests reject before any HOT or module pass can run. Treat these WAT shapes as the Binaryen oracle and future-port target, not as current Starshine output. Before moving the pass out of boundary-only status, use the checklist in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) to cover no-GC, public-type, private non-leaf, function-heap-type, reference-repair, and binary-roundtrip lanes.

## Best beginner summary

If you want one teaching sentence for the whole page, use this:

- `type-unfinalizing` changes whether private heap types are open; it does not infer, merge, delete, or reorder them.
