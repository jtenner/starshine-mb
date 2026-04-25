---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md
  - ../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md
  - ../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md
  - ../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md
  - ./index.md
  - ./binaryen-strategy.md
related:
  - ./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md
  - ./starshine-strategy.md
  - ../constant-field-propagation/wat-shapes.md
  - ../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md
---

# WAT shapes for `constant-field-null-test-folding` / `cfp-reftest`

This page focuses on the *variant-only* shape families.
For ordinary CFP shapes like one-bucket constant replacement, packed-field repair, and atomic bailouts, keep using the parent [`constant-field-propagation`](../constant-field-propagation/index.md) dossier too.

## Reading rule

Ask these questions in order:

1. Is the ordinary CFP analysis even in scope? (`--closed-world`, GC, struct fields)
2. Would plain CFP already replace this read with one value?
3. If not, are there **exactly two** surviving value buckets?
4. Can one legal `ref.test` distinguish those two buckets?
5. Are the payloads still legal CFP replacement values?
6. Do the ordinary CFP safety boundaries and final `ref.test` / `select` validation rules still permit rewriting?

If any answer is “no,” this variant leaves the read alone.

---

## 1. Positive: two subtype populations, two constants, one clean discriminator

**Shape:** canonical variant-only positive

```wat
(type $base (sub (struct (field (mut i32)))))
(type $left (sub $base (struct (field (mut i32)))))
(type $right (sub $base (struct (field (mut i32)))))

(func $read (param $x (ref null $base)) (result i32)
  (struct.get $base 0 (local.get $x)))
```

Assume the closed-world field analysis proves:

- instances of `$left` always carry `11` in field `0`
- instances of `$right` always carry `22` in field `0`
- one `ref.test` can distinguish the `$left` population from the other side

Then Binaryen may replace the read with logic equivalent to:

```wat
(select
  (i32.const 11)
  (i32.const 22)
  (ref.test (ref $left) (local.get $x)))
```

Why it works:

- exactly two buckets exist
- one subtype test isolates one bucket
- the payloads are still legal CFP replacement values

---

## 2. Positive: one side is an immutable global instead of a literal

**Shape:** still variant-positive

```wat
(global $g i32 (i32.const 99))
(func $read (param $x (ref null $base)) (result i32)
  (struct.get $base 0 (local.get $x)))
```

If the proven buckets are:

- subtype A => `global.get $g`
- other side => `i32.const 0`

then the same two-bucket logic can still work.

Important beginner note:

- the pass is not limited to literal-versus-literal splits
- it inherits CFP's “one immutable global” payload form too

---

## 3. Positive: null-trap behavior must still be preserved

**Shape:** legal positive, but trap semantics still matter

```wat
(func $read (param $x (ref null $base)) (result i32)
  (struct.get $base 0 (local.get $x)))
```

If the original read would trap on `null`, the rewritten form must preserve that observable behavior.
The variant cannot silently turn a trapping read into a trap-free constant expression.

So the safe teaching rule is:

- the variant replaces the **successful-read payload logic**
- it does not discard the original null-trap contract

---

## 4. Negative: plain CFP already wins with one bucket

**Shape:** not a variant-only case

```wat
(func $read (param $x (ref null $base)) (result i32)
  (struct.get $base 0 (local.get $x)))
```

If all reachable dynamic instances already agree on one value, plain CFP handles it.
`cfp-reftest` does not need to synthesize a `ref.test`.

This is important because beginners often over-attribute plain CFP wins to the variant.

---

## 5. Negative: three or more buckets

**Shape:** bailout

```wat
;; field analysis finds 11, 22, and 33 as possible values
```

Even if one subtype test could separate one side from the others, the variant does not keep building nested tests.
It is not a generic decision-tree synthesizer.

Safe rule:

- more than two buckets => no variant rewrite

---

## 6. Negative: two buckets, but no one clean subtype discriminator

**Shape:** bailout

```wat
;; two values exist, but the runtime type graph does not permit one legal ref.test
;; that exactly matches the field-value partition
```

This is the most important conceptual bailout.
Two buckets are necessary but not sufficient.
The pass also needs one heap-type test that matches the value split.

---

## 7. Negative: exact references or already-known dynamic type

**Shape:** usually no variant benefit

```wat
(func $read (param $x (ref $left)) (result i32)
  (struct.get $left 0 (local.get $x)))
```

If the dynamic uncertainty the variant needs is gone, there is no reason to synthesize a discriminating `ref.test`.
Either plain CFP replaces the read directly or the code stays as-is.

---

## 8. Negative: atomic ordered reads

**Shape:** inherited CFP bailout

```wat
;; conceptual family: ordered atomic field access path still blocks rewrite
```

The ordinary CFP dossier already records that ordered atomic reads are a hard safety boundary.
The variant does not loosen that rule.

So even when the two-bucket subtype split looks tempting:

- ordered atomic boundary => no rewrite

---

## 9. Negative: payload not representable in CFP's tiny value domain

**Shape:** bailout

```wat
;; one or both buckets are not legal as plain CFP replacement payloads
```

Because the variant still inherits CFP's replacement lattice, it cannot emit arbitrary computed payloads.
If one side is not representable as:

- one literal constant
- or one immutable global

then the variant gives up.

---

## 10. Negative: generic null-test or cast simplification wishful thinking

**Shape:** out of scope

```wat
(ref.test (ref $left) (local.get $x))
```

On its own, this is **not** a `constant-field-null-test-folding` opportunity.
The pass is not a general optimizer for existing `ref.test` expressions.

It only synthesizes a new test when the field-read analysis proves the narrow two-bucket CFP variant shape.

---

## 11. Practical contrast with plain CFP

Use this quick contrast:

- **plain CFP:** “all reachable dynamic instances agree on one field value”
- **`cfp-reftest`:** “there are exactly two field values, and one subtype test distinguishes which one applies”

That contrast is usually the fastest way to keep the family understandable.

---

## 12. Porting checklist

A future Starshine port should keep this mental checklist and the current local status page in [`./starshine-strategy.md`](./starshine-strategy.md):

1. inherit ordinary CFP gates and facts first
2. do not invent a standalone null-test peephole pass
3. require exactly two buckets
4. require one clean `ref.test` discriminator
5. preserve trap, packing, and atomic boundaries
6. leave multi-bucket or ambiguous cases untouched

## Sources

- [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md)
- [`../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`](../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md)
- [`../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md`](../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md)
- [`../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`](../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md)
- [`./index.md`](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`../constant-field-propagation/wat-shapes.md`](../constant-field-propagation/wat-shapes.md)
- [`../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`](../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
