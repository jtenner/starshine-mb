---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./copies-subtypes-ref-tests-and-atomics.md
  - ./wat-shapes.md
---

# `constant-field-propagation`: implementation structure and tests

This page exists because `ConstantFieldPropagation.cpp` is readable, but it still hides a lot unless you line it up with the helper headers and the shipped lit tests.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/ConstantFieldPropagation.cpp` | Core pass family: gating, field-fact collection, subtype/copy fixed point, and read rewrites |
| `src/passes/pass.cpp` | Registers `cfp` and `cfp-reftest`, and places them in the closed-world GC/type cluster |
| `src/ir/possible-constant.h` | Defines the tiny tracked value lattice: none, one literal, one immutable global, or unknown |
| `src/ir/struct-utils.h` | Provides `StructScanner`, `StructValuesMap`, `FunctionStructValuesMap`, and the hierarchy propagator machinery the pass builds on |
| `src/ir/subtypes.h` | Supplies subtype iteration and exact/inexact hierarchy traversal utilities used by both propagation and `ref.test` decisions |
| `src/ir/module-utils.h` | Part of the shared module scanning infrastructure used underneath the walker/pass stack |
| `src/ir/gc-type-utils.h` and `src/ir/bits.h` | Field metadata lookup plus packed-field masking/sign-extension repair |
| `test/lit/passes/cfp.wast` | Main official contract surface for plain `cfp` |
| `test/lit/passes/gto_and_cfp_in_O.wast` | Shows why scheduler placement after `gto` / cleanup matters in the closed-world `-O` pipeline |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `ConstantFieldPropagation::run(Module* module)`

This pass method does six things:

1. require GC features
2. require `--closed-world`
3. scan writes/defaults/copies with `PCVScanner`
4. combine per-function facts into module-level maps
5. solve the subtype-plus-copy fixed point
6. run `FunctionOptimizer` to rewrite reads

### 2. `PCVScanner`

This scanner subclasses `StructUtils::StructScanner` and records:

- literal writes
- immutable-global writes
- default-zero writes
- copy edges from source fields to destination fields
- unknown-making RMW/cmpxchg writes

That means the pass does not re-implement generic struct walking itself.
It plugs custom value-tracking policy into a shared struct-traffic visitor.

### 3. `PossibleConstantValues`

This helper answers the key question:

- what single constant/global, if any, can this field still hold?

Its small value domain is why the pass is fast and conservative.

### 4. `StructUtils::TypeHierarchyPropagator<PossibleConstantValues>`

This helper performs the basic “written down / readable up” hierarchy propagation.
It is not specific to `cfp`, but `cfp` uses it as the first phase before the copy work queue.

### 5. manual copy fixed point in `ConstantFieldPropagation.cpp`

The pass then adds the extra logic that the generic hierarchy propagator does not solve for it:

- copied reads feeding later writes
- queue-driven repropagation after a destination gains new information
- packed-field repair on copied values

That fixed-point loop is where much of the real algorithm lives.

### 6. `FunctionOptimizer`

This walker mutates only the final read sites:

- `visitStructGet`
- `visitRefGetDesc`

So the overall design is:

- module-wide analysis
- function-parallel read rewriting

not “rewrite everything while scanning.”

## Why the core file is smaller than the real contract

If you only read `ConstantFieldPropagation.cpp`, you might think the pass contract is just:

- gather writes
- propagate values
- rewrite reads

That is directionally true, but incomplete.

The source is manageable because Binaryen has already pushed important mechanics into helpers:

- value merging in `possible-constant.h`
- shared struct traffic walking in `struct-utils.h`
- subtype traversal in `subtypes.h`
- packed-field reconstruction in `bits.h`

So the correct teaching model is:

- `ConstantFieldPropagation.cpp` defines policy and phase order
- the helpers define much of the mechanics

## What the registration file proves

`pass.cpp` matters for three reasons.

### It confirms the public names

The upstream public CLI names are:

- `cfp`
- `cfp-reftest`

That is the source-backed reason the local dossier needs to keep the naming split explicit.

### It confirms the public summary split

The registry summaries already teach that the `ref.test` path is a sibling variant, not merely an undocumented internal branch.

### It confirms scheduler placement

The default global-prepass cluster shows that Binaryen runs:

- `remove-unused-types`
- then `cfp` or `cfp-reftest`
- then `gsi`

under closed-world GC conditions.

That tells us the pass is not an isolated curiosity; it is a real step in the closed-world optimize story.

## What the dedicated lit files prove

## `cfp.wast` is the main contract surface

`test/lit/passes/cfp.wast` is huge and deliberately broad.
It proves at least these families.

### 1. Impossible reads from never-created types

If nothing ever writes or constructs a relevant field, a read can become `drop(ref); unreachable`.

### 2. Default-value propagation

`struct.new_default` can justify replacing later reads with explicit zero values.

### 3. Literal-constant propagation

The common positive story is:

- one literal written everywhere that matters
- later read becomes a literal block

### 4. Immutable-global propagation

The pass also optimizes when the single field value is an immutable global, not just a literal.

### 5. Subtype-aware positives and negatives

The lit file makes clear that:

- supertype reads can be blocked by subtype disagreement
- subtype reads can still optimize when the subtype-specific field view is constant
- exactness matters

### 6. Copy propagation

Several families prove that field-to-field copies are not treated as instant unknowns.
The fixed point is real behavior, not a theoretical comment.

### 7. Packed field repair

The packed field tests prove that constant propagation must preserve masking/sign-extension semantics.

### 8. Atomic boundaries

The atomic tests prove the split between:

- ordered reads that stay untouched
- known-trapping reads that can still become `unreachable`

## `gto_and_cfp_in_O.wast` proves scheduler meaning

This file is tiny, but conceptually important.
It demonstrates that in closed-world `-O`:

- earlier GC/type cleanup can remove an unread field and the dead function it kept alive
- then later constant-field propagation can infer a remaining field value exactly
- while the open-world `-O` path keeps the original read

That test is the cleanest official source for explaining why `cfp` is placed where it is.

## There is no single “cfp-reftest.wast” in the sources I reviewed

The reviewed public test surface I used here was:

- `cfp.wast`
- `gto_and_cfp_in_O.wast`

The plain `cfp.wast` comments explicitly mention some shapes that plain `cfp` must not optimize even though `cfp-reftest` might.

So for this dossier the safest teaching rule is:

- treat `cfp.wast` as the primary contract file for the pass family’s normal behavior and key variant boundary,
- and avoid claiming a separate reviewed dedicated `cfp-reftest` lit file unless a later thread verifies and documents one explicitly.

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/ConstantFieldPropagation.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/cfp.wast`

Durable result:

- the checked core pass structure and reviewed lit families still match `version_129` on the important reviewed surfaces

That is a narrow freshness note, not a proof that every helper file is identical.

## Porting checklist

A future Starshine port would need file-level responsibilities equivalent to:

- a boundary-only module pass entry point, not a hot peephole
- a struct-field scanner for writes/defaults/copies/RMWs
- a tiny single-constant-or-global value lattice
- exact/inexact hierarchy propagation
- a copy fixed point
- packed-field reconstruction logic
- read-only rewrite mutation with refinalization
- a separate more-aggressive `ref.test` variant if parity with `cfp-reftest` matters

Any port that implements only “literal constructor followed by read” matching will miss most of the official pass surface.

## Bottom line

For `constant-field-propagation`, the real implementation structure is:

- **small pass file + shared struct scanner + shared subtype helpers + tiny value lattice + large dedicated lit file**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md`](../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp.wast>
