---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md
  - ../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `type-refining`: normal vs GUFA and why fixups are mandatory

This page covers the part of the pass that is easiest to misunderstand:

- what the normal pass actually sees
- what the GUFA variant sees that the normal pass misses
- why Binaryen must repair both reads and writes after refining field types

## First correction: upstream has two passes here, not one

Upstream `pass.cpp` registers both:

- `type-refining`
- `type-refining-gufa`

The local Starshine registry only tracks the base name `type-refining` today; see [`./starshine-strategy.md`](./starshine-strategy.md) for the exact local status and the open naming question.
But the official Binaryen behavior around this topic is incomplete if you ignore the GUFA companion.

## The simplest mental model

- **normal `type-refining`** = direct struct traffic plus limited copy detection
- **`type-refining-gufa`** = whole-program contents inference through `ContentOracle`
- **both** = same public/private legality rules and same read/write fixup back end

## What the normal pass actually sees

The normal mode is built around `FieldInfoScanner`, which subclasses `StructUtils::StructScanner`.

It directly reasons about things like:

- `struct.new`
- `struct.set`
- `struct.get` as a source for copies
- `struct.atomic.rmw`
- `struct.atomic.rmw.cmpxchg`
- some module-code `struct.new` / `struct.get` sites

That means the normal pass is good at questions like:

- what exact or inexact values are written directly into this field?
- is this write just copying the same field back into itself?
- does a default constructor force nullability?
- how should that information move to supertypes or subtypes?

It is **not** good at questions like:

- what value reaches this field only after going through a chain of locals?
- what value comes back from a helper call and then flows into another struct?
- what does a global definitely contain after multiple round trips through functions?

That is where GUFA begins to matter.

## What GUFA sees that the normal pass can miss

The GUFA mode uses `ContentOracle` and queries `DataLocation{type, field}`.
That lets it track whole-program contents more like a global flow oracle.

So GUFA can understand flows through:

- locals
- globals
- calls
- cycles between functions and globals
- other whole-program edges that do not show up as one obvious local struct op

The dedicated `type-refining-gufa.wast` file contains exactly those families.
A recurring shape in that test file is:

- normal mode can refine one field partially
- GUFA can refine a second field further because it sees through the intermediate storage/use chain
- repeated normal optimization passes still do not necessarily rediscover the same answer

That is why the upstream project bothers to ship both passes.

## Why repeated `-O3` is not the same as GUFA

One official test comment makes the point plainly.
Even running the broader optimization cluster twice can still fail to infer what GUFA can infer in one pass, because:

- the relevant information is cyclic
- separate passes each have narrower local views
- the GUFA lattice/oracle is not equivalent to repeatedly rerunning those narrower passes

So a future port should not oversimplify this as:

- "GUFA is just what you get if you rerun the ordinary cluster enough"

## Why the normal pass ignores tee / `br_if` fallthrough copies

This is one of the most practical design choices in the pass.

`FieldInfoScanner::getFallthroughBehavior()` returns:

- `NoTeeBrIf`

The long source comment explains the problem.
If a copied value flows through a `local.tee`, the tee itself can keep the old, broader type even after the field is refined. That may force extra casts later, and those casts are not always cheap or valid enough to justify treating the tee as transparent during inference.

So the normal pass deliberately chooses a smaller but safer rule:

- plain same-field copies can be ignored
- some wrapper fallthroughs can still be recognized
- tee / `br_if` fallthroughs are excluded

This is why the tests split into two families:

### Tee family

- copy goes through `local.tee`
- Binaryen stays conservative
- refinement may stop earlier than a naïve reader expects

### Block / `if` family

- copy goes through control flow with explicit result typing
- `ReFinalize` can later update that control node's type
- refinement can still proceed

That contrast is not accidental.
It is a deliberate implementation boundary.

## Why reads do not constrain inference

Another easy mistake is to think:

- if a field is ever read as `anyref`, Binaryen must leave the field as `anyref`

That is false for this pass.
The inference phase looks at **writes**, not reads.
So the pass can infer a field should become more specific even when old read sites still mention the old broader type.

That design is the whole reason the later fixups exist.

## Read fixups: what Binaryen repairs after refining

After Binaryen decides on new field types, it runs `ReadUpdater`.
That updater handles two situations.

### 1. The refined field makes an old read impossible or uninhabitable

If the pass concludes that a `struct.get` is now effectively reading from:

- a null reference
- a field with no reachable contents
- or a field whose new type cannot fit the old `struct.get` result type

then Binaryen replaces the get with:

- `drop(ref)`
- `unreachable`

This preserves the trap-like behavior without trying to emit an impossible `struct.get` node.

### 2. The read is still valid, but its result type must become narrower

In the normal case Binaryen simply changes the cached result type of the `struct.get` itself.

This is not redundant bookkeeping.
The source comment explains that `ReFinalize` alone can miss some recursive/block cases after a parent temporarily bottoms out. So the pass retags the `struct.get` eagerly before refinalization runs.

## Write fixups: why declaration rewriting is not enough

After rewriting private struct declarations and running `ReFinalize`, some write sites can still be too broad for the newly refined field type.
Binaryen then runs `WriteUpdater` over:

- `StructNew`
- `StructSet`
- `StructRMW`
- `StructCmpxchg`

Its job is simple to say but essential:

- if the value being written is too broad, repair it so the refined field still validates

## The three main write-fixup outcomes

### 1. No fixup needed

If the value type is already a subtype of the refined field type:

- keep it as-is

### 2. Add a `ref.cast`

If a value is not yet narrow enough, but a cast can express the needed runtime check:

- wrap it in `ref.cast`

This is the common exactness-repair outcome.
It is why GUFA exact improvements often show up as extra casts in the official output.

### 3. Emit `ref.null` or `unreachable` instead of casting

Some refined field types are bottoms or continuation-related cases that are not sensibly fixed with a cast.
Then Binaryen chooses one of these shapes instead:

- `drop(value); ref.null bottom` for nullable bottoms
- `drop(value); unreachable` for non-nullable bottoms

That is how the pass stays valid for certain continuation and uninhabited-type families.

## Why GUFA must also look at global initializers

One of the cleverest details in the pass is easy to miss.
`WriteUpdater` only repairs function bodies.
It does **not** go rewrite global initializers by inserting casts there.

So the GUFA front end adds a compensating restriction:

- scan `StructNew` inside non-imported globals
- note the child operand types there too
- refuse to infer a field type that those global initializer operands would later need a cast to satisfy

In short:

- function writes can be repaired later
- global initializer writes need to be kept compatible up front

That is why the GUFA path has extra global-specific logic even though the normal path already scans module code.

## Exactness restrictions: why GUFA is still conservative

The dedicated `type-refining-gufa-exact.wast` file teaches two separate limits.

## Limit 1: custom-descriptor-dependent exactness

If a field is not already exact, GUFA may need later exact casts to realize the refinement.
Without custom descriptors, some of those casts are not valid, so the pass intentionally keeps the field inexact instead.

So the rule is not:

- GUFA always refines to exact when it knows an exact type

It is:

- GUFA refines to exact only when the later repair surface can honestly represent that exactness

## Limit 2: continuation fields

Continuation values are another place where cast repair is limited.
The pass therefore refuses to use some more precise continuation results GUFA can infer, and keeps the original field type instead.

That is a correctness limit, not a missed optimization due to oversight.

## Public/private rules still apply in both variants

Neither normal nor GUFA mode can refine public struct types here.
They both feed into the same back-end legality logic, which freezes public types and only rewrites private ones.

So GUFA is stronger mainly in **inference precision**, not in **boundary permissions**.

## What a future Starshine port must not conflate

A future port should keep these distinctions explicit:

- normal mode != GUFA mode
- tee fallthrough conservatism != general inability to refinalize control flow
- read repair != declaration rewrite
- function-write fixups != global-initializer constraints
- exactness inference != exactness legality

If those are collapsed into one vague story like “the pass just makes field types smaller,” the real Binaryen behavior will be lost.

## Bottom line

The important sentence to remember is:

- **Binaryen first infers field types, then spends real effort making the rest of the module catch up to those refined field types.**

That is true in both variants.
The only big difference is how much each variant can see before that shared repair stage begins.

## Sources

- [`../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md)
- [`../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>
