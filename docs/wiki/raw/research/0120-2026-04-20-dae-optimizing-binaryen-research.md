# 0120 - `dae-optimizing` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `dae-optimizing` really works, which helpers it leans on, and which IR shapes a future Starshine port must preserve.

## Why this pass

- `dae-optimizing` is still unimplemented in Starshine and remains tracked as a boundary-only pass in `src/passes/optimize.mbt`.
- The canonical no-DWARF `-O` / `-Os` path runs it as the **first** late global optimizing pass, before:
  - `inlining-optimizing`
  - `duplicate-function-elimination`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
- The saved generated-artifact `-O4z` audit records a skipped top-level slot:
  - slot `48`: `dae-optimizing`
- The pass name is easy to underread. Binaryen is not just deleting obviously unused parameters. The real implementation can also:
  - refine GC reference parameter types from actual call operands
  - refine function result types from returned values
  - materialize constant actual arguments into callee locals and then remove those parameters
  - localize hard-to-remove call operands so parameter removal becomes legal on a later iteration
  - remove function return values when every direct call drops them
  - rerun a targeted cleanup pipeline on the changed functions when the `optimizing` variant is used
- That combination makes this pass especially important for Starshine’s boundary-only tracker: it is both a signature-changing module pass and a scheduler pass that triggers nested function cleanup work.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`

### Official Binaryen `version_129` sources

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
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/dae-optimizing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
- `test/lit/passes/dae-refine-params-and-optimize.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
- `test/lit/passes/dae-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
- `test/lit/passes/dae-gc-refine-params.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
- `test/lit/passes/dae-gc-refine-return.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
- `test/lit/passes/dae_tnh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>

## Fast answer

Binaryen’s `dae-optimizing` pass is the plain dead-argument-elimination engine **plus** a post-change helper that reruns a targeted function-optimization pipeline on the changed functions.

The actual dead-argument-elimination engine is a module-level signature-rewrite pass that:

1. scans each function to collect direct-call facts, dropped-call facts, tail-call facts, escaped-function facts, and which incoming parameters are really used
2. decides which functions are eligible for closed-world signature changes
3. optionally refines reference-typed parameters and function results using least-upper-bound reasoning
4. pushes constant actual arguments into the callee body and marks those params removable
5. removes dead parameters from both callee signatures and direct callsites, sometimes after first localizing difficult operands
6. removes function return values when every direct call drops them
7. if the `optimizing` variant is active, reruns a follow-up cleanup pipeline on the touched functions

A good beginner summary is:

- Binaryen starts from call graph facts,
- changes only functions whose call boundary still looks closed and direct,
- rewrites both sides of that boundary together,
- and then immediately cleans up the new local / cast / control-flow debris.

That is much richer than “delete unused args.”

## CLI names and scheduler placement

## Pass registration surface

`pass.cpp` registers **two** closely related pass names:

- `dead-argument-elimination`
- `dae-optimizing`

The second one is created by `createDAEOptimizingPass()` and simply turns on the extra optimizing cleanup phase after the core DAE work.

That distinction matters for Starshine docs:

- the top-level no-DWARF optimize path uses `dae-optimizing`
- but the implementation file is still named `DeadArgumentElimination.cpp`
- and the optimizing variant is not a separate algorithm from scratch

## Top-level no-DWARF placement

In the canonical no-DWARF post-pass phase, `dae-optimizing` runs first in the late global-optimization cluster:

- `dae-optimizing`
- `inlining-optimizing`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

That makes DAE the first place where Binaryen starts mutating function boundaries after the late function-local cleanup cluster has already settled.

## Saved generated-artifact `-O4z` evidence

The committed skipped-slot audit matches that source-level picture:

- slot `48`: `dae-optimizing`

The saved full debug log also shows that the pass is not a “one call and done” stage. Inside the log interval between top-level `dae-optimizing` and the next top-level `inlining-optimizing`, repo-local counting over `.artifacts/o4z-wasm-opt-debug.log` finds:

- `12` nested `ssa-nomerge` executions
- `24` nested `local-cse` executions
- `12` nested `code-folding` executions
- `36` nested `precompute-propagate` executions

That last number is especially informative: the optimizing helper prepends one extra `precompute-propagate` before replaying the ordinary default function pipeline, so each nested rerun contributes **three** visible `precompute-propagate` executions in the saved `-O4z` lane.

## The optimizing helper is part of the real contract

`opt-utils.h` shows that `optimizeAfterInlining(...)`:

1. builds a filtered pass runner over the changed functions
2. prepends `precompute-propagate`
3. calls `addDefaultFunctionOptimizationPasses(...)`
4. runs only on the touched function set

So `dae-optimizing` is really:

- DAE boundary rewrites
- plus targeted nested cleanup

A future port that only removes parameters without replaying that helper will not match Binaryen’s real pipeline behavior.

## Actual implementation structure

## 1. Pass shape and top-level helper surface

`DeadArgumentElimination` is a module pass, not a function-local HOT pass.

That is obvious once you look at what it must mutate:

- callee signatures
- direct callsites in other functions
- return types at both ends of the call edge
- escape and export visibility
- nested rerun scheduling over a touched-function subset

The main helper files explain the real scope:

- `param-utils.h`
  - parameter-use discovery, constant actual materialization, parameter removal, call localization
- `lubs.h`
  - least-upper-bound logic for refining ref-typed params and results
- `type-updating.h`
  - body repair when refined parameter types would otherwise make local traffic invalid
- `return-utils.h`
  - body rewrite when removing function result values
- `utils.h`
  - `ReFinalize`, needed after return-type changes
- `opt-utils.h`
  - the nested optimizing rerun helper

## 2. The main per-function fact record: `DAEFunctionInfo`

The implementation’s central record is `DAEFunctionInfo`, which stores:

- `stale`
  - whether a function needs rescanning this iteration
- `unusedParams`
  - the currently removable incoming param indexes
- `calls`
  - direct callsites grouped by callee name
- `droppedCalls`
  - exact `drop(call)` sites for possible result removal
- `hasTailCalls`
  - whether the function itself performs tail calls
- `tailCallees`
  - which functions are called via tail call from this function
- `hasUnseenCalls`
  - which functions escape or are otherwise not safely known only through rewritable direct calls

That record already shows the pass’s real shape:

- call graph facts
- use facts
- tail-call facts
- escape facts
- exact caller-site rewrite facts

## 3. Phase one: parallel scan with `DAEScanner`

`DAEScanner` is a parallel post-walker that populates `DAEFunctionInfo` for each function.

It records:

### Direct calls

`visitCall(...)` adds direct callsites to the per-callee map.

That is the main data DAE can rewrite later.

### Tail calls

If a direct call is a `return_call`, the scanner records the callee in `tailCallees`.

`visitCallIndirect(...)` and `visitCallRef(...)` do not participate in the same signature-rewrite machinery, but they still matter for tail-call conservatism.

### Dropped direct calls

`visitDrop(...)` notices `drop(call $f ...)` shapes and records the exact pointer-to-child location.

That lets the pass later rewrite:

- `drop(call ...)`
- into just `call ...`
- or into `call ...; unreachable` when the old result type was uninhabitable

### Escaped or externally visible functions

`visitRefFunc(...)` marks a referenced function as having an unseen call.

Later, exports are also treated as unseen calls.

This is one of the most important safety rules: if a function boundary escapes through `ref.func` or export visibility, Binaryen refuses signature-changing DAE rewrites there.

### Actually-used incoming parameters

During `doWalkFunction(...)`, if a function is marked stale, the scanner recomputes its used incoming parameters with `ParamUtils::getUsedParams(...)`.

That produces the current candidate set of unused params.

## 4. Phase two: merge facts and decide who is eligible

Inside each DAE iteration, the pass merges the scanned facts into module-wide working sets:

- dense function-name-to-index mapping
- reverse caller graph
- merged direct call maps
- merged tail-callee facts
- merged unseen-call facts
- merged dropped-call locations

The eligibility filter is conservative.

A function is skipped if:

- it is imported
- it has unseen calls
- it has no direct callers

The “no direct callers” rule is easy to miss. Binaryen explicitly treats those cases as not worth optimizing here and expects other passes like DCE / RUME to make dead code disappear instead of having DAE speculate on it.

## 5. Phase three: type refinement is real DAE work

This is the main thing beginners usually miss.

Binaryen DAE does not only remove unused params. It can also make function boundaries **more precise**.

### Parameter type refinement: `refineArgumentTypes(...)`

This phase is GC-gated and only touches reference-typed params.

For each eligible, still-used ref-typed param, DAE:

1. gathers the actual operand types from all direct callers
2. uses `LUBFinder` from `lubs.h` to find the least upper bound across those actual types
3. compares the refined type against the current param type
4. if it is more specific, applies the change with `TypeUpdating::updateParamTypes(...)`

The important beginner-friendly lesson is:

- DAE is allowed to narrow a parameter type when all direct callers already provide a narrower value family

The important implementation lesson is:

- changing the signature is not enough
- the function body may contain `local.get`, `local.set`, or `local.tee` traffic that now needs repair
- that is why `type-updating.h` is a real dependency

### Why unused params are deliberately not refined first

The source comments say Binaryen skips refining params that are already known unused.

Reason:

- those params may become locals later when constants are materialized or params are removed
- changing their type first can create defaultability and local-conversion complications

That is a subtle “do not over-eagerly clean everything at once” design choice.

### Return type refinement: `refineReturnTypes(...)`

DAE can also narrow a function’s result type using `LUB::getResultsLUB(...)` over the actual returned values.

If the result type changes, Binaryen:

- updates the function signature
- updates direct call expression types
- later runs `ReFinalize` over the module so surrounding expressions see the new type

This matters for GC-heavy pipelines because more precise return types can unlock later cast and subtype cleanups.

### Limitation: not a perfect recursive fixed-point solver

The source comments are explicit that return refinement can miss more global optima in recursive or mutually recursive situations.

So the pass is useful and real, but not an exhaustive whole-program type solver.

## 6. Phase four: constant actual values can turn into removable params

`ParamUtils::applyConstantValues(...)` is a second major transformation.

If every direct call to a function passes the same constant value in some parameter slot, DAE can:

- materialize that constant into the callee body, usually as a local initialization
- mark the original incoming parameter unused
- then let later parameter-removal logic erase it from the signature

This is another example of how the pass name undersells the implementation.

It is doing a small form of interprocedural constant propagation at the call boundary.

The GC tests make this especially visible because the constant actual can be:

- `ref.null`
- `ref.i31`
- `ref.func`
- `string.const`

not just small integers.

## 7. Phase five: parameter removal, sometimes after call localization

Once unused params are known, DAE tries to remove them with `ParamUtils::removeParameters(...)`.

That helper must change both sides of the boundary together:

- the callee signature
- every direct callsite that still targets it

### Why removal can fail temporarily

Not every removable parameter can be deleted immediately.

If a call operand is nested or effectful enough that deleting it in place would be unsafe or would disturb evaluation order, `removeParameters(...)` can report failure.

When that happens, DAE records the callee name in `callTargetsToLocalize`.

Then a later step uses `ParamUtils::localizeCallsTo(...)` to rewrite those callsites into a safer shape by hoisting difficult operands into locals first.

So the real algorithm is often:

1. discover removable params
2. fail to remove some because operands are awkward
3. localize those operands
4. iterate again
5. remove the params successfully

That is a major reason this pass belongs in a boundary-only / module-level bucket in Starshine.

## 8. Phase six: dropped return removal is a separate family

The pass also handles a completely different but related optimization:

- if a function returns a value,
- and every observed direct call is wrapped in `drop`,
- then the function result itself may be unnecessary

Binaryen can then:

- change the function result type to `none`
- rewrite every `drop(call ...)` into just `call ...`
- rewrite the function body with `ReturnUtils::removeReturns(...)`

### Uninhabitable result types need `call; unreachable`

One of the nicest correctness details in the file is the special case for old uninhabitable result types.

If the original call expression type told the caller “execution cannot continue normally here,” then just changing `drop(call)` into `call` would lose that fact.

Binaryen repairs this by emitting:

- `call ...`
- followed by `unreachable`

The `dae_tnh.wast` and `dae-optimizing.wast` tests make this behavior explicit.

## 9. Tail-call conservatism is deliberate

Dropped-return removal is more conservative than plain return-type refinement.

The pass avoids removing return values when tail-call relationships could make that unsound or more complicated.

The data structures that enforce that include:

- `hasTailCalls`
- `tailCallees`

So “the result is always dropped” is **not** by itself enough. Tail-call structure can still block the rewrite.

## 10. The `optimizing` variant: nested reruns on touched functions

The difference between plain `dead-argument-elimination` and `dae-optimizing` is short in code but huge in scheduler meaning.

When the optimizing flag is on and DAE made useful changes, Binaryen calls:

- `OptUtils::optimizeAfterInlining(worthOptimizing, getPassOptions(), getModule(), 0)`

The helper then prepends:

- `precompute-propagate`

and reruns the default function optimization pipeline on just the touched functions.

That cleanup can erase or shrink the debris DAE introduced, such as:

- newly materialized locals
- redundant casts after type refinement
- new dead code after result removal
- simplify-locals opportunities after localized call operands

That is why the pass is called `dae-optimizing`, not just `dae`.

## 11. The “don’t chase long one-caller chains forever” heuristic

Another subtle piece of real policy is `unprofitableRemovalIters`.

The implementation detects a low-payoff pattern where:

- one iteration removes params from exactly one function
- that function has exactly one caller
- nothing else interesting is happening

In that case, it stops trying to remove more params in the same invocation.

The idea is practical:

- let a later inlining or later DAE run handle the next link of the chain more cheaply
- do not spend the current invocation crawling down a long single-caller ladder one boundary at a time

This is a good example of Binaryen preferring pipeline efficiency over maximal local greed.

## Important test-backed shape lessons

## `dae-optimizing.wast`: the pass is not just dead-arg deletion

This file shows several core families together:

- removing plain unused parameters from direct-call-only functions
- sinking constant actuals into the callee and then deleting the old incoming parameter
- deleting dropped return values
- preserving `unreachable` when the old dropped result had uninhabitable type semantics
- extra cleanup after the optimizing helper reruns nested passes

The test is the best single beginner proof that `dae-optimizing` changes **signatures, callers, and bodies**.

## `dae-refine-params-and-optimize.wast`: type refinement can unlock later cleanup

This fixture exists to show that parameter type refinement is not an isolated bookkeeping change.

The refined boundary can let the optimizing cleanup replay remove now-obviously-redundant cast or test work afterward.

That is exactly the kind of cross-pass interaction a future Starshine port must preserve.

## `dae-gc-refine-params.wast`: ref-typed parameter LUB refinement is real

This file exercises the GC-specific half of the algorithm:

- refining a broad incoming param type to the least upper bound of actual direct-call operand types
- handling nullability correctly
- keeping body-local traffic valid when the narrowed param is later written or teed

This is where `lubs.h` plus `type-updating.h` matter most.

## `dae-gc-refine-return.wast`: return LUB refinement propagates outward

This file shows that result-type refinement is not purely internal.

After Binaryen refines a function result type, it must also propagate the new type to direct call expressions and then refinalize surrounding code so enclosing expressions keep valid types.

## `dae-gc.wast`: constant actuals include GC and string values

This file is a strong reminder that the constant-argument path is not only about integer immediates.

Binaryen’s `version_129` DAE handles constant actual families like:

- `ref.null`
- `ref.i31`
- `ref.func`
- `string.const`

That matters for modern GC/string-enabled Starshine parity.

## `dae_tnh.wast`: traps-never-happen and `unreachable`-typed operands are corner cases

This file covers the tricky typing side of argument removal when operands are trap-only or unreachable-shaped.

The core lesson is:

- removing an unused argument must still preserve the caller’s overall typing and control-flow facts

That is why Binaryen has special handling for uninhabitable old result types and tail-call cases instead of blindly deleting nodes.

## Source-backed but easy-to-miss limitations

The following points are all directly supported by the `version_129` source, but they are easy to miss if you only read the pass name.

### Closed-world only for signature changes

If a function is:

- exported
- referenced by `ref.func`
- otherwise not known only through the collected rewritable direct calls

then DAE marks it as having unseen calls and refuses signature-changing optimizations.

### Direct-call focused

The pass collects and rewrites direct `Call*` boundaries.

`call_ref` and `call_indirect` matter for conservatism, especially tail-call facts, but they do not participate in the same easy signature-rewrite pipeline.

### Imports are off-limits

Imported functions are skipped.

This is both an ABI rule and a practical boundary rule.

### Functions with no direct callers are skipped

DAE is not trying to improve dead or isolated functions speculatively here.

### Parameter type refinement is GC-only and ref-only

No GC feature means no ref-type boundary refinement in this phase.

### Dropped-return elimination is stricter than return-type refinement

A result type may still be refinable in some scenarios where complete result removal is blocked by tail-call relationships.

### Parameter removal can require an extra iteration

When deletion is unsafe in place, Binaryen localizes call operands first and tries again.

### The pass is not an interprocedural fixed-point theorem prover

It makes strong local improvements, but it does not promise the globally most refined recursive solution.

## What a future Starshine port must preserve

## Boundary model

- Treat this as a **module / boundary** pass, not a function-local HOT pass.
- Preserve the direct-calls-only rewrite model.
- Preserve the closed-world escape checks for exports and `ref.func`.

## Signature rewrite model

- Preserve plain unused-param removal.
- Preserve constant actual materialization into the callee.
- Preserve GC ref-type parameter LUB refinement.
- Preserve return-type refinement plus caller-side type propagation.
- Preserve dropped-return elimination only under the same conservative conditions.

## Safety / bailout model

- Keep imported functions out of scope.
- Keep call-ref / call-indirect conservatism.
- Keep tail-call conservatism.
- Preserve the `call; unreachable` repair for removed uninhabitable dropped results.
- Preserve the “functions with no direct callers are not worth optimizing here” rule.

## Iteration model

- Preserve the stale-function rescanning model.
- Preserve the call-localization retry path when in-place parameter removal fails.
- Preserve the low-payoff one-caller-chain stop heuristic.

## Scheduler model

- Preserve top-level placement before `inlining-optimizing` in the no-DWARF post-pass cluster.
- Preserve the optimizing helper’s extra prepended `precompute-propagate`.
- Preserve the nested rerun of the default function optimization pipeline on the touched functions only.

## Validation / typing model

- Preserve body repair with `TypeUpdating::updateParamTypes` when refining params.
- Preserve post-result-change refinalization.
- Preserve ABI-visible signature stability when unseen calls exist.

## Uncertainty and explicit inferences

1. The nested-pass **counts** in this note come from repo-local counting over `.artifacts/o4z-wasm-opt-debug.log`, not from Binaryen source comments themselves.
2. I did not separately audit current Binaryen `main` for drift in this thread. The pinned source oracle here is Binaryen `version_129`.
3. The repo’s living no-DWARF page also records that `simplify-globals-optimizing` reruns the default function pipeline on changed functions without prepending `precompute-propagate`. I did not rederive that specific `simplify-globals-optimizing` behavior from its implementation file during this DAE-focused thread.

## Bottom line

A beginner-to-intermediate friendly but accurate summary is:

- `dae-optimizing` is Binaryen’s call-boundary cleanup pass, not just a dead-parameter delete button
- it reasons about direct callers, escapes, tail calls, actual argument values, and result uses
- it can narrow signatures, materialize constants, delete parameters, delete returns, and then rerun cleanup on the changed functions
- the nested rerun behavior is part of the pass contract, not an optional polishing step
- and a future Starshine port must preserve both the boundary rewrite rules **and** the follow-up scheduler semantics to be honest parity work
