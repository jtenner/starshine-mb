# 0159 - `dead-argument-elimination` Binaryen research

- Date: 2026-04-21
- Scope: add one more eligible upstream-only Binaryen pass dossier after the main no-DWARF / saved `-O4z` queue and the first upstream-only expansion queue were already dossier-covered.
- Chosen pass: `dead-argument-elimination`.
- Upstream public CLI alias: `dae`.
- Local Starshine registry name: `dead-argument-elimination` in `src/passes/optimize.mbt`.
- Current registry status: boundary-only.
- `agent-todo.md` status: there is **no dedicated `dead-argument-elimination` slice** in the current backlog.

## Why this pass is still an eligible target

The campaign prompt says the original parity queue and the first widened upstream-only queue are already covered, so this thread must either justify a major-gap fallback or expand the tracker with another genuinely eligible upstream-only pass.

`dead-argument-elimination` is a good expansion target because:

1. it is already a named local boundary-only registry pass in `src/passes/optimize.mbt`;
2. it is an official upstream Binaryen pass in `version_129` (`dae` in `pass.cpp`);
3. the existing `dae-optimizing` dossier repeatedly points at the plain pass as the same core engine with one scheduler-changing flag difference;
4. documenting the plain variant reduces future confusion about what the optimizing suffix really adds;
5. the implementation and lit coverage are rich enough to support a real dossier rather than a stub.

So this is not a speculative random expansion. It is a source-backed second-wave registry pass that already sits next to an existing dossier and shares its implementation file.

## Sources reviewed

### Core implementation and registration

- `src/passes/DeadArgumentElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/passes/param-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
- `src/ir/return-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- `src/ir/lubs.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>

### Reviewed lit files and closely related tests

- `test/lit/passes/dae_tnh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
- `test/lit/passes/dae-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
- `test/lit/passes/dae-gc-refine-params.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
- `test/lit/passes/dae-gc-refine-return.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
- `test/lit/passes/dae-optimizing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
- `test/lit/passes/dae-refine-params-and-optimize.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>

I also fetched `test/lit/passes/dae2.wast` while scanning the neighborhood, but that file belongs to the experimental `dae2` reimplementation registered separately in `pass.cpp`, so I treat it only as nearby context, **not** as the main oracle for plain `dae`.

## Highest-level conclusion

Binaryen `dead-argument-elimination` is a **whole-module direct-call boundary rewrite pass**.

Its real contract is:

- collect exact direct-call facts,
- refuse functions with unseen or escaping callers,
- refine parameter and result types when direct-call evidence allows,
- materialize all-equal constant actuals into the callee,
- remove unused parameters through shared `ParamUtils` helpers,
- remove dropped return values when tail-call constraints allow,
- localize hard call operands and iterate until no more progress remains.

The plain pass is **not** just “`dae-optimizing` without the cleanup niceties” in a vague sense. It is literally the same `DAE` class with `optimize = false`, which means the **entire core call-boundary algorithm is shared**, while the nested `optimizeAfterInlining(...)` rerun is the main behavioral split.

That distinction deserves its own dossier because otherwise a future port can easily make one of two mistakes:

- under-implement plain DAE as “delete obvious unused params only”; or
- over-attribute optimizing cleanup behavior to the plain pass.

## Registration and naming facts

`pass.cpp` registers:

- `dae`
- `dae-optimizing`
- `dae2`

In `DeadArgumentElimination.cpp`, the implementations are:

- `createDAEPass() { return new DAE(); }`
- `createDAEOptimizingPass() { auto* ret = new DAE(); ret->optimize = true; return ret; }`

So the plain and optimizing variants are the same engine plus one boolean flag.

Important naming note for the Starshine wiki:

- upstream public name: `dae`
- local registry name: `dead-argument-elimination`

The new dossier should keep both names explicit so future readers can connect the repo tracker to upstream docs and command lines.

## Scheduler placement conclusion

Plain `dae` is **not** part of the current documented no-DWARF default `-O` / `-Os` path in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`.

The current default late post-pass cluster uses `dae-optimizing`, not plain `dae`.

That means this dossier is an upstream-only registry expansion, not a parity-queue pass.

Still, it matters because:

- Starshine already names it in the registry,
- the `dae-optimizing` dossier depends on understanding it,
- and a future implementation may want the plain variant as a separate public/debug/testing entry point even if default presets use the optimizing form.

## What the implementation actually stores

`DeadArgumentElimination.cpp` defines `DAEFunctionInfo` with these key fields:

- `stale`
- `unusedParams`
- `calls`
- `droppedCalls`
- `hasTailCalls`
- `tailCallees`
- `hasUnseenCalls`

That struct already shows the pass is wider than a local dead-param scan:

- `calls` means it rewrites the callee and all known direct callers together;
- `droppedCalls` means return-value removal is a first-class goal;
- `hasTailCalls` and `tailCallees` mean tail-call legality is built into the algorithm;
- `hasUnseenCalls` means export / `ref.func` / unknown-call-surface conservatism is central.

The pass also keeps module-wide working state such as:

- a dense function-name-to-index map,
- a reverse caller graph,
- a merged direct-call list per callee,
- a merged dropped-call-location table,
- a work set of functions worth follow-up optimization,
- a set of call targets whose call operands need localization,
- and a small heuristic counter for “unprofitable” one-caller removal iterations.

## Main algorithmic phases

## 1. Scan current module facts

`DAEScanner` is function-parallel and non-mutating.

It records:

- direct `Call*` users of each non-imported callee,
- `drop(call ...)` locations,
- tail-call facts from `call`, `call_indirect`, and `call_ref`,
- `ref.func` escape facts,
- and truly-used incoming params via `ParamUtils::getUsedParams(...)`.

Important detail:

- `visitRefFunc(...)` treats a referenced function as having unseen calls.
- later, exports are also treated as unseen calls.

So the pass is conservative about any function boundary that might be observed or invoked through a route it cannot rewrite coherently.

## 2. Merge scan results and compute stable caller info

After scanning, the pass merges per-function facts into module-wide vectors:

- `allCalls`
- `tailCallees`
- `hasUnseenCalls`
- `allDroppedCalls`

It also builds a reverse caller map once and then reuses that over-approximation across later iterations.

That over-approximation is deliberate. The comments explicitly say a few stale extra callers are acceptable because they only cause extra rescans, not missed optimizations.

## 3. Skip boundaries it does not fully own

For each function, plain DAE immediately skips when:

- the function is imported,
- the function has unseen calls,
- the function has no direct callers,
- or the function has no parameters / no useful surface for the current phase.

This is the pass’s biggest conceptual safety rule:

> DAE rewrites only direct-call boundaries that Binaryen still controls as a closed enough surface.

## 4. Refine argument types first

`refineArgumentTypes(...)` runs before constant materialization or removal.

It is:

- GC-gated,
- limited to reference-typed params,
- and intentionally skipped for already-unused params.

For each still-used ref param, it computes a least upper bound from all direct call operands using `LUBFinder`, then applies a stricter param type with `TypeUpdating::updateParamTypes(...)` when possible.

Important nuance:

- despite the common intuition, “dead-argument elimination” can make signatures **more specific** even when a parameter remains live.
- unused params are intentionally left alone in this phase because later constantization/removal paths already know how to handle them and early refinement would complicate local/defaultability repair.

## 5. Refine return types too

`refineReturnTypes(...)` calls `LUB::getResultsLUB(...)` and can narrow the function result type when actual returned values prove a stricter type.

If it changes a result type, the pass:

- updates the function signature,
- updates direct call expression types,
- and later runs `ReFinalize` because those type changes can propagate outward through parents.

This is another easy-to-miss fact: plain DAE is also a result-type-tightening pass.

## 6. Materialize all-equal constant actuals inside the callee

`ParamUtils::applyConstantValues(...)` looks for parameters whose incoming values are the same constant at all direct callsites.

When that happens, DAE:

- inserts a `local.set` of the constant inside the callee,
- marks the old parameter as unused,
- and prepares the function for later parameter removal.

This applies to more than integer literals. The reviewed lit files show GC and string-related constant families too.

A beginner-friendly correction here is:

- the pass is not only deleting dead params;
- it can convert a still-read incoming slot into an internal constant local first.

## 7. Remove parameters through shared helpers

After collecting unused params, the pass calls `ParamUtils::removeParameters(...)`.

That helper rewrites:

- the function signature,
- the body,
- the direct callsites,
- and any related local/defaultability structure needed to keep the function valid.

If removal fails only because nested call operands have effects, the helper reports a recoverable failure mode. Plain DAE then records the callee in `callTargetsToLocalize` instead of giving up entirely.

## 8. Localize hard call operands and iterate

At the end of an iteration, if `callTargetsToLocalize` is non-empty, DAE uses `ParamUtils::localizeCallsTo(...)`.

That hoists problematic call operands into temporaries so later iterations can remove the now-effect-free dead parameter.

This is important for teaching the real algorithm:

- the pass is iterative on purpose,
- and one iteration may exist only to make a later one legal.

## 9. Remove dropped return values only under tighter rules

Return-value removal is delayed until no earlier boundary changes were recorded in `worthOptimizing`.

For a function result to disappear, Binaryen requires all of the following:

- the function result is not already `none`,
- there are no unseen calls,
- the function itself has no tail calls,
- the function is not a tail callee of some other function,
- all direct calls are seen,
- and every direct call result is immediately dropped.

Then `removeReturnValue(...)`:

- sets the function result to `none`,
- rewrites each `drop(call ...)` site to either `call` or `call; unreachable`,
- and uses `ReturnUtils::removeReturns(...)` to rewrite the callee body.

The `call; unreachable` case matters when the old return type was uninhabitable. Binaryen preserves the useful “this never returns” fact rather than silently turning that into an ordinary none-typed call.

## 10. Plain DAE stops here; optimizing DAE does not

At the very end of each iteration:

- plain `dae` returns once it has done its own boundary/localization work;
- `dae-optimizing` additionally calls `OptUtils::optimizeAfterInlining(...)` on the touched functions.

That nested rerun prepends `precompute-propagate` and then runs the default function optimization pipeline.

So the plain pass’s output may intentionally still contain:

- newly inserted constant locals,
- newly dead code around dropped returns,
- or intermediate cleanup debris.

That is expected behavior, not evidence that the pass is incomplete.

## Important positive rewrite families

The reviewed implementation and tests show these important positive families:

1. plain unused direct-call parameter deletion;
2. recursive and mutually recursive dead-param elimination when the cycle truly never needs the incoming value;
3. all-callers-pass-the-same-constant materialization into the callee;
4. GC reference parameter narrowing from caller operand LUBs;
5. return type narrowing from actual returned-value LUBs;
6. dropped-return elimination;
7. `call(unreachable)` / `return_call(unreachable)` repair to preserve unreachable typing;
8. TNH-enabled elimination where the only thing keeping a dead param alive was a trap-like argument expression that TNH allows Binaryen to ignore.

## Important bailout and preserved families

The pass also keeps several families deliberately unchanged:

1. imported functions;
2. exported functions;
3. `ref.func`-escaped functions;
4. indirect-call and escaping `call_ref` boundaries where the signature cannot be changed safely;
5. tail-callers and tail-callees for dropped-return removal;
6. functions with no direct callers, because DAE treats them as not worth optimizing here;
7. non-GC parameter narrowing when the type is not a reference;
8. unused params during the type-refinement phase, because later removal handles them better.

## The unprofitable-removal heuristic is real

One subtle implementation detail is `unprofitableRemovalIters`.

If a whole iteration removes parameters from only one function and that callee has only one caller, Binaryen increments a counter and stops doing more of those low-payoff removal rounds inside the same invocation.

The source comment explains why:

- in long single-caller chains, inlining can often expose the same payoff more efficiently than repeated full-module DAE iterations.

So the pass intentionally gives up on some theoretically possible extra progress inside one run.

That is a good example of “real Binaryen behavior” versus “what the pass name suggests in theory.”

## What a future Starshine port must preserve

A future port should preserve at least these contracts:

1. **Module/boundary scope**: this is not a HOT function-local peephole.
2. **Closed direct-call ownership**: exports and `ref.func` escapes must block signature-changing rewrites.
3. **Shared engine with `dae-optimizing`**: do not fork the core algorithm semantically just because the optimizing suffix changes scheduler behavior.
4. **Iterative localization story**: recoverable removal failures should trigger operand localization and another iteration, not silent bailout.
5. **GC ref narrowing and result narrowing**: the pass is also a type-tightening pass.
6. **Return-removal tail-call conservatism**: tail-call structure is part of legality, not optional caution.
7. **Unreachable preservation**: if a removed dropped return carried useful uninhabitable information, caller repair must preserve that with `unreachable`.
8. **Alias handling**: local docs and CLI surfaces should connect `dead-argument-elimination` with upstream `dae` cleanly.

## Beginner-facing summary

If you remember only one thing, remember this:

> Plain `dae` is a direct-call boundary simplifier that iteratively rewrites signatures, constants, and dropped returns, but it intentionally stops before the nested cleanup rerun that makes `dae-optimizing` look much more polished.

That is the clearest mental split between the two public pass names.

## Open questions and uncertainty

- I did not rely on `dae2.wast` for the core dossier because it belongs to the separately registered experimental `dae2` pass, not plain `dae`.
- I reviewed `dae-optimizing` lit files as supporting evidence because they exercise the same core implementation file, but any shape that depends specifically on the optimizing rerun should be labeled as `dae-optimizing`-only rather than silently attributed to plain `dae`.
- I did not see plain `dae` listed in the repo’s current no-DWARF default optimize path, so this dossier should remain clearly marked as an upstream-only registry expansion rather than parity-queue work.

## Durable takeaways to file back into the wiki

- `dead-argument-elimination` / `dae` deserves its own dossier because it is a separately registered upstream pass and a separately tracked local boundary-only name, even though it shares code with `dae-optimizing`.
- The plain pass’s real work is broader than dead-param deletion: it also does constant actual promotion, GC param refinement, result refinement, operand localization, and dropped-return removal.
- The biggest semantic difference from `dae-optimizing` is not the boundary rewrite itself but the absence of `optimizeAfterInlining(...)` after each productive iteration.
- Tail calls, exports, `ref.func`, and unseen boundaries are first-class legality constraints, not minor caveats.
