---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md
  - ../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md
---

# Two-bucket subtype partitions and nonnullable `ref.test` gates in `constant-field-null-test-folding` / `cfp-reftest`

This page covers the exact part of the pass that was easiest to hand-wave in the first dossier:

- how Binaryen proves that a field read has **exactly two** usable outcomes,
- how it proves that **one subtype test** separates those outcomes,
- and why nullable inputs can force an extra `ref.as_non_null` plus a feature-sensitive bailout.

If you remember only one sentence, use this one:

> `cfp-reftest` is not “null-test folding”; it is a tiny CFP rescue path that rewrites one field read to `select(..., ..., ref.test(...))` only when two provable value buckets line up with one subtype partition.

## The exact decision ladder

The reviewed `ConstantFieldPropagation.cpp` logic is much stricter than the pass name suggests.
A good beginner reading order is:

1. ordinary CFP must already be in scope
2. ordinary single-bucket replacement must have failed
3. the tracked field summary must contain **exactly two** possible values
4. each side must correspond to exactly one classifier type bucket
5. one type must be a subtype of the other
6. the two payloads must still live inside CFP's tiny replacement lattice
7. if the base is nullable, Binaryen may need `ref.as_non_null`
8. if that would require nonnullable-type `ref.test` support the module lacks, Binaryen bails out
9. otherwise Binaryen emits a `select` over the two payloads and the synthesized `ref.test`

If any one step fails, the variant does nothing.

## Step 1: this is downstream of ordinary CFP, not a local peephole

The pass does **not** begin from syntax like:

```wat
(struct.get $base 0 (local.get $x))
```

and then locally search for a nearby test.

Instead it begins from the full ordinary CFP machinery:

- closed-world + GC gating
- struct field write/default scanning
- exact-vs-inexact propagation through the type hierarchy
- copy fixed-point solving
- ordinary single-bucket replacement attempts

So the variant is best thought of as:

- **one extra late matcher inside CFP**
- not a freestanding optimization family

## Step 2: the value summary must have exactly two buckets

The first source-confirmed hard gate inside `optimizeUsingRefTest(...)` is:

- `values.values.size() == 2`

That means the pass is intentionally tiny.
It does **not** handle:

- one bucket: plain CFP already owns that
- three or more buckets: out of scope
- arbitrary “small” numbers of possibilities: also out of scope

This is the first place where the local name becomes misleading.
The pass is not hunting generic null tests; it is hunting one exact-two-way classification problem.

## Step 3: each bucket must correspond to one usable classifier type set

Binaryen then asks what dynamic heap types can produce each bucket's value.
The matcher rejects cases where a side still corresponds to more than one classifier type bucket.

So the pass wants something closer to this:

- bucket A comes from one coherent subtype side
- bucket B comes from one coherent sibling/supertype side

and **not** something like this:

- bucket A can arise from several unrelated dynamic populations
- bucket B is just “everything else” in a fuzzy sense

This is why the pass is small even inside the two-bucket space.

## Step 4: the proof is a subtype partition

Once the classifier buckets are small enough, Binaryen checks whether one side is a subtype of the other.
That lets the pass choose a discriminating type `T` such that:

- `ref.test T` means “take payload A”
- otherwise take payload B

This is the real heart of the pass.
The proof is:

- one heap-type test partitions the same runtime population split that the field-value analysis already discovered.

That is very different from the broad reading suggested by the local name.
It is not just:

- null versus non-null
- two different constants
- any handy branch condition nearby

It is one **type partition** lining up with one **field-value partition**.

## Step 5: the payloads still come from CFP's tiny value lattice

Even after the pass finds a valid classifier, it still cannot emit arbitrary values.
The chosen then/else payloads must remain legal CFP replacement values.
That means the variant inherits the same tiny value domain as plain CFP:

- literal constants
- immutable globals
- or unknown

So the variant widens the **chooser**, not the **payload domain**.
That distinction matters for ports.

## Step 6: nullable bases may force `ref.as_non_null`

One of the most important source-confirmed details is how Binaryen handles nullable bases.
Sometimes the pass wants to test a nonnullable reference type even though the original read base is nullable.
In that case it may synthesize something conceptually like:

```wat
(ref.test (ref $sub)
  (ref.as_non_null (local.get $x)))
```

That is not cosmetic.
It is part of how the pass keeps the generated type test well-typed while preserving the field-read contract.

This also explains why the positive nullable test in `cfp-reftest.wast` matters so much: it proves the pass really does use this repair path, not just a simpler already-nonnullable subset.

## Step 7: nonnullable-type `ref.test` is feature-sensitive

Binaryen does not always allow the repaired nullable-base form.
The source explicitly checks whether the resulting `ref.test` would require nonnullable-type test support that the module features do not provide.
If so, it bails out.

This is a core portability rule:

- `ref.as_non_null` repair and
- feature-sensitive legality checking

must travel together.

A port that inserts the repair without reproducing the feature gate will over-accept rewrites Binaryen refuses.
A port that always bails out on nullable bases will underperform the real pass.

## Step 8: the final emitted shape is a `select`, not an `if`

When all gates succeed, Binaryen builds a `select` from:

- payload for the subtype side
- payload for the other side
- synthesized `ref.test` condition

That means the visible transformation is expression-local and read-local.
The pass is not converting the program into control-flow branches.

That is why the best teaching comparison is:

- old result source: `struct.get`
- new result source: `select(const-or-global, const-or-global, ref.test(...))`

## The strongest beginner-friendly positive family

A canonical positive family looks like this:

```wat
(type $base  (sub (struct (field (mut i32)))))
(type $left  (sub $base (struct (field (mut i32)))))
(type $right (sub $base (struct (field (mut i32)))))

(func $read (param $x (ref null $base)) (result i32)
  (struct.get $base 0 (local.get $x)))
```

Assume the closed-world CFP analysis proves:

- every `$left` instance yields `11` for field `0`
- every `$right` instance yields `22` for field `0`
- `$left` is the chosen discriminating subtype

Then `cfp-reftest` can lower the read to logic equivalent to:

```wat
(select
  (i32.const 11)
  (i32.const 22)
  (ref.test (ref $left)
    (ref.as_non_null (local.get $x))))
```

if the nullable repair is required and the necessary feature support exists.

## The most important bailout families

### More than two values

If the field summary has three or more reachable values, the variant stops.
It does not build decision trees.

### Two values but no clean type partition

Even with two values, the pass stops if no single subtype test lines up with the value split.
Two buckets are necessary, not sufficient.

### Multi-type classifier buckets

If one side still maps to multiple dynamic-type buckets the matcher cannot classify with one test, the pass stops.

### Nullable-base repair would need unsupported nonnullable `ref.test`

This is the subtle feature gate many summaries omit.
Binaryen can repair nullable bases, but only when the module features make the repaired test legal.

### Payloads outside the CFP lattice

The chooser can become more expressive than plain CFP, but the chosen values cannot.

## Why this page matters for the local registry name

The local Starshine registry entry is called `constant-field-null-test-folding`.
That is a workable mnemonic, but after reviewing the source it is not the safest teaching name.
The real contract is closer to:

- **CFP two-bucket subtype-test read specialization**

The upstream public name `cfp-reftest` is much closer to the implementation.
This page exists so future readers do not over-interpret the local alias.

## Porting checklist

A future Starshine port should preserve all of these exact behaviors:

- run only inside the ordinary CFP pipeline
- require exactly two tracked values
- require one usable classifier bucket per side
- require one subtype-based discriminator
- keep payloads inside the ordinary CFP representable-value lattice
- insert `ref.as_non_null` only when needed
- reject nullable-base repairs that would require unsupported nonnullable `ref.test`
- emit a `select(ref.test(...))` expression rewrite rather than a branch rewrite

## Sources

- [`../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md`](../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md)
- [`../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`](../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`](../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
