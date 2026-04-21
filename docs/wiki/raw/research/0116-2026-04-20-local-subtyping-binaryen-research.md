# 0116 - `local-subtyping` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what upstream `local-subtyping` actually does, what helper analyses it depends on, which local / GC / control-flow shapes matter, and which conservative bailouts a future Starshine port must preserve.

## Why this pass

- The updated pass tracker still listed `local-subtyping` with wiki status `none`, and it was the first suggested next dossier target when this run started.
- No dedicated living folder existed yet under `docs/wiki/binaryen/passes/`, so this was still an eligible new dossier rather than overlap with an existing deep page.
- `local-subtyping` matters to both of the main local parity stories in this repo:
  - the canonical Binaryen no-DWARF `-O` / `-Os` path
  - the saved generated-artifact `-O4z` audit
- It sits in the GC/local cleanup cluster immediately after `optimize-casts` and immediately before `coalesce-locals`, which makes it especially useful for future Starshine scheduler honesty work.
- The user-facing name is easy to overread. The official pass summary sounds like a broad local-type improvement pass, but the actual implementation is a tiny collector over local gets, local sets, and `ref.as_non_null`, followed by a helper-driven type update step.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/LocalSubtyping.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/lubs.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `src/ir/local-structural-dominance.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- `README.md`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- `test/lit/passes/local-subtyping.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## Fast answer

Binaryen's `local-subtyping` pass is a **small GC/local type-narrowing pass**.

What it really does in `version_129` is:

1. look only at non-parameter locals
2. collect narrower type facts from:
   - concrete `local.get`s
   - concrete `local.set` / `local.tee`s
   - `ref.as_non_null(local.get ...)`
3. compute the least upper bound of those observed types for each local
4. ask the type-updating helpers whether that local can safely change to the narrower type
5. refinalize the function afterward

Important durable facts:

- Despite the name, this pass is **not** a general local type inference engine.
- In `version_129`, the pass body only has visitors for:
  - `LocalGet`
  - `LocalSet`
  - `RefAs`
- It does **not** directly inspect:
  - `ref.cast`
  - `br_on_cast*`
  - globals
  - tables
  - full CFG dataflow facts
- Parameters are deliberately skipped by source comment.
- Tuple locals are deliberately skipped by `TypeUpdating::canHandleAsLocal(...)`.
- The “hard” part is not collecting type facts. The hard part is the rewrite helper:
  - `LocalUpdater`
  - using `LocalStructuralDominance`
  - and sometimes adding a copy local to keep the narrowed type only where dominance makes that safe

A safer short description is:

> `local-subtyping` is Binaryen's small GC-local narrowing pass that collects concrete subtype demands from local traffic and then applies them through the dominance-aware local type updater.

That sentence matches the implementation much better than the pass name alone.

## Naming and true scope

The official README summary for `local-subtyping` is just:

- “apply more specific subtypes to locals”

That is directionally right, but it hides most of the real contract.

The implementation teaches several more exact rules:

- the pass is about **non-parameter locals**, not params and not arbitrary values
- it is only interested in **reference-typed narrowing** that the type-updating helper can handle
- it is not a generic cast-propagation pass
- it is not a generic branch-based type-refinement pass
- it is not a full liveness or CFG analysis pass like `rse`
- it relies on `LocalUpdater` to do the dangerous part of the rewrite

So the beginner-friendly mental model should be:

- collect all the concrete narrower local types Binaryen already sees in obvious places
- take the common safe type that satisfies them all
- then ask the local type-updating helper to rewrite the function around that type change safely

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` adds `local-subtyping` inside the GC-only mid/late local cleanup cluster.

In the canonical no-DWARF path tracked in this repo, the neighborhood is:

- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That ordering matters.

Binaryen explicitly comments in `pass.cpp` that:

- `local-subtyping` must run before `coalesce-locals`
- because coalescing can widen locals into a common supertype
- and then `local-subtyping` would miss narrowing opportunities

That is one of the most durable scheduler facts for a future Starshine port.

## Saved generated-artifact `-O4z` audit

The saved ordered audit in this repo records `local-subtyping` as a real missing top-level slot:

- slot `29`: `local-subtyping`

The saved Binaryen debug log also shows many later repeated executions of the same neighborhood, including runs like:

- `merge-locals -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`

So `local-subtyping` is not just a one-off top-level detail. It also matters to the optimizing nested cleanup story.

## Nested reruns

`opt-utils.h` shows that Binaryen's optimizing helpers rerun the default function optimization pipeline on changed functions.

That means `local-subtyping` can reappear inside larger optimizing passes such as:

- `dae-optimizing`
- `inlining-optimizing`
- `simplify-globals-optimizing`

For Starshine parity, the durable scheduler lesson is:

- the top-level `local-subtyping` slot matters
- the nested rerun sites matter too

## Actual implementation structure

## 1. The pass is function-parallel and post-walk

`LocalSubtyping.cpp` implements the pass as a `WalkerPass<PostWalker<LocalSubtyping>>` and reports `isFunctionParallel() == true`.

That means:

- the pass is per-function
- Binaryen can run it across functions in parallel
- the actual collection walk is post-order inside a function

Inference from the source: traversal order is not the main algorithmic story here, because the pass only adds monotonic type facts during the walk. The important behavior is the later per-local rewrite.

## 2. The pass builds one `LUBFinder` per local

At function entry, the pass creates a `LUBFinder` for each original local index.

Then it immediately seeds only the **non-parameter** locals with their existing declared type.

That seed step matters because it means:

- the pass never invents a type out of nowhere
- the existing declared local type remains part of the final least-upper-bound calculation
- if nothing narrower is learned, the local keeps its original type

## 3. Parameters are deliberately skipped

The source comment says:

- “we optimize vars, not params”
- and then adds a TODO about params plus a warning that “structural dominance is not true of named blocks”

That is a big correctness clue.

Binaryen is intentionally *not* trying to narrow parameters here, because parameter updates interact with control-flow structure and named block parameter behavior in a more delicate way.

A future Starshine port should preserve that conservatism unless it also ports the missing deeper helper logic.

## 4. Only three visitor methods add facts

The real source body is tiny.

### `visitLocalGet`

For non-parameter locals, if the get's type is concrete, Binaryen notes that type in the local's `LUBFinder`.

Why this matters:

- the pass can notice that later uses already treat the local as more specific than its declaration
- dead-code or non-concrete `unreachable`-typed gets do not pollute the calculation

### `visitLocalSet`

For non-parameter locals, if the assigned value is concrete, Binaryen notes:

- `curr->type` for a `local.tee`
- otherwise `curr->value->type`

That means a `local.tee` can contribute a slightly different fact than a plain `local.set`, because the tee result type is what later users observe directly.

### `visitRefAs`

The pass has one specialized refinement hook.

If it sees:

- `ref.as_non_null`
- whose child is exactly `local.get $x`
- and `$x` is a non-parameter local

then it records the non-null version of that heap type as another subtype fact.

This is extremely important for scope.

The pass does **not** have analogous visitor logic for:

- `ref.cast`
- `br_on_non_null`
- `br_on_cast`
- `ref.test`
- other cast/refinement instructions

So the real `version_129` scope is much smaller than the pass name suggests.

## 5. The pass computes a least upper bound, not the single narrowest observed type

After the walk, Binaryen iterates the original non-parameter locals and asks each `LUBFinder` for its `getLUB()` result.

That means the pass is looking for:

- one type that can safely cover all the observed subtype facts
- while still being as specific as possible

This is a common beginner confusion point.

The pass does **not** simply pick:

- the smallest observed type
- or the most recent observed type
- or one branch-local exact subtype

Instead it computes a common type.

For example:

- if all relevant defs/uses are `(ref null $Child)`, the local may narrow to `(ref null $Child)`
- if some are `(ref null $Left)` and others are `(ref null $Right)`, Binaryen may need the common parent or another wider shared supertype
- if plain nullable gets remain while one `ref.as_non_null` exists, the result may stay nullable because the common type must satisfy both facts

That “LUB, not narrowest leaf” rule is the core reason the pass is conservative but still useful.

## 6. Tuple locals are deliberately excluded

Before changing a local, `LocalSubtyping.cpp` checks:

- `TypeUpdating::canHandleAsLocal(lub)`
- `TypeUpdating::canHandleAsLocal(curr)`

In `type-updating.h`, `canHandleAsLocal(...)` returns false for tuple types.

So this pass intentionally skips multivalue / tuple locals.

That matters directly to this repo because the surrounding local cleanup cluster also contains tuple-sensitive passes like `tuple-optimization`.

A future Starshine port must preserve the “single-value locals only” rule unless the helper layer is widened first.

## 7. The actual rewrite is delegated to `LocalUpdater`

If the current local type and the computed LUB differ, Binaryen does **not** directly rewrite the function in `LocalSubtyping.cpp`.

Instead it builds:

- `LocalStructuralDominance dominance(func, wasm);`
- then calls `TypeUpdating::LocalUpdater(func, wasm).changeType(i, lub, &dominance);`

This is the heart of the real pass contract.

`local-subtyping` itself is only the **fact collector plus decision maker**.
The dangerous mutation work lives in the type-updating helper.

## 8. `LocalUpdater` may add a copy local instead of mutating everything in place

The comments in `type-updating.h` explain why changing a local type is tricky.

If some uses are dominated by a suitable assignment but other uses are not, Binaryen may need to:

- leave the old local in place
- create a fresh copy local with the new narrower type
- insert assignments into the copy local where the new type is valid
- redirect only dominated users to that copy local

That is a huge beginner gotcha.

The pass is not just “edit the local declaration type.”
Sometimes it is:

- change declaration type directly
- or split usage through a new copy local

That helper behavior is one of the most important facts a future Starshine port must preserve.

## 9. `LocalStructuralDominance` is the safety model for the rewrite

`local-structural-dominance.h` documents the helper used by `LocalUpdater`.

Durable facts from that helper:

- structural dominance is defined over Binaryen's structured tree, not a generic SSA CFG
- unnamed blocks do **not** matter for dominance because branches cannot target them
- named blocks and loops do matter
- catch bodies are treated as separate nested CFGs in the default mode used here

That explains both:

- the source comment about named blocks and params
- the presence of `try_table`-style tests in `local-subtyping.wast`

In other words, the safety model for this pass is not “any earlier set dominates any later get in textual order.”
It is a more careful structured-control notion.

## 10. `ReFinalize` is part of the pass contract

After the type updates, Binaryen runs:

- `ReFinalize().walkFunctionInModule(func, wasm);`

That is necessary because the helper-driven rewrite can change:

- local.get / local.set types
- local.tee result types
- reference nullability
- surrounding expression types

A future Starshine port that copies the collector logic but skips refinalization would not be an honest Binaryen port.

## Helper dependency map

## `LUBFinder`

From `src/ir/lubs.h`.

What matters here:

- it accumulates type constraints incrementally
- `getLUB()` computes a least upper bound over the noted types
- it is the reason the pass chooses a common safe type instead of the narrowest leaf subtype

## `TypeUpdating::canHandleAsLocal(...)`

From `src/ir/type-updating.h`.

What matters here:

- it limits the pass to helper-supported local types
- today that excludes tuple locals

## `TypeUpdating::LocalUpdater`

From `src/ir/type-updating.h`.

What matters here:

- it performs the actual local type change
- it may add a copy local instead of mutating one local uniformly
- it uses dominance to decide where the narrowed type is valid

## `LocalStructuralDominance`

From `src/ir/local-structural-dominance.h`.

What matters here:

- it defines the structured-control dominance relation needed by the updater
- named blocks, loops, and catches matter
- unnamed blocks do not create extra branch-target structure

## `ReFinalize`

From `src/ir/type-updating.h`.

What matters here:

- it repairs outer expression types after the local update rewrite

## What the shipped test tells us

`test/lit/passes/local-subtyping.wast` is especially useful because it shows what upstream considers worth locking here.

The visible test families include:

- ordinary narrowing from wide ref locals to more specific ref locals
- non-null refinement through `ref.as_non_null`
- multiple-assignment and common-parent cases
- dead-code / trapping-path cases where non-concrete flows do not force a wider local type
- named-block and `try_table` flavored control-flow cases
- `call_ref` and throwing shapes that keep the dominance/update story honest

That test focus matches the source architecture almost perfectly:

- small fact collection
- tricky helper-driven update
- lots of room for control-flow misunderstandings

## Important positive shapes

## Positive family 1: every concrete def/use already agrees on a narrower type

If a local is declared wide but every concrete `local.get` and `local.set` uses a more specific compatible type, Binaryen can narrow the local to that type.

Beginner summary:

- the declaration was too wide
- the actual use sites tell Binaryen a narrower compatible truth
- the pass edits the local world to match that truth

## Positive family 2: sibling subtypes narrow only to their common parent

If one path stores subtype `$Left` and another stores subtype `$Right`, Binaryen does not pick one winner.

It computes the least upper bound.

So the local may narrow from a very wide declared type to a common parent, but not all the way down to either sibling leaf.

## Positive family 3: `ref.as_non_null(local.get ...)` can contribute a non-null fact

If the pass sees `ref.as_non_null` directly on a `local.get`, it records the non-null version of that heap type as another subtype fact.

That can help narrow a nullable local when the rest of the observed local traffic agrees.

## Positive family 4: dead or non-concrete flows do not force widening

Because the visitor logic only records concrete types, `unreachable`-typed dead-code traffic does not automatically prevent narrowing.

This is why trapping or throwing test families matter.
They check that clearly-dead flows do not keep a local wider than necessary.

## Important negative / bailout shapes

## Negative family 1: parameters stay untouched

This is direct source policy today.

Even if a parameter looks narrowable, `LocalSubtyping.cpp` skips it.

## Negative family 2: tuple locals stay untouched

This is direct helper policy today.

Even if a tuple local looks structurally narrowable in theory, the pass declines it because the type-updating helper does not support that case.

## Negative family 3: `ref.cast` alone does not teach this pass anything

This is one of the easiest misunderstandings.

`local-subtyping` does **not** have a `visitRefCast` rule.

So a program that only proves a narrower type through `ref.cast` may need `optimize-casts` first to materialize better local traffic that this pass can actually see.

That is a major reason the scheduler order is:

- `optimize-casts`
- then `local-subtyping`
- then `coalesce-locals`

## Negative family 4: conflicting wide uses keep the local wide

If some concrete gets/sets still need a wider compatible type, the LUB stays wide enough to satisfy them.

So a single narrower use site does not force the whole local to that narrow type.

## Negative family 5: control structure is handled by the updater, not by smart collection

The collection phase is very dumb on purpose.

It does not reason about:

- branch predicates
- arbitrary dominance during collection
- complex control refinements

All the hard safety reasoning is deferred to `LocalUpdater` plus `LocalStructuralDominance`.

That means a port should resist the temptation to broaden the collector into a much more complicated flow analysis unless it also broadens the helper contract.

## The biggest “sounds like vs actually does” corrections

## What the name suggests

A beginner might hear `local-subtyping` and imagine:

- generic local type inference
- flow-sensitive propagation from branches and casts
- full narrowing of params and locals alike
- broad use of all GC type-refinement instructions

## What `version_129` actually does

- non-parameter locals only
- tuple locals excluded
- collects facts only from `LocalGet`, `LocalSet`, and `ref.as_non_null(local.get)`
- computes a common safe type with `LUBFinder`
- hands the actual risky rewrite to `LocalUpdater`
- relies on structural dominance and refinalization for correctness

That smaller reading is the one a future Starshine implementation should preserve first.

## Why the pass sits between `optimize-casts` and `coalesce-locals`

This scheduler placement is not decorative.

- `optimize-casts` can create or expose better narrowed local traffic
- `local-subtyping` can then tighten the local declarations to match that traffic
- `coalesce-locals` must come after, because coalescing multiple locals into one wider storage slot can erase narrowing opportunities

The explicit comment in `pass.cpp` confirms that this is an intentional dependency, not just a lucky ordering coincidence.

## Future Starshine port contract

If Starshine ports `local-subtyping`, preserve these facts first:

1. GC-gated scheduler placement after `optimize-casts` and before `coalesce-locals`
2. non-parameter-local-only scope
3. tuple-local exclusion unless the helper layer expands
4. fact collection only from `local.get`, `local.set` / `local.tee`, and `ref.as_non_null(local.get)`
5. LUB-based narrowing, not “pick the narrowest leaf subtype seen anywhere”
6. helper-driven rewrite through dominance-aware local updating
7. ability to introduce a copy local when uniform mutation is unsafe
8. structured dominance semantics for named blocks, loops, and catches
9. mandatory `ReFinalize` after mutation
10. test coverage for named-block, `try_table`, dead-code, `call_ref`, and non-null refinement families

Those are the durable upstream-level truths.

## Open questions and uncertainty

- I did not fully audit every internal code path inside `LocalUpdater::changeType(...)`; the helper comments are clear enough to establish the important contract, but a future implementation thread should inspect the exact inserted-copy-local rewrite details before porting.
- I did not line-by-line transcribe the entire `local-subtyping.wast` expected output. The important shape families are directly visible in the test file, but some exact after-forms below the helper layer are still summarized rather than exhaustively enumerated.
- The claim that traversal order is not the main story is an inference from the pass structure, not an explicit upstream comment.

## Sources

### Local sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`

### Official Binaryen `version_129`

- `LocalSubtyping.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `lubs.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `local-structural-dominance.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- `README.md`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- `local-subtyping.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
