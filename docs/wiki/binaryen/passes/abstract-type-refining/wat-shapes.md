---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./traps-never-happen-exact-casts-and-descriptors.md
  - ./starshine-strategy.md
---

# `abstract-type-refining` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `abstract-type-refining`.
For provenance and local status, pair it with the raw manifest [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md) and the Starshine page [`./starshine-strategy.md`](./starshine-strategy.md).

The easiest way to read these examples is to remember the pass has two different powers:

1. **always-on bottomization** for struct types that are never created and have no created subtypes
2. **TNH-only child refinement** for abstract parents that have a single still-relevant child branch

## Positive shape 1: TNH-only parent-to-child cast refinement

### Input idea

A chain like:

```wat
(type $A (sub (struct)))
(type $B (sub $A (struct)))
(global $g anyref (struct.new $B))

(func (param $x anyref)
  (drop
    (ref.cast (ref $A)
      (local.get $x)
    )
  )
)
```

### `--traps-never-happen` output idea

```wat
(drop
  (ref.cast (ref $B)
    (local.get $x)
  )
)
```

### Why it works

- `$A` is not directly created
- but exactly one relevant child branch exists: `$B`
- TNH lets Binaryen assume the cast cannot fail in the old way, so the only surviving success family is the live child branch

### Non-TNH behavior

Without TNH, the cast target stays `$A`.

## Positive shape 2: TNH-only `ref.test` and `br_on_cast` refinement

The same parent-to-child logic applies to:

- `ref.test`
- `br_on_cast`

So in TNH, checks on abstract `$A` can become checks on live child `$B`.

That is why the main lit file rewrites not just casts, but also:

- `(ref.test (ref $A) ...)` -> `(ref.test (ref $B) ...)`
- `br_on_cast ... (ref $A)` -> `br_on_cast ... (ref $B)`

## Positive shape 3: locals and signatures rewrite too

The pass is not just a cast peephole.
Type uses elsewhere also change.

### Input idea

```wat
(func
  (local $a (ref $A))
  (local $d (ref $D))
)
```

### TNH output idea

```wat
(func
  (local $a (ref $B))
  (local $d (ref $E))
)
```

### Why it works

The pass uses shared type rewriting, so once `$A -> $B` and `$D -> $E` are in the mapping, all remaining type uses can update.

## Positive shape 4: fully never-created family -> bottom

### Input idea

```wat
(type $Dead (sub (struct)))

(func (param $x anyref)
  (drop
    (ref.cast (ref $Dead)
      (local.get $x)
    )
  )
)
```

with no `struct.new $Dead` and no created subtype of `$Dead`.

### Output idea in both TNH and non-TNH

```wat
(drop
  (ref.cast (ref none)
    (local.get $x)
  )
)
```

### Why it works

No runtime value of that family can exist except null in nullable positions.
So Binaryen bottomizes the type even outside TNH.

## Positive shape 5: nullable impossible cast -> null check

### Input idea

```wat
(drop
  (ref.cast (ref null $Dead)
    (local.get $x)
  )
)
```

### Output idea

```wat
(drop
  (ref.cast nullref
    (local.get $x)
  )
)
```

### Why it works

A nullable cast to a never-created family can still succeed for null.
So the pass preserves the null-only success case instead of turning the whole thing into unconditional unreachable.

## Positive shape 6: one live child among multiple declared children

### Input idea

```wat
(type $A (sub (struct)))
(type $B (sub $A (struct)))
(type $B1 (sub $A (struct)))

;; only $B1 is ever created
```

### TNH output idea

```wat
(ref.cast (ref $B1) ...)
```

### Why it works

Even though `$A` has two declared children, only one branch is runtime-relevant.
The pass checks `createdTypesOrSubTypes`, not just raw child count.

## Positive shape 7: chained TNH refinement to the deepest live child

### Input idea

```wat
(type $A (sub (struct)))
(type $B (sub $A (struct)))
(type $C (sub $B (struct)))

;; only $C is created
```

### TNH output idea

```wat
(ref.cast (ref $C) ...)
```

### Why it works

`computeAbstractTypes(...)` walks subtypes first and propagates a child's refinement onward.
So `$A` can refine through `$B` to `$C`.

## Positive shape 8: exact impossible cast -> bottom, not live child

### Input idea

```wat
(ref.cast (ref (exact $Uninstantiated))
  (local.get $x)
)
```

with TNH enabled and a live child `$Instantiated` beneath `$Uninstantiated`.

### Output idea

```wat
(ref.cast (ref none)
  (local.get $x)
)
```

or, if nullable:

```wat
(ref.cast nullref
  (local.get $x)
)
```

### Why it works

Retargeting an exact cast to `$Instantiated` would create new success cases.
So Binaryen preserves the “only fail” or “only null can pass” meaning instead.

## Positive shape 9: side-effectful exact/descriptor cast localization

### Input idea

```wat
(ref.cast_desc_eq (ref (exact $Dead))
  (block (result anyref)
    (call $effect)
    (local.get $ref)
  )
  (block (result (ref null (exact $Dead.desc)))
    (call $effect)
    (global.get $nullable-desc)
  )
)
```

### Output idea

```wat
(local $tmp-ref anyref)
(local $tmp-desc (ref null (exact $Dead.desc)))
(local.set $tmp-ref
  (block (result anyref)
    (call $effect)
    (local.get $ref)
  )
)
(local.set $tmp-desc
  (block (result (ref null (exact $Dead.desc)))
    (call $effect)
    (global.get $nullable-desc)
  )
)
(ref.cast (ref none)
  (local.get $tmp-ref)
)
```

### Why it works

The pass must preserve child effects and order even when the descriptor-sensitive part disappears.
That is why it uses `ChildLocalizer`.

## Positive shape 10: non-TNH nullable descriptor child gets `ref.as_non_null`

### Input idea

A descriptor cast or branch with a nullable descriptor operand outside TNH.

### Output idea

```wat
(local.set $tmp-desc
  (ref.as_non_null
    (local.get $desc)
  )
)
```

before the simplified cast/branch.

### Why it works

The original descriptor operand may null-trap.
Dropping it silently would change semantics.

## Positive shape 11: impossible `struct.new_desc` in functions -> effects then unreachable

### Input idea

```wat
(struct.new_desc $Struct
  (block (result (ref null (exact $DeadDesc)))
    (call $effect)
    (global.get $fake-desc)
  )
)
```

### Output idea

```wat
(drop
  (block (result (ref null (exact $DeadDesc)))
    (call $effect)
    (global.get $fake-desc)
  )
)
(unreachable)
```

### Why it works

The allocation cannot succeed after the descriptor type is optimized away, but child side effects must survive.

## Positive shape 12: impossible `struct.new_desc` in globals -> null descriptor

### Input idea

```wat
(global $g (ref $Struct)
  (struct.new_desc $Struct
    (global.get $fake-desc)
  )
)
```

### Output idea

```wat
(global $g (ref $Struct)
  (struct.new_default_desc $Struct
    (ref.null none)
  )
)
```

### Why it works

In module code Binaryen cannot synthesize ordinary local-temp scaffolding, so it uses a null descriptor instead.

## Positive shape 13: impossible `ref.get_desc` -> drop input then unreachable

### Input idea

```wat
(func (result (ref (exact $B)))
  (ref.get_desc $A
    (struct.new_default_desc $A
      (ref.null none)
    )
  )
)
```

where `$B` is never created.

### Output idea

```wat
(func (result (ref none))
  (drop
    (struct.new_default_desc $A
      (ref.null none)
    )
  )
  (unreachable)
)
```

### Why it works

The old result type no longer validates, and the operation would only trap anyway.
So the pass makes that trap behavior explicit.

## Positive shape 14: inexact `ref.get_desc` with live subtype -> cast to surviving subtype first

### Input idea

```wat
(ref.get_desc $A
  (local.get $inexact)
)
```

where `$A.sub` / `$B.sub` still exist and can be created.

### TNH output idea

```wat
(ref.get_desc $A.sub
  (ref.cast (ref $A.sub)
    (local.get $inexact)
  )
)
```

### Why it works

The operation is not impossible.
It just needs to be narrowed to the one surviving subtype family that can still produce a descriptor.

## Positive shape 15: exact local type bottomization drops exactness

### Input idea

```wat
(local (ref (exact $foo)))
```

with `$foo` never created.

### Output idea

```wat
(local (ref none))
```

### Why it works

Bottom reference types are not expressed as exact custom refs.
The tiny exact regression exists to keep this legal.

## Positive shape 16: continuation-containing rec groups stay coherent

### Input idea

```wat
(rec
  (type $func (func))
  (type $cont (cont $func))
  (type $uncreated (struct))
)
```

### Output idea

The rewritten rec group still preserves:

```wat
(type $cont (cont $func))
```

while the dead struct type disappears or rewrites safely.

### Why it works

The pass uses shared type rewriting, and the continuation regression proves that machinery keeps function/continuation links coherent while optimizing unrelated struct types.

## Bailout shape 1: open world or no GC

### Output behavior

- without GC: pass is a no-op
- without `--closed-world`: pass throws a fatal error

This is a scheduler and invocation boundary, not a WAT rewrite family.

## Bailout shape 2: public types stay effectively created

If a type is public, the pass conservatively treats it as created.
So a public type does not participate in the same abstract-type cleanup even if the module itself never allocates it.

## Bailout shape 3: multiple live child branches

### Input idea

`$A` has children `$B` and `$B1`, and both remain runtime-relevant.

### Output behavior

Even in TNH, the pass leaves casts/tests on `$A` alone.

### Why

There is no unique surviving child branch to refine to.

## Bailout shape 4: basic-type casts stay basic

### Input idea

```wat
(ref.cast (ref struct)
  (local.get $x)
)
```

### Output behavior

Unchanged.

### Why

This pass is about user struct heap types, not basic heap-type casts like `struct`.

## Bailout shape 5: arrays and functions are unsupported today

The pass has an explicit TODO for arrays and functions.
So even though the name sounds generic, the current implementation skips non-struct heap types.

## Bailout shape 6: subtype edges are preserved here

Even if every use of `$A` rewrites to `$B`, the declared subtype graph is not minimized here.
That later cleanup belongs to `unsubtyping`.

## Reading rule of thumb

When you see an `abstract-type-refining` output, ask:

1. Is this a bottomization case or a TNH-only child-refinement case?
2. Is the operation exact or inexact?
3. Is a descriptor operand involved?
4. Are there child side effects or nullable-descriptor traps to preserve?
5. Is the pass only rewriting uses here, with declaration cleanup deferred to `unsubtyping`?

Those five questions explain most of the visible shapes.

## Bottom line

The real WAT surface of `abstract-type-refining` is not just:

- “abstract type becomes child type”

It is a larger source-backed set of families:

- **bottomization, TNH-only child refinement, exact-cast impossibility preservation, descriptor repair, `ref.get_desc` legality repair, impossible allocation cleanup, and shared type-rewrite robustness**.

## Sources

- [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md)
- [`../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
