---
title: Binaryen simplify-locals-notee research
kind: research
status: supported
last_reviewed: 2026-04-21
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast
  - ../../binaryen/passes/tracker.md
  - ../../binaryen/passes/index.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals/variant-matrix-and-scheduler.md
  - ../../binaryen/passes/simplify-locals-notee/index.md
---

# Binaryen `simplify-locals-notee` research

## Why this pass was chosen

The current tracker already showed the original no-DWARF queue closed, the saved generated-artifact `-O4z` skipped-slot queue closed, and the first expansion wave of upstream-only registry passes dossier-covered.
So this thread could not honestly pick another `wiki status = none` row from the existing tracker tables.

I therefore expanded the tracker with a new **source-backed upstream-only registry candidate**:

- upstream public pass name: `simplify-locals-notee`
- current local removed-registry placeholder: `simplify-locals-no-tee`

This pass is a good expansion target because:

1. it is still named in `src/passes/optimize.mbt`
2. it is a real public Binaryen CLI pass in `version_129`, not just an internal helper mode
3. it sits directly beside already-documented neighbors:
   - `simplify-locals`
   - `simplify-locals-nostructure`
   - `simplify-locals-notee-nostructure`
4. it is easy to misunderstand from the name alone
5. the current living wiki explained the five-variant matrix in the full `simplify-locals` dossier, but did **not** yet give the `-notee` variant its own canonical landing page, scheduler note, or shape catalog

## Backlog-slice check

`agent-todo.md` does **not** have a dedicated slice for `simplify-locals-notee` or the local removed-registry spelling `simplify-locals-no-tee`.

That matters because this dossier is research-first and scheduler/registry-first, not a direct implementation handoff tied to an already-scoped local slice.

## Main correction

The beginner mistake is:

- “`simplify-locals-notee` is just `simplify-locals` but a little weaker.”

The more accurate source-backed summary is:

- Binaryen instantiates the same templated locals engine with `allowTee = false`, `allowStructure = true`, and `allowNesting = true`
- so this variant still performs:
  - direct single-use sinking
  - block / `if` / loop result synthesis
  - late equivalent-copy cleanup
  - final dead-set cleanup
- but it refuses the specific multi-use rewrite that would introduce a new `local.tee`

So `-notee` is **not**:

- no-structure
- nonesting
- dead-set-only cleanup
- a separate algorithm unrelated to the full pass

It is the same staged locals pass family with one semantic switch disabled.

## Official source map

Primary upstream sources used here:

- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`

Important helper dependencies pulled in by `SimplifyLocals.cpp`:

- `src/ir/linear-execution.h`
- `src/ir/effects.h`
- `src/ir/equivalent_sets.h`
- `src/ir/local-utils.h`
- `src/ir/branch-utils.h`
- `src/ir/manipulation.h`

Most important upstream tests:

- `test/passes/simplify-locals-notee.wast`
- `test/passes/simplify-locals-notee.txt`
- comparison surfaces from:
  - `test/passes/simplify-locals.wast`
  - `test/passes/simplify-locals-nostructure.wast`
  - `test/passes/simplify-locals-nonesting.wast`

## Public name and local-registry alias mismatch

One durable local doc problem was the spelling mismatch:

- Binaryen public name in `pass.cpp`: `simplify-locals-notee`
- local removed-registry spelling in `src/passes/optimize.mbt`: `simplify-locals-no-tee`

That mismatch is important enough to document explicitly because future port work can otherwise confuse:

- an upstream CLI/pass-manager name
- a local placeholder/registry spelling
- the already-documented sibling `simplify-locals-notee-nostructure`

## Exact upstream registration and implementation identity

In `pass.cpp`, Binaryen registers five public variants from one family:

- `simplify-locals`
- `simplify-locals-nonesting`
- `simplify-locals-notee`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`

In `SimplifyLocals.cpp`, the factory is explicit:

- `createSimplifyLocalsNoTeePass()` returns `new SimplifyLocals<false, true>()`

That means `simplify-locals-notee` is exactly:

- `allowTee = false`
- `allowStructure = true`
- `allowNesting = true`

## What the implementation actually does

## Phase 1: repeated main sinking cycles

The pass is function-parallel and runs in cycles.
Important state includes:

- pending `sinkables` keyed by local index
- block-exit tracking for structured value synthesis
- `if`-branch merge bookkeeping
- `LocalGetCounter`
- a `firstCycle` flag
- an `anotherCycle` flag
- optional `refinalize`

The main walk uses `LinearExecutionWalker`, not a whole-function CFG solver.
That matters because legality is mostly about:

- current linear trace
- effect ordering
- when control flow splits and invalidates facts

## Phase 2: direct sinking into `local.get`

When the walker reaches a `local.get`, it checks whether there is a pending sinkable `local.set` for the same index.

If there is:

- on first cycle, or when the local has one use, it can sink only the set value
- on later cycles, if multiple uses remain, the full pass may create a `tee`
- but in `simplify-locals-notee`, the multi-use path is rejected because `allowTee = false`

The relevant source gate is `canSink(...)`:

- if this is the first cycle, or teeing is disallowed, and the local has more than one use, the set is not sinkable

So the pass deliberately keeps first-cycle behavior stricter even for the full variant, then becomes more aggressive later. The `-notee` variant keeps that stricter multi-use rule permanently.

## Phase 3: structure formation still exists here

Because `allowStructure = true`, `simplify-locals-notee` still performs the structured half of the family.

The source still calls helpers such as:

- `optimizeIfReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeLoopReturn(...)`

That means `-notee` can still turn multiple internal `local.set`s into direct structured result flow, for example:

- an `if` returning a value instead of storing to a local inside each arm
- a named block returning a branch payload instead of storing then reading later

This is the biggest reason `-notee` deserves its own dossier instead of being hand-waved as a trivial alias.

## Phase 4: effect and control barriers are shared with the family

`visitPre(...)` and `visitPost(...)` use `EffectAnalyzer` to invalidate pending sinks when motion would reorder something unsafe.

Important barriers include:

- operations ordered after pending effects
- entering `try` / `try_table` when the candidate may throw
- non-linear control flow that poisons block-return synthesis or trace-local facts
- dangling EH pops

So `-notee` is not a “freely inline locals” pass.
It is still the same effect-aware movement engine as full `simplify-locals`.

## Phase 5: late equivalent-copy optimization still runs

After the main cycles settle, the pass runs `runLateOptimizations(...)`.
That creates an `EquivalentOptimizer` over `EquivalentSets`.

This phase:

- removes or ignores redundant `local.set x (local.get y)` copies when `x` and `y` already hold equivalent values
- canonicalizes `local.get`s toward a better representative
- may prefer a more refined type even if the alternative local has fewer gets
- can request `ReFinalize` when the chosen representative has a more refined type

Because `allowStructure = true`, `removeEquivalentSets` remains enabled here.
So `-notee` still does meaningful late cleanup beyond first-order sink/no-sink behavior.

## Phase 6: final dead-set cleanup still runs

`UnneededSetRemover` runs after the equivalent-copy phase.
So even if `-notee` refuses a multi-use tee rewrite, it can still make later sets disappear when preceding rewrites or canonicalization reduce local use counts to zero.

## Scheduler placement

## Not part of canonical no-DWARF `-O` / `-Os`

The canonical repo page for Binaryen's no-DWARF default path shows:

- early `simplify-locals-nostructure`
- later full `simplify-locals`

It does **not** show `simplify-locals-notee` in that path.
So this pass is outside the main parity queue, which is why a tracker expansion had to be justified explicitly.

## But still a real public upstream pass

Even though the default no-DWARF pipeline does not schedule it, `pass.cpp` still exposes it as a public pass.
That makes it a legitimate registry/wiki target in this repo, especially because:

- the local registry already names it
- the family-level docs now discuss the exact variant matrix
- the alias mismatch needed a stable home

## Relation to neighboring variants

### Versus full `simplify-locals`

Shared:

- direct sinking
- structure synthesis
- late equivalent-copy cleanup
- dead-set cleanup
- effect barriers
- type-refinalization when needed

Different:

- full `simplify-locals` may create a `tee` on later cycles for multi-use sinks
- `simplify-locals-notee` never does

### Versus `simplify-locals-nostructure`

Shared:

- teeing may be relevant in the family-level algorithm design
- direct sinking rules and barriers are similar

Different:

- `-nostructure` allows tees but forbids block/if/loop result synthesis
- `-notee` forbids tees but still allows structure synthesis

This crossed difference is exactly why beginners confuse the names.

### Versus `simplify-locals-notee-nostructure`

`-notee-nostructure` disables both features.
So compared with `-notee`, it is deliberately flatter and narrower.

A common mistake is to think the already-documented `-notee-nostructure` dossier already covered `-notee` well enough.
It did not, because `-notee` still has the structure-formation half active.

### Versus `simplify-locals-nonesting`

`-nonesting` is stronger still:

- no tees
- no structure synthesis
- no new nesting at all

So `-notee` is much closer to the full pass than to `-nonesting`.

## Important WAT / IR shapes

## Positive shapes

### 1. Single-use sink stays valid

If a local is written once and read once later, `-notee` can still sink directly.

Shape:

```wat
(local.set $x EXPR)
...safe stuff...
(drop (local.get $x))
```

can become roughly:

```wat
(drop EXPR)
```

if barriers and type constraints allow.

### 2. Structured `if` value formation still happens

The shipped `simplify-locals-notee` test proves the pass can still rewrite per-arm stores into a value-returning `if` wrapped in `drop`.

Conceptually:

```wat
(if COND
  (then (local.set $a A))
  (else (local.set $a B)))
(drop (local.get $a))
```

becomes:

```wat
(drop
  (if (result t) COND
    (then A)
    (else B)))
```

with preserved `nop`s or wrapper structure as needed.

### 3. Structured named-block payload formation still happens

The dedicated `simplify-locals-notee` fixture also proves a named block plus branch can be rewritten to return a payload directly to the block result instead of routing through a local.

### 4. Simple block result sinks still happen

A local set from a value block, then immediate use, can still become a dropped block result.

## Negative / bailout shapes

### 1. Multi-use sink that would require a tee

This is the signature negative case.
If a pending set has multiple later uses, `-notee` declines the tee-based rewrite that full `simplify-locals` might do on a later cycle.

### 2. Effect reordering hazards

Calls, stores, throwing code, and other ordered effects can invalidate pending sinkables.

### 3. EH pop and try-boundary hazards

Candidates with dangling EH pops are rejected, and motion into `try` / `try_table` is restricted when throwing behavior would change.

### 4. Non-linear trace poison

Whenever control flow becomes hard enough that the linear-trace model loses confidence, facts are cleared instead of guessed through.

## What is easy to misunderstand

## Misunderstanding 1: “No tee” means “single-pass only.”

False.
The pass still iterates, still runs late optimizations, and can still trigger more main work after those late optimizations.

## Misunderstanding 2: “No tee” means “no structure.”

False.
The implementation identity `SimplifyLocals<false, true>` proves structure remains enabled.

## Misunderstanding 3: “The `-notee-nostructure` dossier already covers this.”

Not enough.
That sibling documents the stricter pairwise-disabled variant.
It does not teach the important fact that `-notee` still rewrites blocks and `if`s to return values directly.

## Misunderstanding 4: “If the default pipeline does not use it, it is not worth tracking.”

False.
The local registry already tracks it, upstream still exposes it, and the spelling mismatch made it a durable source of confusion for future port work.

## Future Starshine port rules

If Starshine ever ports this pass honestly, preserve these source-backed rules:

1. map the upstream public name and the local registry alias explicitly
2. keep the true semantic identity:
   - no tee creation
   - structure still allowed
   - nesting still allowed
3. reuse the same barrier model as the `simplify-locals` family, not a toy peephole implementation
4. keep the late `EquivalentSets` and `UnneededSetRemover` phases in scope
5. do not collapse it into either:
   - `simplify-locals-nostructure`
   - `simplify-locals-notee-nostructure`
6. document clearly that it is outside the canonical no-DWARF path unless future upstream evidence changes that

## Confidence and open questions

Confidence is high on:

- pass naming and registration
- exact template identity
- the tee-vs-structure semantic split
- the dedicated test-proven shape families

Open questions left intentionally narrow:

- current repo work does not yet need a scheduler parity claim beyond “not in canonical no-DWARF `-O` / `-Os`”
- I did not find a local implementation slice in `agent-todo.md`, so any future implementation plan still needs a fresh backlog cut

## Durable conclusion

`simplify-locals-notee` is a real public Binaryen pass and a real local-registry candidate.
It is not redundant with the already-documented `simplify-locals-notee-nostructure` sibling.

The essential teaching point is simple:

- `simplify-locals-notee` disables tee creation
- but it still keeps the structured result-forming half of Binaryen's locals pass family alive

That one distinction is enough to change both its rewrite surface and how a future port must be designed.
