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
  - ../constant-field-propagation/binaryen-strategy.md
  - ../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md
related:
  - ./implementation-structure-and-tests.md
  - ./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../constant-field-propagation/index.md
---

# Binaryen strategy for `constant-field-null-test-folding` / `cfp-reftest`

## The one-sentence contract

Binaryen `version_129` implements `cfp-reftest` as **the normal closed-world CFP engine plus one extra field-read rewrite family that can replace a read with `select(..., ..., ref.test(...))` when exactly two subtype-separated constant buckets are provable**. The sibling-specific raw capture in [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md) now anchors this page directly instead of requiring readers to rely only on the parent CFP manifest.

## Why the local name is dangerous

The local registry name `constant-field-null-test-folding` sounds broader than the real source contract.

It does **not** mean:

- arbitrary `ref.test` simplification
- generic null-check folding
- general cast/test cleanup
- whole-function branch simplification

It really means:

- run CFP
- and in one narrow case, synthesize a `ref.test`-guarded `select` instead of leaving a `struct.get` in place

So the safest teaching rule is:

- treat this as a **CFP sibling variant**
- not as a standalone null-test optimizer

## Scheduler placement

This pass is a fair campaign target because it is already named in the local boundary-only registry, but it is **not** part of the repo's current open-world no-DWARF default optimize path.

Its practical scheduler meaning is the same closed-world GC/type cluster as CFP:

- after type-shaping cleanup like `remove-unused-types`
- before later neighbors like `gsi`

That placement matters because the rewrite depends on:

- closed-world knowledge of created subtypes
- the same field-fact propagation that plain CFP already needs

## Phase 1: inherit the ordinary CFP gates

The variant does not bypass ordinary CFP gating.
It still needs the same preconditions as the parent pass family:

- GC features enabled
- closed-world mode enabled
- struct-field analysis available
- valid exact-vs-inexact subtype reasoning

If those conditions fail, there is no special `ref.test` shortcut.
The whole pass is out of scope.

## Phase 2: build the same field fact model as plain CFP

`cfp-reftest` does not start from raw syntax patterns.
It starts from the same underlying field analysis as plain CFP:

- scan field writes and defaults
- track facts per field at the type level
- propagate them across subtypes and supertypes
- iterate copies to a fixed point
- then rewrite reads where legal

That means the key porting lesson is:

- **the `ref.test` rewrite is downstream of the field-fact analysis**
- it is not a direct local peephole

A future Starshine port that tries to implement only the visible `select(ref.test(...))` output shape without reproducing the earlier CFP analysis will miss the real contract.

## Phase 3: plain CFP gets first chance

The strategy remains conservative.
Binaryen tries the plain CFP replacement story first, and the 2026-04-25 source capture records that the upstream helper is only reached when ordinary replacement fails and the receiver reference is not exact.
That means if one field fact already wins cleanly, the read can be replaced the ordinary way:

- one literal constant
- or one immutable global

The `cfp-reftest` logic is therefore not the default path.
It is the extra salvage path after plain single-bucket replacement is insufficient.

## Phase 4: the variant-only path looks for exactly two buckets

The extra mode in `ConstantFieldPropagation.cpp` searches for one very particular situation:

- the field has **exactly two** possible value buckets
- each side reduces to one usable classifier bucket
- the buckets are still representable as legal replacements
- one subtype test can separate them

This is the core reason the pass is narrow.

If Binaryen sees:

- three or more buckets
- classifier buckets that still mix too many runtime types
- a subtype graph that does not give one clean discriminator
- or values that are not valid replacement payloads

then the variant gives up and leaves the read alone.

## Phase 5: the discriminator is a heap-type split, not a generic null split

The crucial matcher is subtype-driven.
Binaryen looks for a candidate subtype whose created instances line up with one of the two constant buckets.

So the pass is really answering:

- “can one `ref.test` on this base reference tell me which of the two field values applies?”

That is fundamentally different from:

- “can I simplify some null test?”

Null can appear in a bucket, but it is not the defining feature of the optimization.
The defining feature is the existence of **one legal heap-type test that separates the two field-value classes**.

## Phase 6: rewrite the read as a `select`

When that narrow proof succeeds, Binaryen can replace the original read with the logical equivalent of:

- test the base reference with `ref.test`
- if needed, first repair a nullable base with `ref.as_non_null`
- select the constant/global value for the matching subtype bucket
- otherwise select the constant/global value from the other bucket

That is the visible WAT consequence most readers notice.
But the deeper contract is:

- the `select` is only valid because the field-fact lattice, subtype propagation, and created-type reasoning already proved the two-way partition
- and the nullable-base repair is only legal when the resulting nonnullable `ref.test` form validates for the module's active type/feature environment

## Phase 7: keep all ordinary CFP safety boundaries

Because this is the same core engine, the variant inherits all the CFP boundaries that are easy to forget if you focus only on the visible `ref.test` output:

- exact and inexact references are not interchangeable
- null-trap behavior must be preserved
- packed-field reconstruction rules still matter
- atomic ordered reads are still a bailout
- impossible reads can still become `drop(ref); unreachable` instead of a normal constant

So the right implementation mantra is:

- **variant-only extra power, same safety boundaries**

## Positive shapes to teach first

The best beginner-first positive shape is:

- one field in a base type
- two created subtype populations
- each subtype population always writes a different constant value to that field
- a later read through a non-exact base reference
- one subtype test cleanly distinguishes the populations

That can become:

- `select(value_for_subtype, value_for_other_side, ref.test(...))`

A second good positive family is when one side is represented by an immutable global instead of a literal.
The same two-bucket logic still applies as long as both payloads remain legal replacements.

## Bailout shapes to teach early

### More than two buckets

If three or more possible values survive, the variant gives up.
This is a major beginner-facing boundary.

### No single clean subtype discriminator

Even with two buckets, the pass still bails out if there is no one heap-type test that partitions them cleanly.

### Exact-reference reads that already pin the dynamic type

If the dynamic uncertainty the variant needs is not present, plain CFP or no rewrite at all is the right outcome.
The variant does not invent a useless test.

### Atomic ordered reads

The ordinary CFP atomic ordered-read bailout still applies.
This is not relaxed just because the variant wants a `select`.

### Non-CFP-representable payloads

If the buckets are not representable as the tiny CFP replacement domain, the variant gives up.

## What a future Starshine port must preserve

A future port must preserve all of these:

- the same **closed-world and GC gate** as CFP
- the fact that this is a **mode of CFP**, not a separate syntax matcher
- plain single-bucket replacement before variant-only rescue logic
- the **exactly-two-bucket** rule
- the need for **one legal subtype discriminator**
- the same null-trap, packed-field, and atomic boundaries as ordinary CFP
- the scheduler reality that this is an upstream-only closed-world registry candidate today

## Easy misunderstandings

### “It folds null tests.”

Only in the weakest descriptive sense.
The real source-backed behavior is field-read two-bucket subtype splitting.

### “It should be documented with cast optimizers.”

No.
Its home is the CFP / closed-world field-analysis cluster.

### “Two possible values are enough.”

No.
Two values are necessary but not sufficient.
The subtype split must also be representable by one `ref.test`.

### “It rewrites control flow.”

Only incidentally.
The emitted `select` is a read replacement, not a branch optimizer.

## Sources

- [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md)
- [`../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`](../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md)
- [`../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md`](../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md)
- [`../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`](../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md)
- [`./index.md`](./index.md)
- [`../constant-field-propagation/binaryen-strategy.md`](../constant-field-propagation/binaryen-strategy.md)
- [`../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`](../constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
