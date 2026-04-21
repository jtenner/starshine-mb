---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./copies-subtypes-ref-tests-and-atomics.md
  - ./wat-shapes.md
  - ../global-type-optimization/index.md
  - ../global-struct-inference/index.md
---

# Binaryen `constant-field-propagation` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass family.

Primary files:

- `src/passes/ConstantFieldPropagation.cpp`
- `src/passes/pass.cpp`
- `src/ir/possible-constant.h`
- `src/ir/struct-utils.h`
- `src/ir/subtypes.h`
- `src/ir/module-utils.h`
- `test/lit/passes/cfp.wast`
- `test/lit/passes/gto_and_cfp_in_O.wast`

I also did a narrow current-`main` check on the same surfaces.
Durable result:

- the checked `main` pass file still matches the reviewed `version_129` logic on the important gates, analysis structure, and rewrite families
- the checked `main` dedicated lit file still matches on the reviewed surfaces

So this dossier treats `version_129` as the normative algorithm oracle.

## High-level intent

Binaryen uses `constant-field-propagation` to replace a later struct-field read with a known constant or immutable global when module-wide write evidence proves that every relevant dynamic instance agrees on that field value.

That is more precise than either of these summaries:

- propagate constants through structs
- fold struct.get when the constructor looks constant

The real pass is closer to:

- **collect field-write facts for struct heap types, propagate them through the subtype graph and field-copy graph, then rewrite later reads when the readable value collapses to one constant/global**

## The pass family in one table

| Variant | What it does | Why it exists |
| --- | --- | --- |
| `cfp` | Replace reads only when one constant/global value is provable | Cheap, conservative default closed-world optimization |
| `cfp-reftest` | Also use one `ref.test` + `select` when exactly two subtype-separated values are provable | More aggressive speed-oriented variant when later optimization may recover the added test cost |

## The strategy in one phase table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate on mode/features | Require GC and `--closed-world` | The pass assumes type-escape freedom and struct GC features |
| Scan writes/copies | `PCVScanner` over `StructScanner` records defaults, writes, copies, and unknown-making RMWs | Build the per-field evidence base |
| Combine function facts | Merge per-function write/copy info into module-level maps | The rewrite is module-wide even though the final mutations are per-function |
| Propagate hierarchy facts | Written values flow down to subtypes; readable values flow back up to supertypes | Inexact references may point at dynamic subtypes |
| Solve copies to a fixed point | Use a queue to push readable source facts into written destinations and repeat propagation | A copied read can feed a later write, so simple one-pass propagation is insufficient |
| Rewrite reads | `FunctionOptimizer` mutates `struct.get` / `ref.get_desc` into constant/global blocks, `drop; unreachable`, or `select(ref.test ...)` | Cash in on proven readable values |
| ReFinalize changed functions | Refinalize only mutated functions | Replacement expressions can change node types or parent types |

## Phase 0: strict gatekeeping is part of the meaning

`ConstantFieldPropagation::run(Module* module)` immediately returns when:

- `!module->features.hasGC()`

and then throws a fatal error when:

- `!getPassOptions().closedWorld`

That early fatal is part of the contract, not an incidental implementation detail.
It tells us:

- this pass is not intended as an open-world best-effort optimization
- it currently relies on the assumption that no unseen external code creates or mutates relevant struct instances
- the FIXME at the top of the file openly says multi-module GC would require type-escaping checks later

So the best beginner summary is:

- **`cfp` is closed-world by design, not just by preset accident.**

## Phase 1: `PCVScanner` collects what each field may be written with

`PCVScanner` extends the shared `StructUtils::StructScanner<PossibleConstantValues, PCVScanner>` helper.
That matters because the pass itself does not hand-walk every struct instruction from scratch.

The scanner records facts from several sources:

### `noteExpression(...)`

For ordinary writes like `struct.new`, `struct.set`, or descriptor writes, Binaryen calls `PossibleConstantValues::note(expr, wasm)`.
That helper recognizes only:

- literal constant expressions
- `global.get` of an immutable global

Everything else becomes unknown.

### `noteDefault(...)`

For `struct.new_default`, the pass records the zero literal for the field type.
That is why default-created fields can later become explicit constants.

### `noteCopy(...)`

When a field write is fed from a `struct.get`, the scanner records a copy edge instead of immediately collapsing the destination to unknown.
That is crucial.
The pass does not just propagate direct writes; it can also learn through field-to-field copies.

### `noteRMW(...)`

For RMW/cmpxchg-style writes, Binaryen marks the field unknown.
The source comment explicitly says it could in theory recognize no-op RMWs like add-zero, but intentionally leaves that to other optimization logic.

## Phase 2: the value domain is tiny on purpose

`PossibleConstantValues` is a deliberately small lattice.
It tracks only four states:

- no value seen yet
- one literal constant
- one immutable global name
- many / unknown

That means plain `cfp` is not trying to track arbitrary symbolic expressions or even “two literal constants” in the ordinary mode.
The moment two different constants conflict, the value becomes unknown.

That small domain is why the pass is fast and comprehensible.
It is also why the more aggressive exactly-two-value behavior lives only in `cfp-reftest`, not in the normal analysis summary type.

## Phase 3: exact and inexact references are different universes

The main maps are keyed by:

- heap type
- exactness
- field index

That is one of the easiest details to miss.

Binaryen distinguishes between writes through:

- `(ref $super)`
- `(ref (exact $super))`

because a write through an inexact supertype reference may target dynamic subtype instances, while an exact reference may not.

So the pass keeps separate facts for:

- exact reads/writes
- inexact reads/writes

This is a core correctness rule, not a minor implementation convenience.

## Phase 4: hierarchy propagation is asymmetric on purpose

After combining per-function information, the pass computes two related maps:

- `written`
- `readable`

The source comments explain the asymmetry clearly.

### Writes propagate downward

If a write occurs through a reference of type `(ref $super)`, the actual object written may be:

- `$super`
- or any subtype of `$super`

So written values must propagate **down** to subtypes.

### Reads propagate upward

If a read occurs through `(ref $super)`, the actual object read may also be a subtype.
So the readable value at the supertype read site must account for what any subtype might contain.

That means readable values propagate **up** to supertypes.

This is why the pass is better described as subtype-aware readable-value inference, not just constructor constant folding.

## Phase 5: copies create a real fixed point

The most important algorithmic phase is the copy fixed point.

The pass records copy edges of the form:

- field A is read
- that read value is written into field B

That creates a cycle:

- what is readable from A affects what is written to B
- what is readable from B may then affect some later copy destination C

So Binaryen cannot solve this with a single top-down propagation pass.
Instead it uses `UniqueDeferredQueue<CopyInfo>` and iterates until no copy destination gains new information.

The key logic is:

1. initialize `written` from direct writes/defaults
2. derive initial `readable` from `written`
3. for each copy edge, join readable source info into written destination info
4. whenever a destination changes, propagate that new value through subtype/supertype relations and copy edges again
5. stop when the queue is empty

That fixed point is the real center of the pass.

## Phase 6: packed fields need explicit repair

Binaryen tracks untruncated values in the analysis, but a packed field read is not the same as the original written value.
So before using a copied or read value, the pass uses `packForField(...)` to:

- mask unsigned packed reads
- sign-extend signed packed reads

That explains the packed-field lit families.

There is also an important limitation:

- if the tracked value is an immutable global, Binaryen cannot currently represent “global plus later mask/sign-extension” inside `PossibleConstantValues`
- so packed immutable-global situations often degrade to unknown

That is a real boundary, not a missed obvious optimization.

## Phase 7: `FunctionOptimizer` mutates only reads

After the module-wide analysis stabilizes, Binaryen runs `FunctionOptimizer` as a function-parallel walker.
It mutates only:

- `struct.get`
- `ref.get_desc`

It does **not** rewrite constructors, writes, or copy sites directly.

That means the pass is best understood as:

- module-wide analysis
- function-local read rewriting

not as a generic module transformer that edits every struct operation.

## Phase 8: there are three positive rewrite outcomes

### 8a. Unwritten field => `drop(ref); unreachable`

If a readable field has `hasNoted() == false`, Binaryen concludes the type is never actually created with that field reachable at runtime in the closed world.

So a read there is a logic error and can become:

- keep side effects in the ref expression
- then `unreachable`

This is why `cfp` can optimize some reads even more aggressively than a plain constant replacement.

### 8b. One constant/global => `drop(ref.as_non_null ref); value`

When a field collapses to one provable value, Binaryen replaces the read with a block that:

- explicitly traps on null using `ref.as_non_null`
- drops the checked reference
- yields the constant/global value

That preserves the original null-trap behavior.

### 8c. `cfp-reftest` only: two values => `select(..., ref.test(...))`

If ordinary constant replacement fails, the `cfp-reftest` variant may still optimize when:

- exactly two constant buckets exist
- one bucket can be separated by testing a single leaf-like subtype with no further subtypes

Then Binaryen emits a `select` guarded by `ref.test`.

This is intentionally narrow because `ref.test` can be expensive.

## Phase 9: validation repair is part of the contract

Two important repairs happen during rewriting.

### Child field type mismatch => explicit unreachable

The analysis can legitimately infer a value for a parent field that is not actually a subtype of a more refined child field type.
Instead of emitting invalid wasm, Binaryen checks subtype validity and if needed rewrites the replacement into:

- `drop(value)`
- `unreachable`

That means “the only inferred readable value is impossible here, so this path is effectively unreachable.”

### `ref.get_desc` nullable-write quirk

The source comments note that descriptor values can be written with nullable values even though successful reads cannot produce null because the write would have trapped.
After optimizing `ref.get_desc`, Binaryen may therefore need to insert `ref.as_non_null` to keep the resulting read type valid.

So validation repair is part of the actual algorithm, not postprocessing trivia.

## Scheduler placement explains why the pass exists

The repo's main no-DWARF page is open-world, so it does not mention `constant-field-propagation`.

But upstream `pass.cpp` places it in the closed-world GC/type cluster after the earlier cleanup and narrowing passes have simplified the module:

- `type-refining`
- `signature-pruning`
- `signature-refining`
- `global-refining`
- optional `gto`
- `remove-unused-module-elements`
- optional `remove-unused-types`
- optional `cfp` / `cfp-reftest`
- `gsi`

That order matters.
By the time `cfp` runs:

- dead module baggage may already be gone
- field sets/reads may already be simpler
- some fields may already be removed or frozen by `gto`
- type cleanup may already have reduced noise

And then `gsi` can reason over the cleaner post-`cfp` world.

The `gto_and_cfp_in_O.wast` test makes this visible in one compact example.

## What the pass is not

It is not:

- generic constant propagation over arbitrary code
- escape analysis for specific allocated objects
- a field-type refinement pass
- an open-world optimization
- a generic atomic optimization pass
- a broad symbolic expression simplifier

The safest beginner sentence is:

- **`cfp` replaces field reads, not arbitrary computations, and only after a very specific closed-world struct-field analysis proves a single readable value.**

## Common misunderstandings to prevent

### “A dropped allocation should not matter.”

Wrong for this pass.
The analysis is type-level, so dropped allocations still contribute evidence about what values instances of that type can contain.

### “Two constants means the pass should obviously emit a select.”

Only for `cfp-reftest`, and only under narrow subtype-test conditions.
Plain `cfp` intentionally degrades to unknown.

### “Atomics just block optimization.”

Not entirely.
Ordered atomic reads block constant replacement, but known-trapping reads can still collapse to `drop; unreachable` because trapping accesses do not synchronize.

### “This is the same thing as `type-refining`.”

No.
`type-refining` changes declared field types.
`cfp` changes later field reads when field values are provably constant/global.

### “If the field is packed, the propagated literal is still exact.”

No.
Packed reads may require masks or sign extension, and some global-based packed cases currently lose precision entirely.

## Porting checklist

A future Starshine port would need to preserve at least these behaviors:

- boundary-only/module-level placement, not a tiny isolated hot peephole
- hard closed-world requirement or an equivalent stronger proof
- exact/inexact field-fact separation
- subtype-down/read-up propagation
- copy-edge fixed point
- immutable-global as well as literal tracking
- packed-field repair
- null-trap-preserving read replacement
- explicit unreachable repair for impossible refined-child values
- atomic ordered-read bailout
- separate `cfp` versus `cfp-reftest` behavior

Any port that just folds `struct.get(struct.new(const))` shapes will miss the real Binaryen contract by a large margin.

## Bottom line

For `constant-field-propagation`, the real strategy is:

- **collect field facts module-wide, solve them over subtype and copy relations, then rewrite reads conservatively while preserving traps, exactness, packing, and synchronization boundaries.**

That is why the pass matters and why it deserved a dedicated dossier.

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
