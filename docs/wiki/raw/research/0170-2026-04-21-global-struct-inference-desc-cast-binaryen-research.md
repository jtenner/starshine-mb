# 0170 - Binaryen `global-struct-inference-desc-cast` / upstream `gsi-desc-cast` research

Date: 2026-04-21
Status: supported

## Why this pass was chosen

The main no-DWARF / saved-`-O4z` parity queue is already dossier-covered, and the first expansion wave (`remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, `constant-field-propagation`, `constant-field-null-test-folding`, `abstract-type-refining`, `unsubtyping`, `minimize-rec-groups`, `reorder-types`, `dead-argument-elimination`, `simplify-globals`, `inlining`, `propagate-globals-globally`, `global-effects`, `optimize-added-constants`, `optimize-added-constants-propagate`, `simplify-locals-notee`, and `precompute-propagate`) is already dossier-covered too.

So this thread needed either:

- a major-gap fallback inside an already-deep folder, or
- a new, source-backed upstream-only registry expansion.

I chose `global-struct-inference-desc-cast` because:

- it is still named explicitly in the local boundary-only registry in `src/passes/optimize.mbt`
- it is clearly real upstream surface in Binaryen `version_129`, published under the shorter name `gsi-desc-cast`
- the existing `global-struct-inference` dossier only mentions it as a sibling mode, so there was still no dedicated canonical home for its own contract
- it sits directly beside the already-important `gsi`, `gto`, `cfp`, `remove-unused-types`, `abstract-type-refining`, and `unsubtyping` GC/type cluster
- `agent-todo.md` currently has **no dedicated slice** for `global-struct-inference-desc-cast` or `gsi-desc-cast`

That makes it a good second-wave expansion candidate in the same style as `constant-field-null-test-folding` (`cfp-reftest`): a real upstream pass/variant already visible in the local registry, source-backed, and easy to lose if it stays buried inside a neighboring dossier.

## Source set used

Primary official Binaryen sources:

- `src/passes/GlobalStructInference.cpp` on `version_129`
- `src/passes/pass.cpp` on `version_129`
- `test/lit/passes/gsi.wast` on `version_129`
- `src/ir/possible-constant.h` on `version_129`
- `src/ir/subtypes.h` on `version_129`

Local repo context used to justify expansion and connect it to Starshine:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- the existing `docs/wiki/binaryen/passes/global-struct-inference/` folder

## Identity and naming

### Local vs upstream naming

Local Starshine registry name:

- `global-struct-inference-desc-cast`

Official upstream Binaryen public pass name:

- `gsi-desc-cast`

This is a real naming split, not just prose shorthand.
`pass.cpp` registers both `gsi` and `gsi-desc-cast`, while the local registry uses the longer descriptive spelling.

### What the pass is **not**

It is **not**:

- generic cast optimization
- a substitute for `optimize-casts`
- a general ref-cast simplifier over arbitrary runtime values
- a separate whole-program analysis engine unrelated to `gsi`

It is best understood as:

- **the `global-struct-inference` machinery with `optimizeToDescCasts=true`**
- using the same trusted-global origin logic, but aiming at a narrow `ref.cast` rewrite family instead of ordinary field reads

## Scheduler placement

### What `pass.cpp` proves

`pass.cpp` registers two closely related public passes:

- `gsi`
- `gsi-desc-cast`

The repo's canonical no-DWARF path only tracks the plain `gsi` slot.
So `gsi-desc-cast` is:

- real upstream surface
- **not** part of the repo's current default open-world no-DWARF `-O` / `-Os` path
- best taught as an optional sibling in the same GC/type neighborhood

### Why that placement matters

This mode only makes sense after earlier type/global cleanup has made trusted global origins easier to prove.
The nearby cluster in Binaryen docs and neighboring pass pages is roughly:

- `global-refining`
- optional `gto`
- `remove-unused-module-elements`
- optional `remove-unused-types`
- optional `cfp` / `cfp-reftest`
- `gsi`
- optional `gsi-desc-cast`
- optional `abstract-type-refining`
- optional `unsubtyping`

That means a future Starshine port should think of `global-struct-inference-desc-cast` as a **late GC/type precision cleanup**, not as a standalone cast pass dropped into the regular hot-function pipeline.

## High-level implementation structure

`GlobalStructInference.cpp` owns both plain `gsi` and `gsi-desc-cast`.
The file defines a shared `GlobalStructInference` pass object with a constructor parameter that controls whether descriptor-cast optimization is enabled.

At a high level the structure is:

1. gate on GC support
2. if closed world, build the `typeGlobals` oracle with `analyzeClosedWorld(module)`
3. always run `optimize(module)`
4. inside the function walker, visit ordinary read sites and, when enabled, certain `ref.cast` sites
5. if replacements sharpen types, run `ReFinalize`
6. if un-nesting introduced new immutable globals, rerun `reorder-globals-always`

The key beginner correction is:

- `gsi-desc-cast` is **not** a separate analysis pass
- it is a different consumer of the same trusted-global infrastructure

## Shared analysis that the variant reuses

The pass inherits the full origin-proof machinery from plain `gsi`.
That includes:

- the GC gate
- optional closed-world `typeGlobals` construction
- the always-on open-world direct immutable-global fast path
- subtype poisoning via `SubTypes`
- upward propagation of candidate globals from child types to parent types
- the tiny grouping logic over replacement possibilities
- un-nesting of non-constant global-initializer operands into fresh immutable globals when necessary

So the true mental model is:

- plain `gsi` consumes the shared oracle to rewrite `struct.get` and `ref.get_desc`
- `gsi-desc-cast` consumes the same oracle to rewrite some `ref.cast`

## The actual `gsi-desc-cast` contract

The descriptor-cast mode visits `ref.cast` only when `optimizeToDescCasts` is enabled.
But it still keeps several narrow gates.

### Gate 1: the target type must have a descriptor type

The optimization is descriptor-driven.
If the target heap type has no descriptor type to compare against, there is no rewrite.

This is one of the biggest beginner gotchas:

- the pass is not using arbitrary subtype facts alone
- it is using **descriptor equality as a cheaper runtime discriminator**

### Gate 2: trusted-origin globals must collapse to one descriptor identity

The pass needs the target descriptor identity to be tied to a unique candidate global story.
If multiple relevant descriptor-bearing candidates remain and they cannot be collapsed honestly, it bails.

### Gate 3: strict subtypes matter

A plain-looking cast can still be unsafe to replace if relevant strict subtypes of the target type exist.
The source comments and surrounding subtype checks show the intended rule:

- if the target is already exact, the situation is simpler
- otherwise, strict-subtype ambiguity can block the rewrite

That means the pass is **not** simply turning every descriptor-aware cast into a cheaper check.
It only does so when the subtype lattice says the descriptor test is enough.

### Gate 4: the original cast semantics must stay intact

A rewritten cast still has to preserve the success-vs-trap behavior of `ref.cast`.
That means the pass cannot merely return a descriptor or a boolean.
It must produce a value sequence whose runtime meaning still matches the cast contract.

## What the rewrite sounds like versus what it actually is

Easy wrong model:

- if Binaryen knows something about descriptors, it can replace `ref.cast` with a descriptor check everywhere

Safer real model:

- if the value's possible origins are tightly tied to immutable globals,
- and the target type has a descriptor type,
- and strict-subtype ambiguity is absent or already ruled out,
- then Binaryen may replace the ordinary cast path with a descriptor-equality-based cast pattern

So this is much narrower than the name might suggest.

## Important helper and dependency surface

The variant depends on the same helper surface as plain `gsi`.
The important parts are:

- `ModuleUtils::ParallelFunctionAnalysis`
  - used in the closed-world scan that poisons types created in functions
- `FindAll<StructNew>`
  - used to discover function-local allocations that make type families unoptimizable
- `PossibleConstantValues`
  - used by the ordinary `gsi` read side and still part of the same machinery family
- `SubTypes`
  - used for child-to-parent poisoning and candidate-global propagation
- `ReFinalize`
  - required after making expression types more precise
- `Names::getValidGlobalName`
  - needed when un-nesting creates fresh immutable globals
- nested `PassRunner` with `reorder-globals-always`
  - required so new globals appear before use sites

For a future Starshine port, the crucial preservation rule is that **descriptor-cast optimization is not independent of the surrounding module rewrite machinery**.
If un-nesting is supported, global order repair is part of the contract.

## WAT / IR shapes that matter

### Positive family 1: target type with unique descriptor, no strict-subtype ambiguity

Conceptually, the positive shape looks like:

- an immutable global creates or points to a trusted struct instance
- a later value being cast can only come from that trusted-origin family
- the target type's descriptor identity is unique enough to test directly

Result:

- Binaryen can use a descriptor-equality cast path rather than keeping the ordinary generic cast route

### Positive family 2: exact target types

If the target heap type is already exact, one major ambiguity source disappears.
That can make descriptor-based rewriting legal in cases where an inexact target would have to bail.

### Positive family 3: open-world direct-global origin wins
n
Just like plain `gsi`, the variant is not purely closed-world-only.
If the immediate value flow already exposes a direct immutable-global origin strongly enough, some wins are available without the broader closed-world `typeGlobals` map.

### Bailout family 1: target has relevant strict subtypes

If strict subtypes of the target matter and the cast is not already exact enough, descriptor equality may be too weak.
The safe outcome is to preserve the original cast.

### Bailout family 2: target lacks descriptor type

No descriptor type means no descriptor-equality rewrite.

### Bailout family 3: multiple incompatible candidate globals

If the trusted-origin set does not collapse to one descriptor identity, the pass keeps the original cast.

### Bailout family 4: origins proven only by unsupported dynamic traffic

If the origin proof would need arbitrary function-local allocation reasoning or unsupported escape analysis, the pass stops.
This inherits the same narrowness as plain `gsi`.

## Test surface

A notable source-backed finding is that there does **not** appear to be a separate dedicated `gsi-desc-cast.wast` file in `version_129`.
Instead:

- registration is explicit in `pass.cpp`
- implementation is explicit in `GlobalStructInference.cpp`
- observable behavior is covered through the broader `gsi.wast` family and the source file itself

That matters for future documentation because it is easy to overstate the test surface.
The honest rule is:

- this variant is clearly implemented and publicly registered
- but its lit coverage is piggybacked on the broader `gsi` surface rather than isolated in a dedicated file

## What is easy to misunderstand

### Misunderstanding 1: "This is just `optimize-casts` for descriptors"

No.
`optimize-casts` is a different mid-function cast-motion/reuse pass.
`gsi-desc-cast` depends on trusted immutable-global origin reasoning from the GSI family.

### Misunderstanding 2: "Closed world is required for every win"

No.
The broader `gsi` family still has an open-world direct-global fast path.
Closed world enriches the candidate set and subtype reasoning, but it is not the only way the machinery can prove something.

### Misunderstanding 3: "A descriptor check and a cast are the same thing"

No.
The whole reason the gates are narrow is that Binaryen must preserve cast semantics, not merely emit a related boolean test.

### Misunderstanding 4: "If a type has a descriptor, the rewrite always applies"

No.
Subtype ambiguity and candidate-global ambiguity still block the rewrite.

## What a future Starshine port must preserve

A parity-focused port should preserve at least these rules:

- local-vs-upstream naming split:
  - local registry `global-struct-inference-desc-cast`
  - upstream public `gsi-desc-cast`
- shared-engine identity:
  - this is the same `GlobalStructInference.cpp` engine, not a separate pass family
- GC gate and scheduler neighborhood
- exact-target versus inexact-target behavior
- descriptor-type requirement
- strict-subtype ambiguity bailout
- candidate-global uniqueness requirement
- refinalization after type sharpening
- global-order repair if un-nesting introduces fresh globals

## Implementation and documentation consequences

The living wiki should treat `global-struct-inference-desc-cast` as a sibling dossier, not as a subsection permanently buried inside `gsi`.
That makes three important things durable:

1. the local-vs-upstream naming split
2. the fact that this is a real separately registered public pass
3. the narrow descriptor-cast contract future Starshine work must preserve

## Open questions and uncertainty

Two uncertainties should stay explicit.

1. There does not appear to be a dedicated upstream lit file for `gsi-desc-cast` in the reviewed `version_129` surfaces.
   - I found explicit registration and implementation, plus `ref.cast` material in `gsi.wast`, but not a separate `gsi-desc-cast.wast` file.
   - That is a source-backed absence, not proof that broader coverage is impossible elsewhere.

2. The exact emitted AST shape of the descriptor-based cast replacement is easier to misread than the field-read side of plain `gsi`.
   - The broad contract is clear from the implementation comments and gates.
   - But the safest beginner teaching stays at the rule level: descriptor-equality-based cast path, not arbitrary ref-cast replacement.

## Durable summary

`global-struct-inference-desc-cast` is a good tracker expansion target because it is a real local registry entry with real upstream `version_129` implementation under the public name `gsi-desc-cast`, but it previously lacked a dedicated canonical home.

The key lesson is:

- this pass is **not** generic cast optimization
- it is **the descriptor-cast sibling of `gsi`**, using the same trusted immutable-global origin analysis and only rewriting a narrow family of `ref.cast` sites when descriptor identity is sufficient to preserve cast semantics.

## Sources

Local repo sources:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/global-struct-inference/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/closed-world-analysis-and-unnesting.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

Official Binaryen `version_129` sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
