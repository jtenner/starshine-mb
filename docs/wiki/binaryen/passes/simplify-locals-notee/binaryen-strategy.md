---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md
  - ../../../raw/research/0329-2026-04-24-simplify-locals-notee-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
---

# Binaryen `simplify-locals-notee` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle.
The 2026-04-24 immutable raw manifest for this page is [`../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md).

Primary files:

- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies used by the implementation:

- `src/ir/linear-execution.h`
- `src/ir/effects.h`
- `src/ir/equivalent_sets.h`
- `src/ir/local-utils.h`
- `src/ir/branch-utils.h`
- `src/ir/manipulation.h`

Most important tests for this exact variant:

- `test/passes/simplify-locals-notee.wast`
- `test/passes/simplify-locals-notee.txt`

## Exact implementation identity

`pass.cpp` registers:

- `simplify-locals-notee`

and `SimplifyLocals.cpp` implements that public pass with:

- `createSimplifyLocalsNoTeePass()`
- `new SimplifyLocals<false, true>()`

So the real identity is `SimplifyLocals<false, true>` in source syntax, or `SimplifyLocals<false, true, true>` when the default `allowNesting = true` template parameter is made explicit for teaching:

| Template switch | Value | Meaning |
| --- | --- | --- |
| `allowTee` | `false` | do not create new `local.tee` during multi-use sinking |
| `allowStructure` | `true` | still allow block / `if` / loop result synthesis |
| `allowNesting` | `true` | still allow ordinary sinks that create nesting |

That is the key contract.

## High-level intent

Binaryen uses this pass to clean local traffic with the same staged family logic as full `simplify-locals`, but without the rewrite that would keep the first use in place by turning the original `local.set` into a `local.tee`.

A good beginner summary is:

- sink easy locals
- still form structured result values when useful
- still clean equivalent copies and dead sets later
- but never pay for a new tee-based multi-use sink

## Algorithm phases

## Phase 1: repeated main walk over linear execution

The pass is function-parallel and works in cycles.
State includes:

- `sinkables`
- block-exit bookkeeping for branch-payload and fallthrough cases
- `if` merge bookkeeping
- `LocalGetCounter`
- `firstCycle`
- `anotherCycle`
- optional `refinalize`

The walker base is `LinearExecutionWalker`, which means the pass is deliberately built on a cheap structured linear-trace model rather than a full CFG solver.

## Phase 2: gather sinkable `local.set`s

When the main walk sees a `local.set`, it can become pending work if `canSink(set)` says yes.

Important gates in `canSink(...)`:

- a tee is never moved
- values with dangling EH `pop` behavior are rejected
- on first cycle, or when tees are disallowed, a set with more than one use is rejected

That last gate is the signature `-notee` rule.

## Phase 3: sink into later `local.get`s when legal

When the walker reaches a matching `local.get`, `optimizeLocalGet(...)` tries to rewrite.

Positive cases:

- if there is one use, replace the get with the set value directly
- if there is only one use because it is the first cycle, the same direct rewrite applies

Negative case specific to this variant:

- if multiple uses remain, the full pass could eventually create a tee
- `simplify-locals-notee` refuses that path because `allowTee = false`

This is why the pass name is literal, but also why it is easy to overread it: the tee restriction is narrow, not total-family-wide.

## Phase 4: structure formation still runs

Because `allowStructure = true`, the pass still runs the structure-building helpers.

Those include:

- `optimizeBlockReturn(...)`
- `optimizeIfReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeLoopReturn(...)`

So this variant can still rewrite local-mediated control results into direct structured values.

That is the main difference from `simplify-locals-notee-nostructure`.

## Phase 5: effect-aware invalidation

`visitPre(...)` and `visitPost(...)` build `EffectAnalyzer` summaries and use `checkInvalidations(...)` to drop pending sinks that would become illegal if moved farther.

This means the pass is conservative around:

- ordered side effects
- throwing code
- try-region motion
- non-linear control transfers

So even though the pass feels syntactic from the name, it is still an effect-aware movement pass.

## Phase 6: late equivalent-copy optimization

After the main cycles stop making progress, `runLateOptimizations(...)` runs an `EquivalentOptimizer` on `EquivalentSets`.

That phase does two important jobs:

1. remove or ignore redundant local copies
2. canonicalize gets toward a better representative local

The representative-selection logic is not trivial.
It prefers:

- more refined local types, when subtype-safe
- otherwise the representative with more gets, to maximize later dead-local opportunities

This phase can also request `ReFinalize` if a rewritten `local.get` switches to a more refined type.

## Phase 7: final dead-set cleanup

The last explicit phase is `UnneededSetRemover`.
So the pass contract is not complete after sinking and equivalent-copy cleanup; it also includes final removal of sets to now-unused locals.

## Phase 8: refinalization

The pass may refinalize in two places:

- after main sinking changes, when a replacement makes a user observe a more refined type
- after equivalent-copy canonicalization, for the same reason

This matters especially on GC/reference-typed users.

## Scheduler facts

## Public pass, but not in canonical no-DWARF default optimize path

The repo's canonical no-DWARF page records:

- early `simplify-locals-nostructure`
- later full `simplify-locals`

It does not include `simplify-locals-notee`.

So this pass is not part of the main parity queue for the MoonBit debug artifact's default `-O` / `-Os` path.

## Why it still belongs in the local tracker

Despite that scheduler fact, it still belongs in the registry/wiki because:

- upstream publicly registers it
- the local registry already tracks the alias spelling
- it explains an important corner of the larger simplify-locals family
- it prevents future work from conflating `-notee` with `-nostructure` or `-notee-nostructure`

## Important pass interactions

### With `coalesce-locals`

The source comments around the normal scheduler explain why early no-structure cleanup exists before coalescing and why later full cleanup runs after it.
That general family logic still matters here: tee and structure choices can expose or inhibit later local cleanup opportunities.

### With `vacuum`

Like the other simplify-locals family members, this pass can leave behind `nop`s and dead wrappers that later cleanup passes remove.

### With the other simplify-locals variants

This pass is best understood as one point in a 3-axis family matrix, not as a standalone invention.
Its living docs should stay linked to the full family dossier.

## Easy misunderstandings

## Mistake 1: `-notee` means no structure.

Wrong.
The template identity `SimplifyLocals<false, true>` proves the opposite.

## Mistake 2: `-notee` means no nesting.

Wrong.
Only `-nonesting` disables new nesting globally.

## Mistake 3: `-notee` is just dead-set cleanup plus copy cleanup.

Wrong.
It still does the main sink-and-structure walk first.

## Mistake 4: the pass only matters if a default preset uses it.

Wrong.
In this repo it also matters because the local registry names it, the spelling differs from upstream, and the existing family docs were not enough on their own.

## Starshine mapping note

The current Starshine implementation is not a sibling mode yet.
`src/passes/simplify_locals.mbt` implements active full `simplify-locals`, while `src/passes/optimize.mbt` tracks the local alias `simplify-locals-no-tee` only as a removed name and does not register the upstream spelling `simplify-locals-notee`.
See [`./starshine-strategy.md`](./starshine-strategy.md) for the exact code map and future HOT-mode landing zone.

## Bottom line

Binaryen `simplify-locals-notee` is the same staged locals optimization family as `simplify-locals`, with one switch turned off:

- no new tees
- structure still allowed
- nesting still allowed

That narrow-looking difference changes the multi-use rewrite surface enough that it deserved its own canonical dossier page.
