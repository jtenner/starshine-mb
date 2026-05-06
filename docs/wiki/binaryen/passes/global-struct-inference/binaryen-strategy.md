---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-analysis-and-unnesting.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `global-struct-inference` strategy

## Upstream source rule

Use Binaryen `version_129` as the released primary source oracle for this pass, with the immutable source capture in [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md) as the repo-local manifest and the 2026-05-06 current-main recheck in [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md) as the freshness bridge.

Primary files:

- `src/passes/GlobalStructInference.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `ModuleUtils::ParallelFunctionAnalysis`
- `FindAll<StructNew>`
- `PossibleConstantValues`
- `SubTypes`
- `Bits::makePackedFieldGet`
- `ReFinalize`
- `Names::getValidGlobalName`
- nested `PassRunner` plus `reorder-globals-always`

The shipped lit surface is also part of the contract:

- `test/lit/passes/gsi.wast`

For source locations, helper ownership, and Starshine's local line-number code map, read [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) after this page.

## High-level intent

Binaryen uses `global-struct-inference` to exploit a narrow but valuable fact:

- sometimes a struct read is really reading from one of a very small set of immutable global instances

If that is true, then Binaryen can replace the read with something cheaper and more optimizable:

- the exact global origin
- the exact field value
- or a `select` between two possible values

The pass only stays correct because it preserves all of these at once:

1. the read target is an immutable field or descriptor-facing equivalent
2. the pass preserves the null trap on the original reference
3. the origin proof is small and local enough to stay honest
4. replacement values still preserve packed-field semantics
5. type refinement after the rewrite is repaired with `ReFinalize`
6. any new globals added during un-nesting are ordered before their uses

That is why this is a module pass even though the main rewrites happen while visiting functions.

## Where the pass runs

In `pass.cpp`, the default global-prepass builder inserts `gsi` only inside the GC-sensitive global cluster.

### Open-world no-DWARF path relevant to this repo

For the canonical MoonBit debug-artifact path, the meaningful neighborhood is:

- `... -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi -> ...`

That is the simple open-world shape recorded in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`.

### Closed-world Binaryen path

When Binaryen runs in closed world, the neighborhood grows:

- before `gsi`:
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
- after `gsi`:
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That means `gsi` is part of a larger GC/type-tightening module cluster, not a lone field-folding cleanup.

### Important scheduler fact: plain `gsi` vs `gsi-desc-cast`

`pass.cpp` registers both:

- `gsi`
- `gsi-desc-cast`

The repo's canonical no-DWARF page tracks the ordinary `gsi` slot.
The descriptor-cast helper is a nearby optional variant, not part of that default tracked open-world path.

## Phase 0: early GC gate

`GlobalStructInference::run(Module* module)` begins by returning immediately when:

- `!module->features.hasGC()`

This is a real semantic gate, not just scheduler trivia.
The pass does not attempt any of its struct-origin reasoning without GC enabled.

## Phase 1: mode split between closed-world analysis and always-on optimization

The top-level structure is:

- if `closedWorld`, run `analyzeClosedWorld(module)`
- always run `optimize(module)`

This is the first big beginner correction.
The pass is not actually “closed-world-only.”

What closed world adds:

- the `typeGlobals` map
- subtype poisoning and upward global propagation
- broader candidate reasoning for reads of locals, params, or supertypes

What still exists without closed world:

- direct immutable-global read optimization inside `optimize(module)`

So the correct mental model is:

- **closed world enriches the origin proof**
- it does not define the entire pass

## Phase 2: closed-world analysis builds `typeGlobals`

`analyzeClosedWorld(module)` computes which struct heap types are safe to reason about and which immutable globals create them.

### Function scan

Binaryen runs:

- `ModuleUtils::ParallelFunctionAnalysis<HeapTypes>`
- `FindAll<StructNew>(func->body)`

for each defined function.

If a heap type is created in a function body at all, that type becomes unoptimizable.

### Global scan

For each defined global, Binaryen:

- skips imported globals
- marks nested non-top-level `struct.new` occurrences as unoptimizable
- ignores non-ref initializers
- requires the global's **declared type** to be comparable enough for `ref.eq`
  - specifically, it must be a subtype of `eqref`
- rejects mutable globals
- records globals whose top-level initializer is `struct.new`

The declared-type comparability rule is a subtle but important constraint.
It explains why the lit file has:

- positive `eqref` global-declaration cases
- negative `anyref` global-declaration cases

### Subtype propagation

Binaryen then uses `SubTypes` in two ways:

- if a child type is unoptimizable, every ancestor becomes unoptimizable too
- if a child type has candidate globals, those candidate global names are propagated upward to ancestors

Finally, the propagated name lists are sorted for deterministic output.

## Phase 3: function walk over read sites

`optimize(module)` creates a nested `FunctionOptimizer : PostWalker<FunctionOptimizer>`.

It visits:

- `StructGet`
- `RefGetDesc`
- and optionally `RefCast` when `optimizeToDescCasts` is enabled

The main helper is:

- `optimize(Expression* curr, Expression*& ref, Index fieldIndex)`

That shared helper implements almost all of the actual decision logic.

## Phase 4: immutable-field gate

For ordinary field reads, Binaryen first looks up the field and immediately bails out if it is mutable.

That is a central safety rule.
This pass is not generic mutable-field value analysis.

Descriptor reads use the sentinel `DescriptorIndex = -1`, so they skip the ordinary field-mutability check and route through descriptor-specific handling instead.

## Phase 5: open-world direct immutable-global fast path

Before consulting `typeGlobals`, Binaryen checks for the trivial but important case where the read operand itself is a direct `global.get` of a defined immutable global initialized by `struct.new`.

If that is true, it can optimize immediately.

This is why the official source comment says the infrastructure also optimizes:

- reads from structs created in globals
- even in open world

### What the direct fast path actually emits

If the exact read target is known, Binaryen computes the field or descriptor value with `readFromStructNew(...)` and rewrites the current read using `getReadValue(...)`.

That can produce:

- a constant literal
- an immutable `global.get`
- or a placeholder `global.get` for later un-nesting

If the original read could trap on null, Binaryen preserves that by inserting:

- `drop(ref.as_non_null(original-ref))`

before yielding the replacement value.

This detail is easy to miss.
The pass is preserving the null-trap behavior even when the resulting field value itself is known.

## Phase 6: closed-world candidate reasoning over one or two values

If the fast path does not apply, Binaryen looks up the operand heap type in `typeGlobals`.

### No candidates

- give up

### Exactly one candidate global

Binaryen rewrites the **reference** to a block that traps on null and then yields `global.get $candidate`.

It intentionally leaves the later field read in place.
That unlocks later simplification passes without forcing `gsi` itself to do every constant-folding step.

### Multiple candidates

Binaryen scans the relevant `struct.new` operands and groups them by the value read from the requested field.

The key rule is not “at most two globals.”
It is:

- at most two **unique values**
- and if there are two, one value-group must correspond to exactly one global so a single `ref.eq` can distinguish it

Possible outcomes:

- 1 unique value => return that value directly after preserving the null trap
- 2 unique values with one singleton group => emit `select(ref.eq(...))`
- anything larger or more ambiguous => bail out

This explains the official test families where:

- 3 globals / 3 unique values do nothing
- 3 globals / 2 unique values can optimize
- 4 globals / 2 equal pairs still do nothing
- many globals / all same value can still optimize without any select

## Phase 7: `PossibleConstantValues` decides what is constant enough

`readFromStructNew(...)` delegates to `PossibleConstantValues`.

That helper can recognize as constant:

- literal constant expressions
- immutable `global.get`s

and otherwise treats the operand as unknown.

This has two important consequences.

### Positive consequence

If two candidate globals store:

- `global.get $one`
- `global.get $two`

those can still participate in a select rewrite because Binaryen can materialize each immutable global get as a replacement expression.

### Negative consequence

If two candidate globals store non-constant trees that happen to be textually similar, Binaryen does not do deep semantic equivalence over those trees here.

So the pass is selective about what it calls "same value."

## Phase 8: packed-field handling lives in the replacement helper

`getReadValue(...)` reconstructs the replacement expression.

If the field is packed, Binaryen uses:

- `Bits::makePackedFieldGet(...)`

so the replacement preserves the same signed/unsigned truncation or extension behavior as the original read.

That is why the official packed-field lit case shows masked or sign-extended values rather than the raw stored i32 operands.

## Phase 9: non-constant values can still optimize through un-nesting

If a selected field value is not constant, Binaryen can still optimize by un-nesting it.

Mechanically:

1. create a placeholder `global.get`
2. record a `GlobalToUnnest { global, index, get }`
3. after parallel function work completes, add a fresh immutable global initialized from the nested operand
4. replace the original nested operand with a `global.get` of the new global
5. update the placeholder `get` to use the new name

If any globals were added, Binaryen runs nested:

- `reorder-globals-always`

so the new globals appear before uses.

This is a major part of the real pass contract and a major difference from the current local MoonBit subset.

## Phase 10: atomic gets are intentionally allowed

The code comments explicitly note that the pass need not fear synchronization loss here because the field is immutable.

So even atomic get forms can be optimized when the same origin proof succeeds.

That is a genuinely non-obvious rule:

- “atomic” does **not** mean “hands off” for this pass
- immutability is what makes the rewrite safe

## Phase 11: type repair and refinalization

`FunctionOptimizer` tracks a `refinalize` flag.
It sets that flag when:

- the rewritten reference operand type becomes more refined
- or the replacement value type differs from the original read type

At `visitFunction(...)`, if needed, it runs:

- `ReFinalize().walkFunctionInModule(func, getModule())`

This matters for cases like:

- null result refinement
- more precise global reference types
- descriptor or subtype-related return-type refinement

So `gsi` is not just local pattern replacement.
It depends on later type repair inside the same pass.

## Phase 12: descriptor-facing helper surfaces

Two nearby surfaces are easy to miss.

### `RefGetDesc`

Plain `gsi` already visits `RefGetDesc` and feeds it into the same shared optimizer using the sentinel descriptor index.

So the official pass is not limited to ordinary struct fields.

### `gsi-desc-cast`

When `optimizeToDescCasts` is true, `visitRefCast(...)` can rewrite some `ref.cast` operations into descriptor-equality casts when:

- the target type has a descriptor type
- there are no relevant strict subtypes unless the type is exact already
- the descriptor type has exactly one candidate global

This variant is registered upstream, but it is a sibling helper, not the canonical open-world no-DWARF slot tracked in the repo page.

## What this pass does **not** do

These non-goals are worth keeping explicit:

- no generic whole-program field dataflow
- no arbitrary many-way dispatch among many possible globals
- no deep expression-equivalence reasoning for non-constant field operands
- no mutable-field value inference
- no origin proof for types allocated in functions or nested global positions
- no implicit assumption that closed world alone makes every parent-type read safe to rewrite

## Why the official tests matter so much

The real contract is easiest to understand from the shipped `gsi.wast` families.
The file covers:

- open-world-shape-compatible direct-global reads
- one-global reference rewrites
- two-value and grouped-value selects
- more-than-two-value bailouts
- subtype positives and negatives
- nested-global and function-local poisoning
- non-constant un-nesting
- packed and atomic gets
- `eqref` vs `anyref` declaration differences
- bottom-type no-crash handling
- null-result refinement

That is much broader than the current local MoonBit test surface.

## Current freshness note

A focused 2026-05-06 current-main recheck found no teaching-relevant drift here on the reviewed owner, registration, helper, and dedicated-lit surfaces:

- current `main` still shows the same mode split: optional closed-world analysis followed by `optimize(module)` in all modes
- current `main` still shows un-nesting plus nested `reorder-globals-always`
- current `main` still shows the plain `gsi` / sibling `gsi-desc-cast` factory split
- current `main` `gsi.wast` remains the dedicated plain-pass proof surface reviewed for this dossier

So the current wiki should continue treating `version_129` as the released semantic oracle without an active trunk-drift caveat. The 2026-05-06 check was a focused source bridge, not a full post-`version_129` trunk audit.

## What a future port or parity pass must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- the pass is GC-gated
- the open-world direct immutable-global fast path still exists
- closed world enriches the pass with `typeGlobals`; it does not define the entire pass
- immutable-field gating is mandatory
- subtype poisoning and upward candidate propagation are both real
- profitability is really about one value or two unique values with one singleton testable group
- immutable `global.get` operands count as constants for grouping/materialization
- packed-field signedness and atomic-get safety rules must be preserved
- non-constant nested operands can participate through fresh-global un-nesting
- refinalization is part of the rewrite contract
- `RefGetDesc` and the sibling `gsi-desc-cast` surface exist even if the repo's current public preset does not model them

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.
