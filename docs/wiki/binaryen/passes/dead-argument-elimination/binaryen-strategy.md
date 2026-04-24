---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md
  - ../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dae-optimizing/index.md
---

# Binaryen `dead-argument-elimination` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The immutable source manifest for this dossier is [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md).
- The official `version_129` GitHub release page was re-checked on 2026-04-24 and showed publish date **2026-04-01 14:31**.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration file, helper headers, and dedicated lit roster did not surface a teaching-relevant contract drift beyond this page's claims.
- The core implementation is `src/passes/DeadArgumentElimination.cpp`.
- Public registration and the plain-vs-optimizing split come from `src/passes/pass.cpp`.
- The nested cleanup helper that only the optimizing variant uses lives in `src/passes/opt-utils.h`.
- The main helper contracts come from:
  - `src/passes/param-utils.h`
  - `src/ir/return-utils.h`
  - `src/ir/lubs.h`
  - `src/ir/type-updating.h`
- The reviewed behavior examples come from:
  - `test/lit/passes/dae_tnh.wast`
  - `test/lit/passes/dae-gc.wast`
  - `test/lit/passes/dae-gc-refine-params.wast`
  - `test/lit/passes/dae-gc-refine-return.wast`
  - plus the shared-core contrast files `dae-optimizing.wast` and `dae-refine-params-and-optimize.wast`

## Compact owner/test split

The real owner map is:

- `DeadArgumentElimination.cpp` for the shared plain + optimizing core,
- `pass.cpp` for public registration,
- `opt-utils.h` only for the optimizing variant's nested cleanup helper,
- and the distributed `dae_tnh` + `dae-gc*` lit family for the plain-pass proof surface.

That last point matters because Binaryen does **not** provide one neat dedicated plain `dae.wast` file.
The neighboring optimizing files are useful contrast evidence, while `dae2.wast` belongs to the separately registered experimental sibling rather than to plain DAE.

## The pass in one sentence

Binaryen `dead-argument-elimination` / `dae` is a **whole-module direct-call boundary rewrite pass** that iteratively tightens signatures, materializes constant actuals, removes dead parameters and dropped returns, and localizes hard operands when needed, but stops short of the extra nested cleanup rerun used by `dae-optimizing`.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Collect direct calls, dropped direct calls, tail-call facts, `ref.func` escapes, and used incoming params | Build exact boundary facts before mutation |
| Filter | Skip imports, unseen-call functions, and functions with no direct callers | Keep ABI-visible or uncontrolled boundaries out of scope |
| Refine params | Narrow used ref-typed params from direct-call operand LUBs | Make the boundary more precise before deletion |
| Refine results | Narrow result types from returned-value LUBs and refinalize later if needed | Preserve more specific type information |
| Constantize | Materialize all-equal actuals inside the callee | Convert a boundary input into an internal constant |
| Remove params | Delete dead params through `ParamUtils` and rewrite direct calls | Core dead-argument elimination |
| Remove returns | Delete result values when every known direct call drops them and tail-call rules allow it | Shrink the return side of the boundary |
| Localize and iterate | Hoist effectful operands into temporaries and try again next iteration | Recover removals that were blocked only by nested effects |

## The biggest naming fact

For current Starshine status, local descriptive names, and future-port implications, read [`./starshine-strategy.md`](./starshine-strategy.md).

`pass.cpp` registers:

- `dae`
- `dae-optimizing`
- `dae2`

For the first two, the implementation split is tiny but important:

- `createDAEPass()` returns `new DAE()`
- `createDAEOptimizingPass()` returns `new DAE()` with `optimize = true`

So the plain pass is **not** a different algorithm.
It is the same engine without the final nested call to `OptUtils::optimizeAfterInlining(...)`.

That means a future Starshine port should keep one shared core model and one explicit scheduling difference.

## Phase 1: the data model shows the real scope

`DAEFunctionInfo` stores:

- `stale`
- `unusedParams`
- `calls`
- `droppedCalls`
- `hasTailCalls`
- `tailCallees`
- `hasUnseenCalls`

Those fields imply four important facts.

### 1. This is not a local peephole pass

The pass groups information by callee and caller across the whole module.

### 2. Return-value removal is part of the pass contract

`droppedCalls` exists specifically so Binaryen can later remove a function result when every direct call drops it.

### 3. Tail calls are a built-in safety boundary

`hasTailCalls` and `tailCallees` are tracked from the start because dropped-return elimination cannot ignore tail-call type constraints.

### 4. Escape analysis is deliberately conservative

`hasUnseenCalls` records functions whose boundary Binaryen does not fully control.
That includes `ref.func` escapes and exports.

## Phase 2: `DAEScanner` gathers direct-call facts

`DAEScanner` is function-parallel and non-mutating.

### `visitCall`

- groups direct calls by callee name;
- records direct tail calls through `curr->isReturn`.

### `visitCallIndirect` and `visitCallRef`

- do not give the pass a boundary it can rewrite directly;
- but still mark tail-call-related conservatism when they are return-form calls.

### `visitDrop`

- records exact `drop(call ...)` locations;
- those locations later let `removeReturnValue(...)` patch callers in place.

### `visitRefFunc`

- marks the referenced function as having unseen calls;
- this deliberately blocks signature-changing rewrites, because the function reference could escape and be observed externally.

### `doWalkFunction`

- recomputes per-function facts only when the function is marked stale;
- uses `ParamUtils::getUsedParams(...)` to distinguish truly-used incoming params from locals that merely reuse a parameter index after a write.

That last detail is easy to miss: Binaryen is not just looking for any `local.get` of a parameter slot. It wants to know whether the **incoming boundary value** is ever read.

## Phase 3: merge and closed-boundary filtering

After the scan, the pass merges the per-function facts into module-wide vectors and maps.

Important merged structures include:

- `allCalls`
- `tailCallees`
- `hasUnseenCalls`
- `allDroppedCalls`
- `callers`

Then it applies the main legality filter.

A function is skipped for signature-changing work when:

- it is imported;
- it has unseen calls;
- or it has no direct callers worth rewriting.

In beginner language:

> DAE only changes boundaries that Binaryen can still see and rewrite as a direct-call set.

## Phase 4: parameter refinement comes before deletion

`refineArgumentTypes(...)` runs first.

It is:

- GC-gated,
- limited to reference-typed params,
- based on direct-call operand evidence,
- and intentionally skipped for params already marked unused.

For each still-used ref param, Binaryen:

1. gathers all direct call operand types for that param position,
2. computes a least upper bound with `LUBFinder`,
3. checks whether the new type is stricter than the current param type,
4. applies the new param types with `TypeUpdating::updateParamTypes(...)`,
5. updates the function signature.

### Why unused params are skipped here

The source comment makes the reason explicit:

- unused params are handled better by later constantization/removal logic;
- refining them early would complicate the later local/defaultability story.

So Binaryen uses a deliberate phase ordering, not maximum eagerness.

## Phase 5: result refinement also belongs to DAE

`refineReturnTypes(...)` uses `LUB::getResultsLUB(...)` to infer a stricter function result type from actual returned values.

If it succeeds, Binaryen:

- updates the function result type,
- updates direct call expression types,
- and later runs `ReFinalize()` because parent expression types may need repair.

This is an important teaching point:

- plain DAE is not only about deleting boundary traffic;
- it can also tighten both sides of the boundary while keeping the same basic call graph.

## Phase 6: constant actual materialization is first-class behavior

`ParamUtils::applyConstantValues(...)` searches for params that receive the same constant in all direct calls.

If it finds one, Binaryen can:

- insert a `local.set` of that constant inside the callee,
- mark the corresponding param unused,
- and let later removal delete the actual boundary input.

The reviewed tests show this is not limited to numeric literals. GC and string-related constant families appear too.

So the real meaning is closer to:

- “turn boundary inputs into internal facts when they are globally constant across the known direct-call surface.”

## Phase 7: dead-parameter removal uses helper-driven boundary rewriting

When enough params are known unused, DAE calls `ParamUtils::removeParameters(...)`.

That helper owns the hard rewrite work:

- changing signatures,
- rewriting direct calls,
- replacing removed incoming params with locals or other valid body forms,
- and reporting whether the only blocker was nested effects that could be localized away.

### The recoverable-failure path matters

If removal fails only because the call operands have nested effects, the pass does **not** treat that as a hard no-op.
Instead it records the callee in `callTargetsToLocalize`.

That means DAE has a built-in “prepare, then retry later” phase.

## Phase 8: localization and iteration are part of the real algorithm

At the end of the iteration, if any targets were marked for localization, DAE calls:

- `ParamUtils::localizeCallsTo(...)`

That hoists effectful operands into temporaries so a later iteration can safely remove the now-simple dead argument.

This is why the pass runs to convergence.

A future port that only performs one boundary scan and one delete attempt would under-implement real Binaryen behavior.

## Phase 9: unprofitable single-caller chains are throttled

The pass keeps `unprofitableRemovalIters`.

If one iteration removes parameters from only one function and that function has only one caller, Binaryen counts that as an unprofitable removal round and stops doing more of those within the same invocation.

The source comment explains the heuristic:

- long single-caller chains often pay off more efficiently through inlining than through repeated whole-module DAE rounds.

So DAE intentionally does not chase every possible final improvement in one run.

## Phase 10: dropped-return removal is stricter than dead-param removal

Dropped-return elimination happens only when `worthOptimizing` is still empty for the current iteration.

That is a practical mutation-discipline rule: Binaryen avoids rewriting both params and results for the same callsite in one iteration.

The pass also requires:

- the function result is not already `none`;
- no unseen calls;
- the function itself has no tail calls;
- the function is not a tail callee;
- all direct calls are known;
- and every direct call result is dropped.

If all of that holds, `removeReturnValue(...)`:

1. changes the function result to `none`;
2. rewrites `drop(call ...)` to either plain `call` or `call; unreachable`;
3. updates call expression types where needed;
4. uses `ReturnUtils::removeReturns(...)` to rewrite the callee body.

### Why `call; unreachable` sometimes appears

If the old result type was uninhabitable, the caller learned something useful: the call could never really return normally.

Binaryen preserves that fact by turning the caller site into:

- `call`
- then `unreachable`

instead of silently dropping the information.

That is a subtle but very important correctness and optimization-preservation rule.

## Phase 11: plain DAE deliberately omits the optimizing rerun

At the end of a productive iteration:

- plain `dae` stops after its own boundary and localization work;
- `dae-optimizing` additionally runs `OptUtils::optimizeAfterInlining(...)` on the touched functions.

That helper prepends `precompute-propagate` and then runs the default function optimization pipeline.

So if plain DAE leaves behind:

- fresh constant locals,
- dead cleanup debris,
- extra drops,
- or simplifiable structured wrappers,

that is still faithful Binaryen behavior.

## What is easy to misunderstand

## Misunderstanding 1: “It only removes unused parameters”

False.
The implementation also:

- refines parameter types,
- refines result types,
- materializes constants,
- removes dropped returns,
- and localizes operands.

## Misunderstanding 2: “It is a closed-world optimizer”

Only in a narrower sense.
It needs a closed-enough **direct-call boundary surface**, but it is not the same kind of whole-program closed-world GC pass as `type-refining`, `signature-pruning`, or `remove-unused-types`.

## Misunderstanding 3: “If a function is referenced but not called indirectly, DAE can still rewrite it”

No.
`ref.func` is treated conservatively as an unseen-call escape.

## Misunderstanding 4: “The plain and optimizing variants need separate core implementations”

No.
The source deliberately shares one implementation and flips one flag.

## Misunderstanding 5: “Tail calls only matter for return_call syntax”

Not quite.
The pass tracks tail callers and tail callees because result removal has to preserve the tail-call type contract across those boundaries.

## What a future Starshine port must preserve

- The module-wide direct-call grouping model.
- The unseen-call filter for exports and `ref.func` escapes.
- The iterative localization-and-retry flow.
- The GC-only reference-param narrowing phase.
- The result-refinement plus later `ReFinalize` obligation.
- The stricter dropped-return + tail-call legality checks.
- The `call; unreachable` repair when uninhabitable results disappear.
- The explicit split between plain DAE and `dae-optimizing` at the scheduler/follow-up-cleanup level.

## Bottom line

Binaryen `dead-argument-elimination` is best taught as:

- a direct-call boundary optimizer,
- with iterative legality repair,
- plus type-tightening and dropped-return logic,
- but **without** the cleanup replay that makes `dae-optimizing` look stronger in end-to-end optimize pipelines.
