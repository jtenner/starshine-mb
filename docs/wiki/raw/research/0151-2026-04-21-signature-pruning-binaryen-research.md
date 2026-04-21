# 0151 - Binaryen `signature-pruning` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `type-refining` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `signature-pruning`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/signature-pruning/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

At that point:

- the main no-DWARF / saved-`-O4z` queue no longer had any pass with wiki status `none`
- the implemented-landing queue was already closed
- the prompt explicitly excluded the parity-queue dossiers that recent threads had just refreshed
- `remove-unused-types` and `type-refining` were already dossier-covered in the tracker's upstream-only expansion table
- `agent-todo.md` still had **no dedicated `signature-pruning` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `signature-pruning` for six source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- It sits immediately after `type-refining` and before `signature-refining` / `global-refining` in Binaryen's closed-world GC/type prepass cluster, so documenting it now makes the neighbor docs easier to understand.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official Binaryen implementation is much more specific than the name suggests: it is not general signature cleanup, but a heap-type-level dead-argument-elimination pass for nominal function types that works across all functions sharing a type and all `call_ref` users of that type.
- The implementation hides multiple beginner traps that are worth documenting explicitly:
  - the pass body requires `--closed-world` and will `Fatal()` if you invoke it directly without that option
  - any table in the module disables the entire pass today
  - imported / public / tag-used / continuation-used / JS-called / function-subtyped signatures are all excluded for different reasons
  - Binaryen can first materialize a constant actual value inside the callee body and only then prove that the parameter became removable
  - side-effectful or interacting call operands can trigger a delayed `ChildLocalizer` rerun, so the pass is intentionally a two-cycle pipeline rather than one simple rewrite walk
  - even when two signatures shrink to the same final function shape, Binaryen still preserves distinct heap types

So this thread is not re-opening an old parity item.
It is the first explicit living dossier for the closed-world `signature-pruning` pass that sits between the repo's new `type-refining` docs and the older `global-refining` docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/cfg/liveness-traversal.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit file checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `SignaturePruning.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed surfaces that matter most here:
  - same GC gate
  - same direct `--closed-world` requirement with `Fatal()` on misuse
  - same whole-module table bailout
  - same two-iteration cap
  - same public/tag/continuation/JS-called/subtyping exclusion matrix
  - same `ParamUtils::applyConstantValues -> ParamUtils::removeParameters -> GlobalTypeRewriter::updateSignatures -> localizeCallsTo(...)` structure
- the only diff in the checked pass file was a comment typo fix (`disctinct` -> `distinct`)
- the checked `pass.cpp` diff on these reviewed surfaces was unrelated typo cleanup elsewhere, not a `signature-pruning` scheduler change
- the checked dedicated lit file was identical on the reviewed surfaces

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable rule for the living wiki should be:

- use `version_129` as the normative algorithm oracle
- record later upstream drift explicitly if it matters
- do not invent a semantic drift story when the checked current surfaces still match the reviewed tag behavior

## Repo-local sources used for context

Starshine-side files that mattered while choosing and framing this dossier:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `signature-pruning`
- the local registry tracks the pass name `signature-pruning` only as a boundary-only upstream surface
- the current living `type-refining` and `global-refining` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `signature-pruning` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `signature-pruning` is not generic “signature cleanup.”

The real `version_129` contract is narrower and more concrete:

1. require GC features and a closed-world module
2. group functions and `call_ref` sites by **function heap type**, not by textual signature alone
3. figure out which parameters are actually live at function entry across every function with that heap type
4. opportunistically materialize constant actual values inside the callee bodies, which can make more parameters become unused
5. remove unused parameters from all functions with that heap type and from all direct and `call_ref` users of that heap type at once
6. rewrite the nominal signature types module-wide in one atomic `GlobalTypeRewriter` step
7. if side-effectful call operands blocked some removals, localize those operands and try one more cycle

A better short summary is:

- **Binaryen `signature-pruning` is heap-type-level dead-argument elimination for nominal function signatures, with constant-actual promotion and one delayed localization rerun.**

The three biggest beginner corrections are:

- the pass prunes **parameters only**; it does not refine parameter types or result types
- it works per **heap type**, so one imported/public/used sibling can block an otherwise removable parameter in another function with the same type
- the pass is intentionally a **two-cycle pipeline**, not a single in-place walk, because localization is delayed until after the signature rewrite

## Upstream naming and scheduler surface

`pass.cpp` registers `signature-pruning` with the summary:

- `remove params from function signature types where possible`

That summary is accurate, but too small.
It hides several central details:

- the pass rewrites **function heap types**, not just individual function declarations
- it explicitly considers both direct `call` users and `call_ref` users
- it can first rewrite bodies by materializing constant actual values
- it can run a second cycle after localizing effectful operands

### Relation to nearby passes

The source comment at the top of `SignaturePruning.cpp` compares the pass to DAE:

- DAE looks at one function at a time
- `signature-pruning` looks at one **heap type** at a time
- that lets it optimize indirectly called functions too, as long as all functions and `call_ref` uses with that heap type agree

That is the most useful mental model:

- **DAE per function**
- **signature-pruning per nominal function type**

### Scheduler placement

`signature-pruning` is not part of the repo's main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default prepass cluster is:

- if `wasm->features.hasGC()` and `options.optimizeLevel >= 2`
- and if `options.closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- then continue with:
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That teaches four durable things:

- this pass is a **closed-world pre-`global-refining`** signature cleanup step
- it belongs to the early GC/type cluster, not the later function-pass cluster
- its default-pipeline optimize-level gate lives in `pass.cpp`
- its pass body itself checks only:
  - `hasGC()`
  - `closedWorld`
  - `tables.empty()`

So if you invoke `--signature-pruning` directly, the pass body does **not** inspect `optimizeLevel`; that is a scheduler rule, not a pass-local semantic rule.

## Phase-by-phase reading of the official implementation

## Phase 0: hard gates

`SignaturePruning::run(Module* module)` begins with three strong gates:

- if `!module->features.hasGC()` -> return immediately
- if `!getPassOptions().closedWorld` -> `Fatal() << "SignaturePruning requires --closed-world"`
- if `!module->tables.empty()` -> return immediately

The table gate is especially important.
It is not a per-table-use bailout.
The entire pass returns on **any** table because the current implementation does not yet model:

- `call_indirect`
- element segments
- other table-mediated function-type uses

So the official `version_129` pass is all-or-nothing here.

## Phase 1: the pass is intentionally limited to two cycles

After the gates, `run()` does:

- `if (iteration(module)) { iteration(module); }`

So Binaryen runs at most **two** cycles.

The source comment explains why another cycle can help:

- one cycle can materialize a constant parameter value or localize an effectful operand
- that change can make another parameter removable only in the next cycle

But the pass does **not** compute a full fixed point.
A future port must preserve that practical limit unless it explicitly documents a divergence.

## Phase 2: parallel per-function collection

Inside `iteration()` the pass defines an `Info` summary with:

- `std::vector<Call*> calls`
- `std::vector<CallRef*> callRefs`
- `std::unordered_set<Index> usedParams`
- `bool optimizable = true`

Then it runs `ModuleUtils::ParallelFunctionAnalysis<Info>`.

For each function:

- imported functions are immediately marked `optimizable = false`
- `FindAll<Call>` collects direct calls in the body
- `FindAll<CallRef>` collects `call_ref` users in the body
- `ParamUtils::getUsedParams(func, module)` computes which parameters are actually live at function entry

The `getUsedParams` helper is more subtle than a raw `local.get` search.
It uses `LivenessWalker` at function entry and deliberately ignores:

- unreachable code
- reads of locals that only happen after the parameter value has already been overwritten
- non-parameter locals

So a parameter whose index is mentioned later in the body can still count as unused if the incoming value was dead before the first overwrite.
The lit file has an explicit regression for that.

## Phase 3: combine information by heap type, not by function name

The pass then folds the per-function summaries into two combined structures:

- `allInfo: HeapType -> Info`
- `sigFuncs: HeapType -> vector<Function*>`

This is the heart of the pass.
Everything from this point on is keyed by the **function heap type**.

### Direct calls

For each direct `call`, Binaryen looks up the callee function and appends the call to:

- `allInfo[callee->type.getHeapType()].calls`

### `call_ref`

For each `call_ref`, Binaryen uses the target expression's type and appends the call to:

- `allInfo[target->type.getHeapType()].callRefs`

So direct calls and `call_ref`s are both part of the same final decision, just gathered differently.

### Parameter liveness

For parameter liveness, the pass unions `usedParams` across every function that shares the same heap type.
That means:

- if **any** function with that heap type genuinely uses parameter `i`, then parameter `i` cannot be pruned from that heap type at all

This is the easiest wrong assumption to make if you think in terms of individual functions.

## Phase 4: special intrinsic handling happens while combining calls

While processing direct `Call*` nodes, `SignaturePruning.cpp` checks:

- `Intrinsics(*module).isCallWithoutEffects(call)`

When it finds one, it marks the target heap type as unoptimizable.
The important detail is that the actual target function reference of `call.without.effects` is stored in the **last operand**, not modeled like an ordinary direct call.

So the pass deliberately refuses to optimize those target signatures for now, rather than trying to special-case every intrinsic user update.

This is a good example of the pass being more conservative than the name suggests.

## Phase 5: external and unsupported boundary filters

After aggregation, the pass excludes more heap types from optimization.

### Public function types

It loops over `ModuleUtils::getPublicHeapTypes(*module)` and marks public **function** heap types unoptimizable.

This is broader than just exported functions.
`getPublicHeapTypes` in `module-utils.cpp` treats as public:

- imported function types
- exported function types
- imported table / global / tag boundary types
- transitively referenced types from already-public rec groups

That is why the lit file includes two subtle public-rec-group no-op cases:

- one where an exported function makes another function type in the same rec group public
- another where a public struct field reference prevents swapping the old public function type for a pruned private replacement

### Tags

For each tag in the module, the pass marks `tag->type` unoptimizable.
So any function type shared with a tag is frozen.
The test file has an explicit tag regression for this.

### Continuations

If stack switching is enabled, Binaryen scans all heap types and, for any continuation type, marks its underlying signature type unoptimizable.
The pass comment is explicit:

- users such as `cont.bind` / `resume` are not updated today

The lit file shows the key consequence:

- a normal function sharing a type with a continuation function is also blocked
- a different type in the same module can still optimize

### JS-called functions

The pass calls `Intrinsics(*module).getJSCalledFunctions()` and marks those signature types unoptimizable as well.
That helper covers:

- `@binaryen.js.called` annotations
- functions referenced from `configureAll` in the start function

So the real boundary is “signature-called from JS,” not only “exported from wasm.”

## Phase 6: function subtyping blocks pruning

The pass constructs `SubTypes subTypes(*module)` and then refuses to optimize any type that has either:

- an immediate subtype
- a declared signature supertype

The source comment explains the reason:

- a type must have the same number of params and results as its supertypes and subtypes

So the official implementation takes the simple conservative path:

- only prune signatures that are isolated from signature-subtyping relations

The lit file has an explicit no-op case for this, including a comment that Binaryen could in principle optimize a whole related cluster at once later.

## Phase 7: constant actuals can create new pruning opportunities

Once a type survives all those gates, the pass calls:

- `ParamUtils::applyConstantValues(funcs, info.calls, info.callRefs, module)`

This helper is one of the main hidden teaching surfaces.

### What the helper actually does

For each parameter index, `PossibleConstantValues` notes the actual operands from:

- every direct call
- every `call_ref`

If they all match and remain constant, Binaryen prepends:

- `local.set(paramIndex, constantExpr)`

to every function body with that heap type.

At that point the incoming parameter value is ignored, so the parameter may become unused.
The pass then erases that index from `usedParams`.

### What counts as a constant here

`PossibleConstantValues` accepts:

- literal constant expressions
- immutable `global.get`

And `Properties::isConstantExpression(...)` means this includes more than raw integers.
The lit file shows source-backed positives for:

- `i32.const`
- `ref.func`
- `ref.null`

and a negative mixed-value case where combining `ref.null` with another ref value prevents the optimization.

### Important negative fact

This step does **not** yet prune the call operands.
It only rewrites the callee bodies so the parameter becomes dead.
Pruning still happens in the next helper.

## Phase 8: parameter removal is synchronized across functions and call sites

If any parameters are now unused, the pass builds a sorted set of unused indexes and calls:

- `ParamUtils::removeParameters(funcs, unusedParams, info.calls, info.callRefs, module, getPassRunner())`

That helper attempts removal in descending index order.

### Safety checks before removal

For each candidate operand at each direct call and `call_ref`, `removeParameter` refuses removal when:

- the operand type is `unreachable`
- `EffectAnalyzer(...).hasUnremovableSideEffects()` is true

The `unreachable` check is easy to miss.
The source comment explains why the pass simply skips those today:

- removing the parameter could change the call expression's type from `unreachable` to something concrete
- Binaryen chooses not to propagate or re-wrap that here

### What successful removal does

On success, the helper:

1. shrinks the parameter list on all affected functions
2. clears local names
3. adds a new local for the removed parameter's old body uses
4. rewrites `local.get` / `local.set` indexes so internal uses now reference that new local
5. calls `TypeUpdating::handleNonDefaultableLocals` on the rewritten functions
6. erases the matching operands from both direct calls and `call_ref`s

That is another easy beginner trap:

- Binaryen does **not** simply delete the parameter and hope the body still works
- it preserves internal uses by turning the old parameter into a body local

## Phase 9: signature rewrite is atomic and distinct types stay distinct

When removals succeed, the pass computes a `newSignatures` map from old heap type to new `Signature(newParams, oldResults)`.

Then it calls:

- `GlobalTypeRewriter::updateSignatures(newSignatures, *module)`

This is the crucial module-wide commit point.

### Why the pass undoes temporary function type updates first

`removeParameters()` necessarily mutates function parameter lists while it works, because local indexing depends on the number of parameters.
But `signature-pruning` then immediately restores each function's nominal heap type before calling `updateSignatures()`.

The reason is source-backed and important:

- Binaryen wants all functions with a particular heap type, and all `call_ref` users of that heap type, to see the new signature **at once** in one rewrite
- the helper `GlobalTypeRewriter` is the component that can update all those type uses consistently

### Distinct types remain distinct

The source comment here is explicit too:

- even if two optimized types end up with the same final signature, the rewriter keeps them distinct heap types

The lit file has an explicit regression for that.

## Phase 10: localization is delayed until after type rewriting

If `removeParameters()` reported a failure for a type, the pass records one representative `Call` or `CallRef` expression in `callTargetsToLocalize`.
It does **not** store the original heap type directly.

The source comment explains why:

- `GlobalTypeRewriter::updateSignatures(...)` rewrites all heap types into a new combined rec-group world
- even unchanged heap types may no longer compare by their old identity
- a representative expression is a more stable thing to keep until after rewriting

After the signature rewrite, the pass re-discovers the updated target heap types from those saved expressions and then calls:

- `ParamUtils::localizeCallsTo(callTargetTypes, *module, getPassRunner())`

### What localization does

`localizeCallsTo(...)` uses `ChildLocalizer` from `localize.h`.
That helper can:

- hoist effectful or interacting operands into new locals
- replace now-moved children inside the call with `local.get`
- turn unreachable children into outer dropped/unreachable setup

And if that introduces blocks around EH `pop` traffic, the helper runs:

- `EHUtils::handleBlockNestedPops(...)`

The lit file has explicit catch/pop regressions for this phase.

### Why this implies a second cycle

Localization itself does not prune another parameter immediately.
It only makes later removal safe.
That is why the pass returns `true` and re-enters `iteration(module)` one more time.

## Important official test families

The single shipped `signature-pruning.wast` file is large enough to teach most of the contract.
The most useful families are:

- direct-call plus `call_ref` positives where middle parameters disappear from both the function type and all call sites
- full all-parameter removal cases
- overwritten-parameter liveness cases where a parameter index is still mentioned in the body but the incoming value is actually dead
- side-effectful actuals on `call` and `call_ref` that require localization before pruning
- import and same-heap-type sibling no-op cases
- different-heap-type same-final-signature cases that must remain distinct
- constant actual families for integer, `ref.func`, and `ref.null` values
- mixed constant-value negatives where two different values prevent optimization
- unreachable-expression regression coverage for type collection and printing stability
- `call.without.effects` negative coverage
- function-subtyping negative coverage
- local-index / tee / `struct.get` / v128 rewrite regressions for the parameter-to-local dance
- EH pop localization regressions
- public rec-group and public struct-field negative cases
- tag and continuation negative cases

That one lit file is effectively the user-facing specification for the pass.

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no result pruning
- no parameter type refinement
- no whole-module table / `call_indirect` support today
- no optimization of imported or public signature types
- no optimization of tag-used or continuation-used signature types
- no optimization of signature-subtyped clusters today
- no full fixed point beyond two iterations
- no guarantee that any single eligible unused parameter will be removed if operand effects or unreachable typing still block it after the second cycle

## What a future Starshine port must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- the algorithm is keyed by **heap type**, not by function name or textual signature string
- parameter liveness is based on entry liveness, not raw mention counting
- imported/public/tag/continuation/JS-called/subtyped signatures stay frozen
- the whole pass bails out if the module contains any tables
- constant actual materialization happens before final pruning and can create new dead parameters
- successful pruning must update both direct calls and `call_ref` users of the signature
- internal uses of a removed parameter become a new body local, with correct local-index repair
- nominal signature rewriting must happen atomically across the module through a global type rewrite step
- distinct heap types must stay distinct even if they converge to the same final signature
- localization is delayed until after the signature rewrite and only then triggers one extra cycle
- EH nested-pop fixups matter after localization

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.

## Bottom line

Binaryen `signature-pruning` in `version_129` is a **closed-world, GC-gated, heap-type-level dead-argument-elimination pass for nominal function signatures**.

The real contract is:

- collect uses per function
- combine decisions per heap type
- freeze a long list of externally visible or currently unsupported signature families
- promote constant actuals into callee bodies
- remove unused parameters across every function and call site sharing that heap type
- rewrite signature heap types atomically
- localize blocked operands and try once more

That is much more specific, and much more teachable, than the short pass summary alone.