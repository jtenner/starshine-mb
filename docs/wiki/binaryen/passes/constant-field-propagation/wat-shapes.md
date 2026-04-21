---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./copies-subtypes-ref-tests-and-atomics.md
---

# `constant-field-propagation` WAT and IR shape guide

This page is the beginner-friendly shape catalog for Binaryen `constant-field-propagation`.

The pass name is easy to overread.
The actual question is not:

- “can we simplify this expression?”

The actual question is:

- “for this struct-field read, do all reachable dynamic instances that matter in the closed world agree on one readable value?”

## Reading this page

Each shape below is labeled as one of:

- **positive** = Binaryen usually rewrites it
- **negative** = Binaryen deliberately keeps it
- **bailout** = Binaryen gives up because a correctness boundary prevents a rewrite

All examples are schematic, not exact copies of the official tests.

---

## 1. Never-created type read

**Shape:** positive

```wat
(type $S (struct (field i32)))

(func (local $s (ref null $S))
  (drop
    (struct.get $S 0
      (local.get $s)
    )
  )
)
```

If the module never creates or writes a readable `$S.0` anywhere, Binaryen treats the read as logically impossible in the closed world.

Typical rewrite shape:

```wat
(drop
  (block
    (drop (local.get $s))
    (unreachable)
  )
)
```

Important detail:

- Binaryen keeps side effects in the reference expression by dropping it first.

---

## 2. Default-created field always reads as zero

**Shape:** positive

```wat
(type $S (struct (field i64)))

(func (param $s (ref null $S))
  (drop (struct.new_default $S))
  (drop
    (struct.get $S 0
      (local.get $s)
    )
  )
)
```

Because every observed write to `$S.0` is the default zero value, Binaryen can replace the read with an explicit constant plus a null trap on the reference.

Typical rewrite shape:

```wat
(drop
  (block (result i64)
    (drop (ref.as_non_null (local.get $s)))
    (i64.const 0)
  )
)
```

---

## 3. One literal everywhere

**Shape:** positive

```wat
(type $S (struct (field f32)))

(func (param $s (ref null $S))
  (drop
    (struct.new $S
      (f32.const 42)
    )
  )
  (drop
    (struct.get $S 0
      (local.get $s)
    )
  )
)
```

When all readable evidence for `$S.0` collapses to the same literal, Binaryen emits the same block shape as above with the literal at the end.

---

## 4. One immutable global everywhere

**Shape:** positive

```wat
(global $g i32 (i32.const 42))
(type $S (struct (field i32)))

(func (param $s (ref null $S))
  (drop
    (struct.new $S
      (global.get $g)
    )
  )
  (drop
    (struct.get $S 0
      (local.get $s)
    )
  )
)
```

Binaryen can treat an immutable global as a single readable value.
So the read becomes a block that yields `global.get $g`.

Important contrast:

- if `$g` is mutable, this becomes a negative shape instead.

---

## 5. Mutable global source

**Shape:** negative

```wat
(global $g (mut i32) (i32.const 42))
(type $S (struct (field i32)))

(func (param $s (ref null $S))
  (drop
    (struct.new $S
      (global.get $g)
    )
  )
  (drop
    (struct.get $S 0
      (local.get $s)
    )
  )
)
```

A mutable global is not treated as a compile-time constant source.
So Binaryen leaves the read alone.

Reason:

- the pass can track immutable globals by name
- mutable globals are runtime-varying inputs

---

## 6. Supertype read blocked by subtype disagreement

**Shape:** bailout for plain `cfp`

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32) (field f64))))

(func $create
  (drop (struct.new $A (i32.const 10)))
  (drop (struct.new $B (i32.const 20) (f64.const 3.14)))
)

(func (param $x (ref null $A))
  (drop
    (struct.get $A 0
      (local.get $x)
    )
  )
)
```

A read through `(ref null $A)` may observe either an actual `$A` or an actual `$B`.
Since the two disagree, plain `cfp` cannot replace the read with one value.

Important note:

- this exact family may become a **positive** only under the stricter `cfp-reftest` variant when the subtype split is simple enough.

---

## 7. Subtype read still constant

**Shape:** positive

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32) (field f64))))

(func $create
  (drop (struct.new $A (i32.const 10)))
  (drop (struct.new $B (i32.const 20) (f64.const 3.14)))
)

(func (param $x (ref null $B))
  (drop
    (struct.get $B 0
      (local.get $x)
    )
  )
)
```

Now the read is through the subtype reference.
If all actual `$B` instances agree on field `0`, Binaryen can still optimize the read even though the supertype world is mixed.

This is one of the clearest examples of why exact type view matters.

---

## 8. Field-to-field copy chain

**Shape:** positive if the copy source is stable

```wat
(type $A (struct (field i32)))
(type $B (struct (field i32)))

(func
  (local $a (ref $A))
  (local $b (ref $B))
  (struct.set $B 0
    (local.get $b)
    (struct.get $A 0
      (local.get $a)
    )
  )
  (drop
    (struct.get $B 0
      (local.get $b)
    )
  )
)
```

If `$A.0` is always the same readable value, Binaryen's copy fixed point may infer that `$B.0` is also always that value.

This is a core official shape family.
It is why the pass needs more than one hierarchy propagation sweep.

---

## 9. Packed unsigned read

**Shape:** positive with repair

```wat
(type $A_8 (struct (field i8)))

(drop
  (struct.get_u $A_8 0
    (struct.new $A_8
      (i32.const 0x12345678)
    )
  )
)
```

Binaryen can optimize this, but not by yielding the raw original constant.
It must preserve packing semantics.

Typical rewrite idea:

```wat
(block (result i32)
  (drop (ref.as_non_null ...))
  (i32.and (i32.const 0x12345678) (i32.const 255))
)
```

So packed-field positives are really “positive with masking/sign-extension repair.”

---

## 10. Packed immutable-global source

**Shape:** often bailout

```wat
(import "a" "b" (global $g i32))
(type $A_16 (struct (field i16)))

(drop
  (struct.get_u $A_16 0
    (struct.new $A_16
      (global.get $g)
    )
  )
)
```

Even if the global is the only source, Binaryen cannot always track “that global, but masked later” in the current value domain.
So these shapes often degrade to unknown.

This is an official source-backed limitation, not just a missing optimization in the wiki.

---

## 11. Ordered atomic read with a constant field

**Shape:** bailout

```wat
(type $Shared (struct (field (mut i32))))

(func (param $x (ref $Shared))
  (drop
    (struct.atomic.get acqrel $Shared 0
      (local.get $x)
    )
  )
)
```

Even if the field appears constant, Binaryen keeps ordered atomic reads.

Reason:

- the analysis does not prove that removing the read preserves synchronization behavior

So successful ordered atomic reads are a deliberate non-goal.

---

## 12. Ordered atomic read that is known to trap

**Shape:** positive

```wat
(type $Never (struct (field i32)))

(func (param $x (ref $Never))
  (drop
    (struct.atomic.get acqrel $Never 0
      (local.get $x)
    )
  )
)
```

If the field is known never to be written or created in the closed world, the read is known to trap.
Binaryen can still turn it into `drop(ref); unreachable`.

Reason:

- trapping accesses do not synchronize, so preserving the trap is enough

This is one of the most important atomic subtleties in the pass.

---

## 13. `cfp-reftest`-only two-value split

**Shape:** positive only in `cfp-reftest`

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32))))
(type $C (sub $A (struct (field i32))))

;; B instances always hold 10 in field 0
;; C instances always hold 20 in field 0

(func (param $x (ref null $A))
  (drop
    (struct.get $A 0
      (local.get $x)
    )
  )
)
```

Plain `cfp` leaves this alone.
`cfp-reftest` may replace it with a `select` guarded by `ref.test` if one bucket is representable by a single testable subtype.

Important point:

- this is a sibling-variant feature, not normal `cfp` behavior

---

## 14. Array-of-struct realistic itable shape

**Shape:** mixed / partial positive

```wat
(type $VTable (struct (field funcref)))
(type $ITable (array (ref $VTable)))
(type $Object (struct (field (ref $ITable))))
(global $g (ref $ITable) ...)

(struct.get $VTable 0
  (array.get $ITable
    (struct.get $Object 0
      (local.get $obj)
    )
    (i32.const 1)
  )
)
```

Binaryen may not optimize the whole nested expression at once.
But `cfp` can still simplify the inner object-field read into a `global.get`, which makes the surrounding expression easier for later passes such as precompute-style logic.

This is a good reminder that some pass wins are staging wins, not final-form wins.

---

## 15. Child field type too narrow for the inferred parent value

**Shape:** positive, but to explicit unreachable rather than a constant

Suppose the analysis infers a parent field can only hold some constant/global, but on a more refined child type that value would not actually be a subtype of the child field type.

Binaryen does **not** emit invalid wasm.
Instead it rewrites the replacement into an explicit unreachable path after dropping the impossible value.

This is a correctness repair, not a fallback bug.

---

## 16. What the pass does not try to do

These are all non-goals in the reviewed sources:

- generic local/value constant propagation
- tracking individual object lifetimes precisely
- optimizing mutable-global sources as compile-time constants
- broad atomic synchronization reasoning
- arbitrary multi-way subtype dispatch synthesis
- field-type refinement

## Quick mental checklist for future work

When evaluating a candidate `cfp` shape, ask:

1. Is this a struct-field read at all?
2. Are we in closed world with GC?
3. Are we reading through an exact or inexact reference?
4. Do all readable dynamic instances agree on one value?
5. If not, is this the narrow two-value `cfp-reftest` case?
6. Are copies, packing, subtype refinements, or atomics changing the answer?
7. Will the replacement preserve null traps, validation, and synchronization boundaries?

If any of those answers are unclear, the shape is probably a bailout or needs a repair step.

## Sources

- [`../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md`](../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
