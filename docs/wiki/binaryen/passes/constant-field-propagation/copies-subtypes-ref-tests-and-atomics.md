---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md
  - ../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `constant-field-propagation`: copies, subtypes, `ref.test`, and atomics

This page covers the part of Binaryen `constant-field-propagation` that is easiest to misunderstand:

- why exact and inexact references must be tracked separately
- why copied field values force a real fixed point
- what `cfp-reftest` actually adds
- why atomics split into “ordered-read bailout” versus “known-trap rewrite” cases

## 1. Exact and inexact references are not interchangeable

Suppose a module has:

```wat
(type $A (sub (struct (field i32))))
(type $B (sub $A (struct (field i32) (field i32))))
```

Now compare these write sites:

```wat
(struct.set $A 0
  (local.get $a-inexact)   ;; (ref $A)
  (i32.const 10)
)
```

and

```wat
(struct.set $A 0
  (local.get $a-exact)     ;; (ref (exact $A))
  (i32.const 10)
)
```

The first write may hit:

- an actual `$A`
- or an actual `$B`

The second write may hit only:

- an actual exact `$A`

That is why Binaryen keys the main maps by:

- heap type
- exactness
- field index

A future port must preserve that split.
If you collapse exact and inexact traffic together, subtype positives and subtype bailouts will both go wrong.

## 2. Reads and writes move through the hierarchy in opposite directions

The source comments in `ConstantFieldPropagation.cpp` explain the directionality.

### Writes go down

If a write is performed through `(ref $A)`, a subtype instance may receive it.
So written values must propagate **downward** to subtypes.

### Reads go up

If a read is performed through `(ref $A)`, the dynamic value may actually be some subtype instance.
So readable values must propagate **upward** to supertypes.

That asymmetry is the heart of the pass.

It also explains an easy beginner surprise:

- a subtype disagreement can block a supertype read even when the supertype's own direct constructor writes look constant.

## 3. Copies create a real cycle in the dataflow

A copied field value looks like this at a high level:

```wat
(struct.set $Dst 0
  (local.get $dst)
  (struct.get $Src 1
    (local.get $src)
  )
)
```

If `$Src.1` is always `42`, then `$Dst.0` may also become `42`.
But that means:

- readable facts about `$Src.1`
- affect written facts about `$Dst.0`
- which then affect readable facts about `$Dst.0`
- which may feed even more copies

So Binaryen cannot do only one hierarchy propagation pass.
It needs a queue and a fixed point.

## 4. The fixed point is about copied reads, not generic symbolic execution

This is important.
The pass is **not** solving arbitrary expression equations.
It is solving a much smaller problem:

- a field read is copied into another field write

That narrow scope is why the algorithm remains practical.

The work queue stores destinations whose written facts changed because of copied readable values.
Then Binaryen re-runs the relevant hierarchy propagation around those destinations until nothing else changes.

So the fixed point is real, but it is still tightly bounded to field-copy traffic.

## 5. Packed fields complicate copies

Now consider a packed field:

```wat
(type $A_8 (struct (field i8)))
```

and a write like:

```wat
(struct.new $A_8
  (i32.const 0x12345678)
)
```

A later unsigned read of field `0` is not the original `0x12345678`.
It is effectively:

```wat
(i32.and (i32.const 0x12345678) (i32.const 255))
```

And a signed read would instead sign-extend.

That is why the copy logic explicitly packs values for fields before using them as readable facts.

### Important limitation

If the tracked single value is an immutable global, Binaryen cannot currently represent:

- “that global, but masked/sign-extended later”

inside `PossibleConstantValues`.
So some packed+global shapes intentionally become unknown.

That is a real source-backed boundary.

## 6. `cfp-reftest` is narrower than it sounds

Plain `cfp` tracks one constant or global, otherwise unknown.

`cfp-reftest` adds one extra idea:

- if exactly two constant buckets exist,
- and one bucket can be separated by a single cheap-enough subtype test,
- replace the read with a `select` guarded by `ref.test`

A beginner might think this means “if there are two values, emit a test.”
That is not what the code does.

Binaryen requires more.

### The source-backed conditions are intentionally strict

The reviewed code requires, in practice:

- the ordinary constant path must have failed
- the read reference must be inexact
- created concrete types under the relevant supertype must collapse to exactly two constant values
- one bucket must be represented by exactly one subtype
- that subtype must have no further subtypes, so the test is a simple closed/final-ish discriminator

If those conditions fail, `cfp-reftest` gives up.

So the better explanation is:

- `cfp-reftest` is a conservative two-bucket subtype classifier, not a generic multi-way type switch synthesizer.

## 7. Why the pass cares about created concrete types

The `ref.test` path ignores abstract subtypes with no allocations.
That is deliberate.

If a type under the hierarchy is never actually created, it does not contribute a readable runtime value for the field.
So the analysis can skip it when forming the two buckets.

This is another place where the pass is more semantic than it first appears:

- it is not only traversing declared types
- it also cares whether those types ever contribute concrete runtime instances

## 8. The pass is type-level, not object-flow-sensitive

The lit tests explicitly cover the surprising rule that even a dropped allocation can contribute evidence.

For example:

```wat
(drop
  (struct.new $S
    (i32.const 42)
  )
)
```

can still justify later replacement of:

```wat
(struct.get $S 0
  (local.get $s)
)
```

if no conflicting writes exist.

That feels strange only if you imagine the pass is tracking the lifetime of individual objects.
It is not.
It is tracking what values instances of a type may contain in the closed world.

## 9. Atomics split into two different semantic cases

This is one of the most important beginner traps.

### Case A: ordered atomic read with a known constant value

Even if the field value looks constant, Binaryen does **not** replace ordered atomic reads such as:

```wat
(struct.atomic.get acqrel $T 0
  (local.get $x)
)
```

Why?
Because the current analysis cannot prove that removing the read would preserve synchronization behavior.
A constant field value is not enough.

So ordered atomic reads are a bailout.

### Case B: known-trapping read from a never-written field

Now consider a field that was never written at all in the closed world.
The read is known to trap regardless.
In that case Binaryen can replace even atomic reads with:

```wat
(block
  (drop (local.get $x))
  (unreachable)
)
```

The source comments explicitly justify this by saying trapping accesses do not synchronize.

So the atomic rule is not “atomics are off limits.”
It is:

- **ordered successful reads are off limits, but known-trapping reads are still fair game.**

## 10. `ref.get_desc` has one extra nullability wrinkle

`ref.get_desc` behaves like a field read for optimization purposes, but it has a twist:

- some writes can involve nullable values that would trap before a successful read could ever observe null

So after replacing a `ref.get_desc`, Binaryen may need an extra `ref.as_non_null` fixup to keep the resulting read type valid.

That is why descriptor reads deserve explicit mention in the dossier instead of being lumped under “same as `struct.get`.”

## 11. How nearby passes change the payoff

The `gto_and_cfp_in_O.wast` test shows the practical payoff chain.

### Before earlier closed-world cleanup

A field may look non-constant because:

- a now-unneeded helper function is still alive through a `ref.func`
- an unread field is still present in the type
- a later `struct.set` still exists only because that field still exists

### After earlier cleanup

Once passes like:

- `gto`
- `remove-unused-module-elements`
- `remove-unused-types`

have done their work, `cfp` may see a much cleaner field world.

So `cfp` is a payoff pass as much as it is an analysis pass.
Its real opportunities depend strongly on the earlier closed-world cleanup cluster.

## 12. The safest one-sentence explanation of the hard part

The best compact explanation of the hard part of `constant-field-propagation` is:

- **Binaryen treats struct-field constants as a subtype-aware, exactness-aware, copy-aware closed-world dataflow problem, then rewrites reads only when the resulting runtime behavior still preserves traps, packing, and synchronization boundaries.**

## Sources

- [`../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md)
- [`../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md`](../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md`](../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
