---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
---

# Binaryen `precompute-propagate` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/Precompute.cpp`.
- Public registration comes from `src/passes/pass.cpp`.
- The most important scheduler neighbor for this variant is `src/passes/opt-utils.h`, because that file shows where Binaryen prepends `precompute-propagate` during nested post-inlining cleanup.
- The most useful propagate-specific behavior files are:
  - `test/lit/passes/precompute-propagate-partial.wast`
  - `test/lit/passes/precompute-propagate_all-features.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>

## The pass in one sentence

Binaryen `precompute-propagate` is a function-parallel speculative compile-time evaluator that runs the ordinary `precompute` rewrite pipeline, then extends it with a `LazyLocalGraph`-driven local get/set worklist and one extra rerun of the main walk.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Main post-walk | Speculatively evaluate expressions bottom-up with the same machinery as plain `precompute` | Find concrete results semantically instead of matching only syntax |
| Child-retention safety | Keep required local/global writes when replacement would otherwise erase them | Preserve semantics even when the outer result becomes constant |
| Partial precompute | Push parent work into `select` arms when that shrinks the whole expression | Reach more profitable shapes than direct whole-node folding alone |
| Propagation setup | Build `LazyLocalGraph`, prove some constant sets and gets, and record proven `LocalGet*` values | Extend the evaluator's reach across local carriers |
| Main-walk rerun | Revisit the same function once with those extra get facts available | Newly propagated facts can unlock rewrites that the first walk could not prove |
| Refinalization | Repair types after rewrites | The pass changes real IR, not just metadata |

## Biggest naming fact

The easiest beginner mistake is thinking:

- `precompute-propagate` is just the same pass with a more aggressive CLI label.

The reviewed source says something narrower and more useful:

- it is the same core evaluator **plus** a real extra local-propagation phase.

So a correct teaching summary is:

- **semantic precompute with one extra local-flow-powered pass over the function**.

## Relationship to plain `precompute`

This is the most important conceptual split in the whole family.

### Shared core

Both public pass names share:

- `PrecomputingExpressionRunner`
- compile-time execution through `ConstantExpressionRunner`
- flow-sensitive replacement into constants / branches / returns / `nop`
- child-retention logic for local/global writes
- partial `select` precompute
- GC identity and emitability checks
- final `ReFinalize`

### Extra propagate-only behavior

Only `precompute-propagate` adds:

- `LazyLocalGraph`-driven reasoning over local gets and sets
- a map of concrete propagated values for some `LocalGet*`
- one extra rerun of the main walk when propagation changed anything
- all-reaching-sets consensus for propagated gets
- fallthrough-value analysis for propagated sets

That means the public distinction is not cosmetic. It affects fixed points and therefore real output shapes.

## Scheduler placement

This is one of the main reasons the pass deserves its own folder.

### What it is **not**

- It is **not** the top-level no-DWARF `-O` / `-Os` pass used by the current repo orientation page.
- Those top-level slots still use plain `precompute`.

### What it **is**

- It is the more aggressive top-level variant used at higher optimize levels and higher shrink settings.
- It is also the variant prepended by `optimizeAfterInlining(...)` before rerunning the default function optimization pipeline on changed functions.

That one scheduler rule is why this pass keeps showing up in neighboring dossiers:

- `dae-optimizing`
- `inlining-optimizing`
- aggressive pipeline notes such as the saved generated-artifact `-O4z` traces

It also explains the deliberate contrast in `simplify-globals-optimizing`: that pass reruns the default function pipeline but does **not** prepend `precompute-propagate`.

## Core algorithmic story

The durable algorithm is:

1. walk expressions bottom-up
2. speculatively evaluate them with the same bounded interpreter used by plain `precompute`
3. replace only when the result is concrete, emitable, and semantics-preserving
4. optionally perform partial-select precompute
5. if this mode is `propagate`, compute extra local facts with `LazyLocalGraph`
6. rerun the main walk once using those propagated facts
7. refinalize the function

That is a small but very real phase split.

## What the propagate phase is actually doing

The propagate phase is easy to overstate.

It is **not** a generic SCCP engine.
It is **not** a whole-program lattice pass.
It is **not** a broad dominance rewrite system.

A better model is:

- learn concrete values for some sets through their **fallthrough values**,
- learn concrete values for some gets only when **all reaching sets agree**,
- feed the proven get values back into the existing compile-time evaluator,
- and let the ordinary precompute machinery do the visible rewrites.

So the propagate phase mostly expands the evaluator's inputs instead of inventing a second unrelated optimizer.

For the exact worklist and merge-consensus mechanics, see [`./local-worklist-fallthrough-and-merge-boundaries.md`](./local-worklist-fallthrough-and-merge-boundaries.md).

## Important helper dependencies

The future-port helper surface to preserve is:

- `ConstantExpressionRunner` and `Flow`
- `LazyLocalGraph`
- `Properties`
- `EffectAnalyzer`
- `ExpressionStackWalker`
- `ReFinalize`

These helpers matter because the pass's correctness boundary depends on them.

### `ConstantExpressionRunner`

This is what makes the family semantic rather than syntax-only.
The pass is literally asking what an expression would do, under conservative limits, instead of just spotting algebraic templates.

### `LazyLocalGraph`

This is the propagate-only extension point.
It gives the pass a conservative way to know more about some `local.get`s than the first walk could know from local syntax alone.

### `EffectAnalyzer`

This prevents the pass from erasing important child writes just because the final result became a constant.

### `ReFinalize`

This repairs function types after rewrites. A future Starshine port must not treat this as optional bookkeeping.

## Important positive shapes

The propagate variant matters most on these families:

### 1. A parent expression becomes foldable only after a local carrier is resolved

Conceptually:

```wat
(local.set $x
  (i32.const 7))
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

Plain `precompute` may already simplify some direct syntax around this, but the propagate variant's extra local fact makes it easier for the evaluator to collapse the parent expression on the rerun.

### 2. Identical incoming sets after a join unlock a concrete `local.get`

Conceptually:

```wat
(local $x i32)
(if (local.get $cond)
  (then (local.set $x (i32.const 10)))
  (else (local.set $x (i32.const 10))))
(i32.add (local.get $x) (local.get $x))
```

This becomes easier to teach once the get-consensus rule is explicit: the pass is not proving one branch taken, it is proving both branches agree.

### 3. Partial `select` precompute becomes more useful after propagation

Conceptually, if the arms become locally-known constants or simpler values, the upward partial algorithm can simplify the parent more aggressively on the second pass.

### 4. The visible rewrite still comes from the ordinary evaluator

This is worth repeating.
The propagate phase does not directly “rewrite locals away” as its main contract. It mostly enables the normal precompute rewrites to succeed more often.

## Important negative and bailout shapes

### 1. Known but non-emitable values

The evaluator can know more than it is allowed to print back into IR.
That boundary still applies in propagate mode.

### 2. Required child writes

If speculative evaluation walked through local/global writes, those writes still have to be preserved when the outer expression is replaced.

### 3. Conservative loop and depth limits

Propagation does not remove the pass family's bounded-execution contract.

### 4. GC identity barriers

Propagation does not let the pass collapse distinct heap identities into one just because their contents look equal.

### 5. Params, nondefaultable-local entry reads, and mismatched incoming constants

The exact worklist logic is conservative on all three. If any of those cases blocks consensus, the extra phase simply does not help.

## Pass interactions that are easy to miss

### With `dae-optimizing` and `inlining-optimizing`

This is the most important neighbor story.
Those passes rely on `optimizeAfterInlining(...)`, which prepends `precompute-propagate` before rerunning the default function pipeline on touched functions.

So when those passes create new constant or local-carrier opportunities, `precompute-propagate` is one of the first cleanup passes that cashes them in.

### With plain `precompute`

Top-level no-DWARF `-O` / `-Os` is a good reminder that Binaryen does not always pay for the propagate step. The variant exists because the scheduler sometimes wants the lighter version.

### With `simplify-globals-optimizing`

This neighboring dossier is a deliberate contrast case: it reruns the default function pipeline on changed functions, but it intentionally does **not** prepend `precompute-propagate`.

## What a future Starshine port must preserve

1. Keep `precompute` and `precompute-propagate` as distinct public pass contracts.
2. Keep the propagate phase as an extension of the same evaluator, not a silent replacement by a broader unsourced dataflow pass.
3. Preserve child-write retention rules and emitability checks.
4. Preserve the exact local-worklist boundaries:
   - set fallthrough-value analysis
   - subtype filtering on propagated set values
   - all-reaching-sets consensus for propagated gets
   - param and nondefaultable-local entry bailouts
5. Preserve the scheduler distinction between plain no-DWARF top-level slots and aggressive or after-inlining reruns.
6. Keep GC identity boundaries explicit.
7. Preserve the one-extra-rerun flavor of the propagate mode instead of turning it into an unbounded fixed-point loop without source backing.

## Recommended teaching rule

When another wiki page mentions `precompute-propagate`, describe it as:

- the aggressive / nested-rerun sibling of `precompute`
- with an extra `LazyLocalGraph` get/set worklist
- that unlocks more of the same semantic-precompute rewrite family

Avoid describing it as generic constant propagation or as a mere CLI alias.
