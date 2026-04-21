---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./permutations-brands-and-public-conflicts.md
---

# `minimize-rec-groups` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `minimize-rec-groups`.

The easiest way to read these examples is to remember that the pass owns **module type-section shapes**, not function-body optimization shapes.

It has two big jobs:

1. split private heap types into the smallest SCC-based rec groups that validation requires
2. keep those new groups distinct from one another and from public groups, using permutations first and brands when necessary

## Positive shape 1: no heap types -> no-op

### Input idea

```wat
(module
  (global $g i32 (i32.const 0))
)
```

### Output idea

Unchanged.

### Why it works

There are no heap types, so there are no rec groups to minimize.

## Positive shape 2: one heap type -> no-op

### Input idea

```wat
(module
  (type $t (struct))
  (global $g (ref null $t) (ref.null none))
)
```

### Output idea

Unchanged.

### Why it works

There is only one type and no collision to resolve.

## Positive shape 3: one source rec group with independent members splits apart

### Input idea

```wat
(module
  (rec
    (type $a (struct (field i32)))
    (type $b (struct (field i64)))
    (type $c (struct (field f32)))
  )
)
```

### Output idea

```wat
(type $a (struct (field i32)))
(type $b (struct (field i64)))
(type $c (struct (field f32)))
```

### Why it works

There is no mutual recursion at all.
So each private type is its own SCC and can become its own singleton group.

## Positive shape 4: an acyclic chain inside one source rec group splits into ordered singletons

### Input idea

```wat
(module
  (rec
    (type $a (struct))
    (type $b (struct (field (ref $a))))
    (type $c (struct (field (ref $b))))
  )
)
```

### Output idea

```wat
(type $a (struct))
(type $b (struct (field (ref $a))))
(type $c (struct (field (ref $b))))
```

### Why it works

The three types are not mutually recursive.
They only form a forward dependency chain, so SCC minimization splits them.

## Positive shape 5: source order can be repaired

### Input idea

The same chain as above, but written backward in the source rec group.

### Output idea

Binaryen still emits the valid order:

```wat
(type $a ...)
(type $b ...)
(type $c ...)
```

### Why it works

The pass does not trust source order.
It rebuilds a valid order using supertype and descriptor dependency edges.

## Positive shape 6: a true cycle stays in one rec group

### Input idea

```wat
(module
  (rec
    (type $a (struct (field (ref $b))))
    (type $b (struct (field (ref $c))))
    (type $c (struct (field (ref $a))))
  )
)
```

### Output idea

Still one `(rec ...)`.

### Why it works

All three types are in the same SCC.
The minimization target is the SCC boundary, not “singletonize everything.”

## Positive shape 7: only the mutually recursive subset stays grouped

### Input idea

```wat
(module
  (rec
    (type $a (struct (field (ref $b))))
    (type $b (struct (field (ref $a))))
    (type $c (struct (field (ref $a))))
  )
)
```

### Output idea

```wat
(rec
  (type $b ...)
  (type $a ...)
)
(type $c ...)
```

### Why it works

`$a` and `$b` are mutually recursive.
`$c` only depends on them.
So `$c` can split off.

## Positive shape 8: same-shape singleton groups need a brand when no permutation exists

### Input idea

```wat
(module
  (rec
    (type $a (func))
    (type $b (func))
  )
)
```

### Output idea

Conceptually:

```wat
(type $a (func))
(rec
  (type $brand (struct))
  (type $b (func))
)
```

### Why it works

Two singleton `func` groups have the same shape.
A singleton has no interesting reorderings, so the only way to keep `$a` and `$b` distinct is to add a brand.

## Positive shape 9: the initial brand may itself collide, so Binaryen skips ahead

### Input idea

Two singleton structs with the same shape.

### Output idea

Binaryen may choose a later brand such as an `array (mut i8)` instead of a tiny struct brand.

### Why it works

The pass checks whether the proposed brand would still make the branded group look identical to the real singleton type.
If yes, it advances to the next brand.

## Positive shape 10: some same-shape multi-type SCCs can be separated by permutation alone

### Input idea

Two isomorphic two-type SCCs where the ordering constraints still leave multiple valid topological orders.

### Output idea

One group may emit as:

```wat
(rec
  (type $b1 ...)
  (type $a1 ...)
)
```

while another emits as:

```wat
(rec
  (type $a2 ...)
  (type $b2 ...)
)
```

### Why it works

The groups are still distinct under shape comparison once a different valid order is chosen.
No brand is needed yet.

## Positive shape 11: extra groups can reuse the same brand with different permutations

### Input idea

Several duplicate-shape groups from the same equivalence class.

### Output idea

Binaryen can keep one chosen brand but still produce different final group shapes by pairing that brand with different valid permutations.

### Why it works

Brands and permutations are not exclusive.
The pass can reuse a brand while still exploring fresh legal orders.

## Positive shape 12: when permutations run out, Binaryen advances to the next brand

### Input idea

More duplicate-shape groups than there are distinct valid-shape permutations under the current brand.

### Output idea

Later groups gain newer brands such as:

```wat
(type $1 (array (mut i8)))
(type $5 (array i8))
(type $6 (struct ...))
```

### Why it works

The class has exhausted its usable distinct shapes, so the next compact brand is required.

## Positive shape 13: previous-SCC references can still participate in branded groups

### Input idea

A later singleton or SCC references an earlier already-split group.

### Output idea

Binaryen still brands or permutes only the local conflicting group while preserving the external reference to the earlier SCC.

### Why it works

The pass rewrites the whole module after rebuilding the new rec groups, so previous-SCC references stay consistent.

## Positive shape 14: public conflicts are resolved only on the private side

### Input idea

```wat
(module
  (type $public (struct))
  (global $public (export "g") (ref null $public) (ref.null none))
  (rec
    (type $private (struct))
    (type $other (struct (field (ref null $private))))
  )
)
```

### Output idea

The public type stays untouched, and the private side gains a brand if needed.

### Why it works

Public groups are immutable collision targets.
The pass must change the private group instead.

## Positive shape 15: descriptor/described chains stay together and ordered

### Input idea

```wat
(module
  (rec
    (type $a (descriptor $a.desc) (struct))
    (type $a.desc (describes $a) (struct))
  )
)
```

### Output idea

Still one rec group, with:

- `$a` before `$a.desc`

### Why it works

Described types and descriptors belong to the same SCC, and the order graph forces described-before-descriptor.

## Positive shape 16: descriptor-heavy SCCs sometimes can still avoid a brand

### Input idea

A descriptor/described chain plus an extra reorderable helper type.

### Output idea

Binaryen may choose a different valid topological order and avoid a brand.

### Why it works

The extra type creates more legal orders without violating the described-before-descriptor rule.

## Positive shape 17: exactness can keep public shapes distinct

### Input idea

```wat
(module
  (type $foo (struct))
  (type $exact (struct (field (ref (exact $foo)))))
  (type $inexact (struct (field (ref $foo))))
  (import "" "exact" (global $exact (ref null $exact)))
  (import "" "inexact" (global $inexact (ref null $inexact)))
)
```

### Output idea

No collision between the public shapes.

### Why it works

With the relevant features enabled, exactness is part of the written shape.
So the two public groups are distinct.

## Positive shape 18: exactness can stop mattering under a different feature set

### Input idea

The same exact-vs-inexact SCC pair as above, but with custom descriptors disabled.

### Output idea

The once-distinct groups can now collide, and the exact group may need a brand.

### Why it works

`RecGroupShape` compares types as written under the active features.
When the feature set erases exactness, shape comparison erases that distinction too.

## Bailout shape 1: no GC

### Output behavior

No rewrite at all.

This is a scheduler and feature boundary, not a WAT rewrite family.

## Bailout shape 2: public groups are not rewritten

Even when a public group has a conflicting shape, the pass never mutates the public side.

## Bailout shape 3: automorphisms can defeat permutation-only disambiguation

### Input idea

A highly symmetric SCC where different legal orders still produce the same shape.

### Output behavior

Binaryen inserts a brand.

### Why

Those orders are automorphism-equivalent, so permutations do not buy a new shape.

## Bailout shape 4: subtype constraints can leave only one valid order

### Input idea

An SCC whose subtype edges force one topological order.

### Output behavior

Binaryen inserts a brand if another same-shape group already exists.

### Why

There is nothing else to permute.

## Bailout shape 5: this is not dead-type removal

A group can remain fully live yet still be split or branded.
The pass is about rec-group partitioning and identity preservation, not liveness.

## Bailout shape 6: this is not `reorder-types`

A successful `minimize-rec-groups` run may reorder members of an SCC, but only as part of disambiguation and only within validation constraints.
It is not a frequency sorter.

## Reading rule of thumb

When you see a surprising `minimize-rec-groups` output, ask:

1. What are the private SCCs here?
2. Which groups collide by written shape?
3. Are there multiple **valid** orders once subtype and descriptor rules are enforced?
4. Do those valid orders actually differ in shape under the active features?
5. If not, which compact brand did Binaryen pick next?

Those five questions explain most of the visible shapes.

## Bottom line

The real WAT surface of `minimize-rec-groups` is not just:

- “oversized rec group becomes smaller rec groups”

It is a larger source-backed set of families:

- **SCC splitting, valid-order repair, permutation-based disambiguation, brand fallback, descriptor-order constraints, public-shape conflicts, and feature-sensitive exactness toggles**.

## Sources

- [`../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-shape.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-type-shape.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
