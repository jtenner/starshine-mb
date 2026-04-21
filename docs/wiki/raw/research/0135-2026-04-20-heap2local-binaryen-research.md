# Heap2Local Binaryen Research

## Scope

- Deepen the existing `heap2local` landing page into a real Binaryen dossier.
- Use Binaryen `version_129` as the main semantic oracle.
- Explain the actual implementation structure in beginner-friendly language.
- Record the important source-visible drift from current `main` without pretending it is already a released `version_129` fact.
- Keep the result useful for future Starshine parity work in the mid-function GC/local cleanup cluster.

## Why this pass was the right target now

- The updated tracker named `heap2local` as the strongest remaining implemented landing-page target after `dead-code-elimination` was deepened.
- `heap2local` is already implemented locally, but the wiki surface was still just:
  - a short landing page
  - a parity note
- It sits in one of the most important Binaryen neighborhoods for future Starshine parity work:
  - `remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
- The saved generated-artifact `-O4z` audit already shows `heap2local` as expensive-but-successful rather than a current corruption slot, so the durable work here is understanding, documentation, and future performance/coverage guidance.

## Local source material audited first

Repo docs and trackers:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing living pages under `docs/wiki/binaryen/passes/heap2local/`
- archived note `docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md`
- saved generated-artifact audit `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- saved Binaryen debug log `.artifacts/o4z-wasm-opt-debug.log`

Current in-tree Starshine implementation surfaces:

- `src/passes/heap2local.mbt`
- `src/passes/heap2local_test.mbt`
- `src/passes/heap2local_primary_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/registry_test.mbt`

## Official upstream source-of-truth files

Primary `version_129` sources:

- `src/passes/Heap2Local.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/pass.h`
- `src/ir/type-updating.h`
- dedicated test: `test/lit/passes/heap2local.wast`

Important helper files visible directly from the includes and called APIs:

- `src/ir/branch-utils.h`
- `src/ir/eh-utils.h`
- `src/ir/local-graph.h`
- `src/ir/parents.h`
- `src/ir/bits.h`
- `src/ir/properties.h`
- `src/ir/utils.h`
- `src/wasm-builder.h`
- `src/wasm-type.h`

## Beginner summary

Binaryen `heap2local` is not a generic “promote everything from heap to stack” pass.

A better summary is:

1. find a freshly created GC object that never escapes the current function,
2. prove every reachable use is exclusive to that allocation,
3. if it is a small fixed-size array, first reinterpret it as a synthetic struct,
4. replace the object's fields with locals,
5. rewrite the uses (`struct.get`, `struct.set`, some casts/tests/comparisons, some atomic families),
6. repair types, locals, and EH shape so the result still validates.

That is more precise than the short pass-registry description in `pass.cpp`:

- `replace GC allocations with locals`

That description is accurate, but it hides almost all of the real safety work.

## Scheduler placement

### Top-level no-DWARF `-O` / `-Os`

From `pass.cpp` and the repo's canonical pathway page:

- `heap2local` runs once in the mid-function GC/local cleanup cluster.
- In the no-DWARF `-O` / `-Os` function path it sits after:
  - `remove-unused-brs`
- and before:
  - `optimize-casts`
  - `local-subtyping`
  - `coalesce-locals`
  - `local-cse`
  - `simplify-locals`

That placement is not arbitrary.

- earlier cleanup reduces junk local/control traffic first
- `heap2local` then turns some GC object traffic into ordinary locals
- later local/cast/subtyping passes can exploit the newly scalarized traffic

### Higher-aggression top-level variants

At higher optimize/shrink levels, `merge-locals` can also appear after `heap2local` and before the cast/subtyping pair.
That is important for understanding the saved `-O4z` audit and the future neighbor docs.

### Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` reuses the default function optimization pipeline after inlining-related boundary passes.
That means `heap2local` is not just a one-time top-level pass.

The saved local debug log confirms that directly:

- `.artifacts/o4z-wasm-opt-debug.log` contains `18` `running pass: heap2local` lines

So future parity work must not model `heap2local` as “one slot only.”

## Actual implementation structure in `Heap2Local.cpp`

The file has four big moving parts:

1. `EscapeAnalyzer`
2. `Struct2Local`
3. `Array2Struct`
4. `Heap2Local` / `Heap2LocalPass`

### 1. `EscapeAnalyzer`

This is the real semantic gate.

It proves two things about one allocation:

1. the allocation does not escape the function
2. every use is exclusive to that allocation

The key internal enum is `ParentChildInteraction`:

- `Escapes`
- `FullyConsumes`
- `Flows`
- `Mixes`
- `None`

That enum is the heart of the pass.
It explains why `heap2local` is not just “replace allocation with locals if it looks simple.”
Binaryen explicitly distinguishes:

- parents that safely consume the allocation
- parents that safely pass it onward
- parents that mix the allocation with other possible values
- parents that let it escape

The main data structures used by the analyzer are:

- `LazyLocalGraph`
  - to follow local-set/local-get flows and check exclusivity
- `Parents`
  - to walk child -> parent flow
- `BranchUtils::BranchTargets`
  - to follow branch-sent values to target blocks
- `ScratchInfo`
  - to record synthetic locals inserted during rewrites so later analysis still understands those new temporary flows

The algorithm is a queue of `(child, parent)` flows.
It starts from the allocation and keeps walking outward through:

- parents
- local sets/gets
- branch-sent values

If it ever sees `Escapes` or `Mixes`, the candidate is rejected.
If it reaches only `FullyConsumes` and `Flows`, it performs a final exclusivity check over the affected local gets.

### 2. `Struct2Local`

Once the allocation is known safe, `Struct2Local` performs the actual field-to-local rewrite.

Important details from the source:

- it allocates one fresh local per struct field
- if the allocation has a descriptor, it allocates an extra descriptor local
- it may allocate extra scratch locals to preserve evaluation order while computing initializer expressions
- it often replaces the original allocation with `ref.null`, not with “nothing”

That `ref.null` placeholder is intentional.
It keeps the surrounding IR valid while later rewrites remove or widen the remaining reference traffic.

This rewrite handles much more than plain `struct.get` / `struct.set`:

- `ref.is_null`
- `ref.eq`
- `ref.as_non_null`
- `ref.test`
- `ref.cast`
- `ref.get_desc`
- packed `struct.get_s` / `struct.get_u`
- `struct.rmw`
- `struct.cmpxchg`
- `array.cmpxchg` in the special case where the optimized allocation flows through the `expected` input rather than the `ref`

### 3. `Array2Struct`

Binaryen does not scalarize arrays directly in the same way Starshine currently does.
Instead it lowers eligible arrays into a synthetic struct first, then reuses `Struct2Local`.

That is a big conceptual point.

`Array2Struct` only accepts arrays that are sufficiently struct-like:

- `array.new`, `array.new_default`, or `array.new_fixed`
- size must be constant
- size must be `< 20`
- later indexed access must be analyzable

It builds a synthetic struct type with one field per array slot, preserving sharedness.
Then it rewrites:

- `array.set` -> `struct.set`
- `array.get` -> `struct.get`
- `array.rmw` -> `struct.rmw`
- `array.cmpxchg` -> `struct.cmpxchg` when the optimized allocation is the `ref`
- `ref.test` / `ref.cast` on arrays using the original array type semantics before the new struct type would change the answer

That split between “original array type semantics” and “new synthetic struct mechanics” is easy to miss and important to preserve.

### 4. `Heap2Local` and `Heap2LocalPass`

`Heap2Local` owns per-function reusable analyses:

- `LazyLocalGraph`
- `ScratchInfo`
- `Parents`
- `BranchUtils::BranchTargets`

It also runs `AllocationFinder` once to collect:

- reachable `StructNew`
- reachable eligible `ArrayNew`
- reachable eligible `ArrayNewFixed`
- a boolean `hasPop` flag

Then it does:

1. arrays first
2. structs second
3. EH `pop` fixup at the end if anything changed

The pass itself is explicitly function-parallel:

- `Heap2LocalPass::isFunctionParallel() == true`

That matters for both scheduler expectations and performance expectations.

## Important helper dependencies and what they mean

### `LazyLocalGraph`

This is not just a convenience.
It is how Binaryen proves exclusivity for locals.

The crucial check is:

- every `local.get` reachable from the candidate's writing sets must read only from those same sets

If a later `local.get` could read from some other set, the optimization is rejected.

That is why mixed param/local provenance, `select` merges, and loop-carried ambiguity are bailouts.

### `Parents`

This supports the child-to-parent walk.
Without it, the analyzer would know what the allocation is used by directly, but not how that value keeps flowing upward through blocks, loops, casts, and branches.

### `BranchUtils`

Two uses matter:

- `BranchTargets`
  - map branch names to their target scopes
- `operateOnScopeNameUsesAndSentValues(...)`
  - find branches that send the optimized allocation as a branch value

This is what allows the pass to reason about the special case:

- a branch to a block is okay **only** when that branch is the sole value reaching the block and there is no competing fallthrough value

### `Bits::makePackedFieldGet`

Packed fields and packed array elements do not simply become plain local gets.
Binaryen preserves the signed/unsigned semantics by reconstructing the truncation/sign-extension logic on the rewritten local traffic.

That is an important non-obvious correctness detail.

### `EHUtils::handleBlockNestedPops`

If the function contains `pop` and the rewrite created blocks, nested-pop structure may have become invalid.
Binaryen repairs that explicitly after the optimization.

### `ReFinalize`

The pass cannot rely on old expression types after changing:

- nullability
- cast behavior
- OOB array operations into explicit `unreachable`
- flowing reference types generalized to the synthetic struct type or to nullable variants

So both `Struct2Local` and `Array2Struct` can set `refinalize = true` and run `ReFinalize()` when needed.

### `TypeUpdating::handleNonDefaultableLocals`

This is easy to miss because it does **not** appear in `Heap2Local.cpp` itself.
It happens through the pass framework.

In `pass.h`, `Pass::requiresNonNullableLocalFixups()` defaults to `true`.
`Heap2LocalPass` does not override that.
So after the pass modifies Binaryen IR, `PassRunner::handleAfterEffects(...)` runs:

- `TypeUpdating::handleNonDefaultableLocals(func, wasm)`

That means nondefaultable local repair is part of the real Binaryen pass boundary even when it is not spelled out in the pass file's main algorithm.

## Positive transformation families

Source + test-backed or source-backed positive shapes include:

### Struct families

- direct `struct.new` / `struct.new_default` consumed by `struct.get`
- allocation stored to a local, then accessed only through exclusive `local.get`s
- local copy chains where every reachable copy remains the same allocation
- direct `local.tee` owners
- block and loop result flow where the value remains exclusive
- branch-to-block flow where that branch is the sole exiting value
- descriptor-bearing `struct.new_desc` / `struct.new_default_desc`
- `ref.get_desc`
- `ref.as_non_null`
- `ref.is_null`
- `ref.eq`
- `ref.test`
- `ref.cast`
- packed gets (`struct.get_s`, `struct.get_u`)
- `struct.rmw`
- `struct.cmpxchg`

### Array families

- `array.new_default`, `array.new`, `array.new_fixed`
- size constant and `< 20`
- constant-index `array.get`, `array.get_s`, `array.get_u`, `array.set`
- array `ref.test`
- array `ref.cast`
- array atomic get/set/RMW/cmpxchg once the array has been converted into a struct-like shape and the interaction rules still hold

### Validation/repair families

- failing casts become explicit `unreachable`
- OOB array accesses become explicit `unreachable`
- flowing ref types can be widened to nullable or retargeted to the synthetic struct type
- nested EH `pop` shapes are repaired after rewriting

## Negative and bailout families

Important bailouts from the source and tests:

- allocation returned from the function body or via `return`
- allocation passed to a call
- allocation stored in a way that escapes heap identity outward
- non-exclusive local provenance
- `select` / if-else mixing of different possible reference values
- array size not constant
- array size `>= 20`
- nonconstant array indexes when the optimized allocation is the accessed array ref
- branch targets with competing sent values or competing fallthrough values
- unreachable allocations are ignored and left for other cleanup (`dce`)

A useful beginner summary is:

- `heap2local` is conservative by design
- it prefers to miss an optimization rather than accidentally scalarize a reference whose identity can still matter

## Important non-obvious corner cases

### 1. Arrays are only “small fixed structs in disguise” here

Binaryen is not optimizing arbitrary arrays.
It is optimizing a small, fixed, constant-index subset that can be reinterpreted as a synthetic struct safely.

### 2. The pass is single-iteration by design

The file comment and tests make this explicit.
If optimizing one allocation would expose a second now-nonescaping allocation, the pass does not keep looping until fixpoint.
It depends on later cleanup (especially `vacuum`) plus a later rerun of `heap2local` in another optimization round.

### 3. Non-nullability repair happens in two layers

There are two separate stories:

- in-pass rewrites often replace removed ref traffic with nullable `ref.null`
- pass-runner post-fixups then make nondefaultable locals valid again

If you only notice one of those layers, the pass looks inconsistent.
It is not; the repair work is split across the pass body and the generic pass framework.

### 4. Packed access semantics are preserved, not erased

Scalarization does **not** mean “forget the original field representation.”
Packed fields still need masking or sign-extension.

### 5. Atomic accesses are still optimizable when the object never escapes

This is surprisingly subtle and important.
The source explicitly notes that once the object never escapes the function, those accesses cannot synchronize with another thread through that object identity.
So Binaryen can lower them to local operations without keeping fences in the same way.

### 6. Descriptor and `ref.cast_desc_eq*` support is more visible in source than in the dedicated lit test

The source contains handling for:

- descriptor-bearing struct allocations
- `ref.get_desc`
- descriptor-based casts

The dedicated `heap2local.wast` surface in `version_129` does **not** visibly exercise all of those families.
So part of the durable contract here is source-backed rather than lit-backed.
That should be stated honestly.

## What current `main` changed after `version_129`

A narrow 2026-04-20 direct source comparison found the following real drift in `main/src/passes/Heap2Local.cpp`:

1. `EscapeAnalyzer` is more precise for array operations.
   - Nonconstant array indexes are now only an analysis barrier when the optimized allocation flows as the accessed `ref`, not when it flows as some other operand.
2. `ArrayCmpxchg` / `StructCmpxchg` handling is reordered and refined.
   - current `main` more clearly separates the “optimized allocation is the `ref`” case from the “optimized allocation is the `expected` value” case
   - current `main` also preserves dynamic array indexes via scratch locals in one of those later cases
3. `visitRefTest` now explicitly leaves unreachable code alone instead of rewriting it to a concrete constant there.

The dedicated `heap2local.wast` file on `main` changed only by a typo fix (`vaccum` -> `vacuum`).
So the current drift is source-visible, but the owning lit file does not appear to have gained matching new direct coverage yet.

Inference from that evidence:

- `version_129` is still the right released oracle for the dossier
- but a future Starshine port should be aware that current trunk already tightened some array/cmpxchg/unreachable corner cases beyond the tag

## Current Starshine comparison

The local implementation already matches a substantial subset and has good parity evidence:

- green primary suite in `src/passes/heap2local_primary_test.mbt`
- green `10000`-case `gen-valid` compare from the archived `0075` note
- green `200`-case smoke rerun in `0078`
- current backlog says the remaining local gap is mainly:
  - non-nullable-local / refinalization fixups
  - the wider missing neighbor cluster after `heap2local`

But the local implementation is still much narrower than the full upstream surface in some key ways:

- no Binaryen-style parent/branch/local exclusivity engine
- no array-to-struct stage
- no full source-level handling for the wider cast/test/atomic/cmpxchg families
- no automatic Binaryen-style nondefaultable-local fixup layer documented in the local pass machinery

That gap is exactly why the dossier needed expansion.

## What a future Starshine port must preserve

1. **Escape + exclusivity are separate requirements**
   - proving “does not escape” is not enough
2. **Array support is intentionally narrow**
   - constant size, `< 20`, constant-index struct-like use
3. **Arrays lower through a synthetic struct stage upstream**
   - do not casually skip that if parity is the goal
4. **Nullability and type repair are part of the contract**
   - they are not cleanup polish
5. **Packed semantics must survive scalarization**
6. **Atomic/reference special cases exist**
   - even if the first local port leaves some of them out, the dossier should keep them visible
7. **Single-iteration behavior is intentional**
   - later reruns and neighbors matter
8. **Scheduler placement matters**
   - the pass is there to make later local/cast/subtyping cleanup more profitable

## Suggested living-page split for this ingest

The living folder should make these subtopics easy to navigate:

- landing page: what the pass really is and why it matters
- strategy page: algorithm and helper dependencies
- shape page: positive, negative, bailout WAT families
- special-cases page: non-nullable locals, refinalize, packed/atomic/descriptor oddities, source-vs-test coverage, and post-`version_129` drift
- Starshine page: what the local implementation actually does today

## Sources

- Binaryen `version_129`:
  - `src/passes/Heap2Local.cpp`
  - `src/passes/pass.cpp`
  - `src/passes/opt-utils.h`
  - `src/pass.h`
  - `src/ir/type-updating.h`
  - `test/lit/passes/heap2local.wast`
- Binaryen `main` narrow freshness check:
  - `src/passes/Heap2Local.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/heap2local.wast`
- Local repo sources listed in the scope section above
