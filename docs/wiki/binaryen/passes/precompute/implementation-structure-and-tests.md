---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../../raw/research/0229-2026-04-21-precompute-implementation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../precompute-propagate/index.md
---

# `precompute`: implementation structure and tests

This page is the compact source-confirmed map for Binaryen `version_129` plain `precompute`.
Use [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md) as the immutable provenance manifest for the reviewed official release, source, and test URLs cited here.

Its main job is to answer two practical questions:

1. which upstream files really own the plain pass contract?
2. which shipped tests prove plain `precompute`, and which neighboring tests belong to the shared family or the sibling `precompute-propagate` mode instead?

## Main owner files

## `src/passes/Precompute.cpp`

This is the real owner file.

It contains the full shared family implementation for both public names:

- `precompute`
- `precompute-propagate`

For plain `precompute`, the most important durable facts visible in the reviewed file are:

- the pass is built on `PrecomputingExpressionRunner`, which subclasses `ConstantExpressionRunner`
- the main work is bottom-up speculative compile-time evaluation, not syntax-only peepholes
- direct replacement is gated by `Flow` outcomes, emitability, and child-retention rules
- partial precompute is part of the ordinary plain-pass contract when `optimizeLevel >= 2`
- GC identity caching, temporary heap-cache isolation during speculative partial precompute, and final refinalization are all owned here
- the sibling `precompute-propagate` mode is implemented in the same file by enabling one extra propagation phase after the ordinary walk

That shared-file structure is the first thing a future porter should know.

## `src/passes/pass.cpp`

This file matters because it proves:

- `precompute` is a real public upstream pass name in `version_129`
- its public description is the smaller “compute compile-time evaluatable expressions” contract
- plain `precompute` is the top-level no-DWARF `-O` / `-Os` mode rather than the propagating sibling
- the public split from `precompute-propagate` is intentional and user-visible

Without `pass.cpp`, it is too easy to document the evaluator accurately but lose the public meaning of the plain-vs-propagate split.

## `src/passes/opt-utils.h`

This file does not own plain `precompute` semantics directly.
It still matters because it proves the most important scheduler boundary:

- `optimizeAfterInlining(...)` prepends `precompute-propagate`, not plain `precompute`

That means a good plain-pass teaching page must keep the neighboring sibling explicit instead of implying that top-level no-DWARF `precompute` is the only practical precompute-family surface.

## `src/wasm-interpreter.h`

This is the key semantic helper owner.

It matters because the plain pass relies on:

- `ConstantExpressionRunner`
- `Flow`
- compile-time execution rules and bounded interpretation

That is what makes `precompute` a semantic evaluator rather than a bag of local AST patterns.

## `src/ir/properties.h`

This file matters because it owns helper boundaries that shape plain `precompute` behavior, especially:

- `Properties::getFallthrough(...)`
- `Properties::isValidConstantExpression(...)`

Those helpers explain why:

- partial precompute only considers promising `select` arms,
- propagation in the sibling pass talks about fallthrough values,
- and some shells are treated as transparent enough for compile-time reasoning while others are not.

## `src/ir/local-graph.h`

This file is not part of the plain pass's direct algorithmic surface, but it is still part of the implementation map because it owns the extra local-worklist phase that belongs specifically to `precompute-propagate`.

For plain `precompute`, that neighboring-helper role matters because it keeps the public split honest:

- plain `precompute` uses the shared evaluator and partial-precompute logic
- `precompute-propagate` adds the `LazyLocalGraph` get/set worklist on top

## Owner split in one table

| File | Ownership role | What it contributes |
| --- | --- | --- |
| `src/passes/Precompute.cpp` | core owner | Shared evaluator, child retention, partial precompute, optional propagation phase, emitability, GC identity, refinalization |
| `src/passes/pass.cpp` | public registration and preset placement | CLI-visible pass identity and the plain-vs-propagate split in top-level scheduling |
| `src/passes/opt-utils.h` | nested-rerun context | Proves that nested optimizing cleanup uses the sibling `precompute-propagate` form |
| `src/wasm-interpreter.h` | semantic engine | `ConstantExpressionRunner` and `Flow` model for compile-time execution |
| `src/ir/properties.h` | helper semantics | Fallthrough and constant-expression helpers used by partial-precompute and family-level reasoning |
| `src/ir/local-graph.h` | sibling-boundary helper | Owns the extra local-worklist machinery that belongs to `precompute-propagate`, not plain `precompute` |

## Official tests and what they prove

## `test/lit/passes/precompute-effects.wast`

This is the clearest proof file for the part beginners most often miss:

- the pass can speculatively evaluate expressions,
- but still preserves local/global-writing children when the replacement would otherwise erase required writes,
- and still bails out when control-flow-sensitive child retention would become too subtle.

If you only read arithmetic examples, you miss the real pass contract.

## `test/lit/passes/precompute-partial.wast`

This file proves that plain `precompute` already has a real extra algorithm beyond direct constant folding:

- upward parent-into-`select` partial precompute
- stack-aware retry through larger parent slices
- temporary heap-cache isolation during speculation
- and the distinction between “known during speculation” and “safe to reuse globally”

This is the most important plain-mode-only test boundary to keep visible.

## `test/lit/passes/precompute_all-features.wast`

This is the broadest general-behavior oracle for plain `precompute` itself.

It proves the reviewed plain-pass contract over families like:

- ordinary scalar/control folds
- tuple constants and tuple extracts
- immutable-global and value-carrier folds
- emitability-driven positives and negatives on the all-features surface

It is the best single reminder that plain `precompute` is much wider than arithmetic-only constant folding.

## `test/lit/passes/precompute-gc.wast`

This file proves the shared GC family surface for plain `precompute`, including:

- known allocation identity versus same-contents ambiguity
- `ref.eq` outcomes that depend on identity, not structural equality
- loop and merge uncertainty that blocks direct replacement

## `test/lit/passes/precompute-gc-immutable.wast`

This file proves the immutable-heap side of the contract:

- immutable `struct.get`
- immutable `array.get`
- nested immutable reads
- and the difference between “known object” versus “known-and-emittable result”

## `test/lit/passes/precompute-gc-atomics.wast` and `precompute-gc-atomics-rmw.wast`

These files prove the atomic/synchronization boundary:

- some obvious-value GC atomic gets can fold on unshared or non-order-sensitive shapes
- seqcst or shared synchronization keeps the operation visible
- RMW and `cmpxchg` stay preserved even when their value would look obvious

That split is part of the real contract, not a local implementation accident.

## `test/lit/passes/precompute-strings.wast`

This file proves that plain `precompute` has a real string surface too, including:

- `string.eq`
- `string.concat`
- `string.measure_wtf16`
- narrow `stringview` and `string.new_wtf16_array` positives
- valid-UTF16 emitability boundaries

## `test/lit/passes/precompute-ref-func.wast`

This file proves the `ref.func` and nested branch-value surface, where plain `precompute` can collapse more control/value structure than the name suggests, while still preserving type-correct reference results.

## `test/lit/passes/precompute-relaxed.wast`

This file proves one of the easiest-to-forget negatives:

- deterministic SIMD ops may fold
- relaxed SIMD operations stay preserved because the pass will not erase their nondeterminism

For the neighboring pass that removes relaxed SIMD by replacing those operations with traps, see [`../remove-relaxed-simd/index.md`](../remove-relaxed-simd/index.md).

## `test/lit/passes/precompute-stack-switching.wast`

This file proves that stack-switching instructions stay outside the ordinary plain `precompute` fold surface, even when children look simple.

## Neighboring `precompute-propagate*` tests matter as boundary proof

The sibling files still matter for plain-pass teaching because they show what **does not** belong to plain `precompute` alone:

- `precompute-propagate-partial.wast`
- `precompute-propagate_all-features.wast`

Those files prove the extra local-get/set worklist and one-extra-rerun behavior that belongs to the sibling public pass name.

So they are part of the source map even though they are not the main proof files for plain `precompute` itself.

## Test split in one table

| Test file | Why it matters for plain `precompute` teaching | What it proves |
| --- | --- | --- |
| `precompute-effects.wast` | direct plain-pass proof | speculative evaluation plus child-retention and ordering-sensitive bailouts |
| `precompute-partial.wast` | direct plain-pass proof | upward partial-`select` precompute and temporary speculative heap-cache isolation |
| `precompute_all-features.wast` | broad plain-pass proof | scalar/control/tuple and emitability-driven family coverage |
| `precompute-gc.wast` | GC proof | allocation identity, `ref.eq`, merge/loop uncertainty |
| `precompute-gc-immutable.wast` | GC immutable proof | immutable heap reads and known-vs-emittable boundaries |
| `precompute-gc-atomics.wast` / `precompute-gc-atomics-rmw.wast` | GC atomic proof | synchronization-sensitive negatives and RMW preservation |
| `precompute-strings.wast` | string proof | string operation positives plus UTF-16 emitability boundaries |
| `precompute-ref-func.wast` | reference/control proof | branch-value and `ref.func` collapse surface |
| `precompute-relaxed.wast` | SIMD boundary proof | relaxed-SIMD nondeterminism bailout |
| `precompute-stack-switching.wast` | feature boundary proof | stack-switching preservation |
| neighboring `precompute-propagate*` files | sibling-boundary proof | the extra local-worklist and rerun behavior that belongs to `precompute-propagate` |

## What this source map says about the real contract

The source map prevents two common teaching mistakes.

### Mistake 1: treating plain `precompute` as too small

If you only look at the name or the short `pass.cpp` description, the pass can sound like ordinary constant folding.

The file/test map shows it is really:

- a shared semantic compile-time evaluator,
- with write-preserving replacement,
- partial `select` precompute,
- GC identity and emitability boundaries,
- and a broad feature-specific lit surface.

### Mistake 2: treating plain `precompute` as the whole family

If you only focus on `Precompute.cpp`, it is easy to flatten the distinction between:

- plain `precompute`
- `precompute-propagate`

The source map shows the right split:

- the core evaluator is shared,
- plain `precompute` is the top-level no-DWARF public mode,
- and the sibling adds the `LazyLocalGraph` local-worklist plus one extra rerun and is used in aggressive/nested contexts.

## Porting takeaway

If Starshine ever needs a stricter source-level re-port or refactor of plain `precompute`, this page suggests a compact checklist:

1. keep the shared evaluator core aligned with `Precompute.cpp`
2. preserve direct replacement gates based on `Flow`, emitability, and child retention
3. preserve the plain-mode partial-precompute algorithm rather than treating it as a sibling-only extra
4. use the broad lit family, not just one file, as the behavior oracle
5. keep the sibling boundary explicit so `precompute-propagate` work is not silently collapsed into the meaning of plain `precompute`

## Recommended local teaching rule

When plain `precompute` is cited elsewhere in the wiki:

- link here for the owner/test split
- link to [`./binaryen-strategy.md`](./binaryen-strategy.md) for the algorithm overview
- link to [`./propagation-partial-precompute-and-gc-identity.md`](./propagation-partial-precompute-and-gc-identity.md) for the hardest shared-family mechanics
- link to [`../precompute-propagate/index.md`](../precompute-propagate/index.md) when the neighboring public sibling matters
- avoid describing plain `precompute` as either a tiny arithmetic folder or as the whole family all by itself
