---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./wat-shapes.md
  - ../type-refining/index.md
  - ../global-refining/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `signature-pruning` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/SignaturePruning.cpp`
- `src/passes/pass.cpp`
- `src/passes/param-utils.h`
- `src/passes/param-utils.cpp`
- `src/ir/module-utils.h`
- `src/ir/module-utils.cpp`
- `src/ir/type-updating.h`
- `src/ir/subtypes.h`
- `src/ir/intrinsics.h`
- `src/ir/intrinsics.cpp`
- `src/ir/possible-constant.h`
- `src/ir/localize.h`
- `src/ir/eh-utils.h`
- `src/cfg/liveness-traversal.h`
- `test/lit/passes/signature-pruning.wast`

I also did a narrow current-`main` check on the same surfaces.
Durable result:

- the checked `main` pass logic still matches the reviewed `version_129` algorithm on the important gates, phase split, and helper usage
- the only diff in `SignaturePruning.cpp` was a comment typo fix
- the checked dedicated lit file still matches the reviewed `version_129` surface

So this dossier treats `version_129` as the normative algorithm oracle.

## High-level intent

Binaryen uses `signature-pruning` to remove parameters from **nominal function signature heap types** when the whole closed-world module proves those parameters are dead across:

- every function with that heap type
- every direct `call` to functions with that heap type
- every `call_ref` using that heap type

That is more precise than either of these summaries:

- remove unused signature params
- dead-argument elimination for function types

The real contract is closer to:

- **aggregate per-function liveness by heap type, optionally promote constant actuals into the callee body, prune unused params across all sibling functions and call sites, rewrite the signature type atomically, then rerun once after delayed operand localization if necessary**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate on GC + closed world + tables | Require GC, require `--closed-world`, bail out if any table exists | The current implementation only handles the nominal direct/`call_ref` world it can rewrite safely |
| Collect function-local facts in parallel | Gather direct calls, `call_ref`s, and entry liveness for params | The pass starts from individual function facts |
| Combine by heap type | Union param liveness and call users per function heap type | Decisions are made per nominal type, not per function |
| Freeze unsupported/public types | Exclude imports, public types, tags, continuations, JS-called signatures, and subtype-linked signatures | These surfaces are observable or not fully updated today |
| Apply constant actuals | Materialize identical constant arguments inside callee bodies | That can make more parameters become dead |
| Remove unused params | Rewrite all sibling functions and their direct/`call_ref` users together | Signature pruning must stay synchronized across every user of the heap type |
| Rewrite signature heap types | `GlobalTypeRewriter::updateSignatures(...)` | Type identities and `call_ref` users must update atomically |
| Localize blocked operands and rerun once | `ChildLocalizer` hoists interacting/effectful operands, then the pass gets one extra cycle | Some removable params are blocked only by operand placement, not by true semantic necessity |

## Scheduler placement

`signature-pruning` is not part of the repo's main open-world no-DWARF path.

The relevant upstream `pass.cpp` neighborhood is:

- if GC is enabled and `optimizeLevel >= 2`
- and if `closedWorld`
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

That means this pass is an **early closed-world GC/type-cluster prepass**.
It is not part of the repo's current open-world parity queue.

## Important scheduler subtlety: optimize level is a pipeline gate, not a pass-body gate

The default pipeline only adds `signature-pruning` when `optimizeLevel >= 2`.

But `SignaturePruning::run(Module* module)` itself checks only:

- `module->features.hasGC()`
- `getPassOptions().closedWorld`
- `module->tables.empty()`

So if a user invokes `--signature-pruning` directly, the pass does not inspect `optimizeLevel` itself.
That optimize-level condition belongs to the default scheduler, not to the core algorithm.

## Phase 0: strict early gates

`SignaturePruning::run(Module* module)` begins by:

- returning immediately on `!module->features.hasGC()`
- `Fatal()`ing if `!getPassOptions().closedWorld`
- returning immediately if `!module->tables.empty()`

This is a real semantic boundary.
The pass is not trying to be “mostly okay” in open world, and it is not trying to partially handle table-mediated uses.

## Phase 1: the pass is deliberately limited to two cycles

After the gates, the pass does:

- `if (iteration(module)) { iteration(module); }`

So Binaryen gives itself at most **two** chances.
The source comment explains why another cycle can help:

- constant actual promotion can make another parameter dead later
- call operand localization can make a previously blocked removal safe later

But the pass does **not** run to a full fixed point.
That limited rerun is part of the official contract.

## Phase 2: per-function facts come from parallel local analysis

Inside `iteration()` Binaryen defines:

- `Info { calls, callRefs, usedParams, optimizable }`

and runs `ModuleUtils::ParallelFunctionAnalysis<Info>` over the module.

For each function:

- imports are immediately marked non-optimizable
- `FindAll<Call>` collects direct `call` sites
- `FindAll<CallRef>` collects `call_ref` sites
- `ParamUtils::getUsedParams(func, module)` computes which parameters are live at **function entry**

### Important negative fact

The pass does **not** decide parameter usage by searching for every `local.get` of a parameter index.
It uses entry liveness.
That means a parameter can still count as unused even if its index appears later in the body, when the incoming value was overwritten first.
The lit file has an explicit regression for that.

## Phase 3: Binaryen combines facts by heap type, not by function

After the parallel scan, Binaryen folds those per-function summaries into:

- `allInfo: HeapType -> Info`
- `sigFuncs: HeapType -> vector<Function*>`

This is the main conceptual pivot of the whole pass.
Everything from this point on is about the **nominal function heap type**.

### Direct calls

For each direct `Call`, Binaryen finds the callee function and records the call under:

- `callee->type.getHeapType()`

### `call_ref`

For each `CallRef`, Binaryen records the call under:

- `callRef->target->type.getHeapType()`

### Parameter liveness

For parameter usage, Binaryen unions `usedParams` across all functions sharing the heap type.
So if even one sibling function really needs parameter `i`, that parameter stays for the whole heap-type family.

## Phase 4: `call.without.effects` gets a special blocker rule

While combining direct calls, `SignaturePruning.cpp` checks:

- `Intrinsics(*module).isCallWithoutEffects(call)`

When that is true, Binaryen looks at the last operand, which is the actual function reference target of the intrinsic, and marks that target heap type non-optimizable.

This is a deliberate conservative rule.
The pass does not try to update those intrinsic-mediated signature users today.
The lit file has an explicit no-op regression for this family.

## Phase 5: public and unsupported signature families are frozen

After combination, the pass excludes more heap types from optimization.

## 1. Public function heap types

Binaryen iterates `ModuleUtils::getPublicHeapTypes(*module)` and freezes any public function heap type.

This is broader than just exported functions.
`module-utils.cpp` shows that `getPublicHeapTypes` publicizes:

- imported functions
- exported functions
- imported tables / globals / tags with ref-typed boundaries
- transitively referenced types from already-public rec groups

That explains the test cases where:

- exporting one function makes another function type in the same rec group public too
- a public struct type that mentions a function type can block pruning because Binaryen cannot just swap the old public reference to a new private pruned signature

## 2. Tags

For each tag, the pass freezes `tag->type`.
So any function signature type shared with a tag stays unchanged.

## 3. Continuations

If stack switching is enabled, Binaryen walks all heap types and freezes the underlying signature of every continuation type.
The source comment is explicit that users such as `cont.bind` / `resume` are not updated here.

## 4. JS-called signatures

The pass calls `Intrinsics(*module).getJSCalledFunctions()` and freezes the heap types of those functions.
That helper covers:

- `@binaryen.js.called` annotations
- `configureAll`-listed functions in the start function

So the true boundary is “signature-called from JS,” not merely “wasm-exported.”

## Phase 6: function subtyping blocks pruning

The pass constructs `SubTypes subTypes(*module)` and then skips any heap type that has:

- any immediate subtype
- a declared signature supertype

The source comment explains why:

- a type must have the same number of params and results as its supertypes and subtypes

So the official implementation takes the simple conservative route:

- only prune signatures that are isolated from signature-subtyping relations

The lit file has an explicit no-op family for that.

## Phase 7: constant actuals can create new pruning opportunities

For each surviving heap type, Binaryen first calls:

- `ParamUtils::applyConstantValues(funcs, info.calls, info.callRefs, module)`

This is a key beginner trap.
The pass does **not** jump straight from “unused params” to “remove params.”
It first tries to make more params unused.

### What `applyConstantValues(...)` actually does

For each parameter index, `PossibleConstantValues` notes the actual operands from:

- every direct call
- every `call_ref`

If they all collapse to the same constant, Binaryen prepends:

- `local.set(paramIndex, constantExpr)`

to every function body sharing that heap type.
That makes the incoming parameter value irrelevant, which can make the parameter dead.
The pass then removes that index from `usedParams`.

### What counts as a constant here

`PossibleConstantValues` supports:

- constant literal expressions via `Properties::isConstantExpression(...)`
- immutable `global.get`

The lit file shows concrete positive families for:

- integer constants
- `ref.func`
- `ref.null`

and a negative mixed-value family where `ref.null` plus a different ref value blocks the optimization.

### Important negative fact

This step does **not** update call sites yet.
It only rewrites the callee bodies so later pruning becomes legal.

## Phase 8: parameter removal is synchronized across sibling functions and all users

If any parameters are now unused, the pass builds a sorted set of dead indexes and calls:

- `ParamUtils::removeParameters(funcs, unusedParams, info.calls, info.callRefs, module, getPassRunner())`

This helper removes parameters in descending index order.

### Removal safety checks

For every candidate removed operand at every direct call and `call_ref`, the helper refuses removal when:

- the operand type is `unreachable`
- `EffectAnalyzer(...).hasUnremovableSideEffects()` is true

The `unreachable` rule is easy to miss.
The source comment explains that Binaryen does not want to deal here with changing the surrounding call type from `unreachable` to something concrete.
So it simply skips such cases.

### What successful removal actually rewrites

On success, the helper:

1. shrinks the parameter list on all affected functions
2. clears local names
3. adds a new body local for the removed parameter's old internal uses
4. updates `local.get` / `local.set` indexes so those uses now target the new local
5. runs `TypeUpdating::handleNonDefaultableLocals(...)`
6. erases the matching operands from direct calls and `call_ref`s

So Binaryen does **not** just delete the parameter and hope the body still works.
It preserves internal uses by converting the removed parameter into a regular local.

## Phase 9: the nominal signature rewrite is atomic and preserves distinct types

When removals succeed, the pass fills:

- `newSignatures: HeapType -> Signature`

and later commits all of them through:

- `GlobalTypeRewriter::updateSignatures(newSignatures, *module)`

### Why the pass restores the old nominal type before the rewrite

`removeParameters()` necessarily mutates function param lists while it works, because local indexing depends on the number of params.
But `signature-pruning` then restores each function's old nominal heap type before the final type rewrite.

The reason is source-backed and important:

- Binaryen wants all functions with that heap type, and all `call_ref` users of it, to observe the new signature **at once**
- `GlobalTypeRewriter` is the helper that can update every type use consistently

### Distinct heap types stay distinct

The source comment also makes this explicit:

- even if two different heap types end up with the same final `(func ...)` shape after pruning, Binaryen keeps them distinct types

The lit file has a dedicated regression for that.

## Phase 10: localization is delayed until after the type rewrite

If `removeParameters(...)` reports failure for a type, the pass stores one representative `Call` or `CallRef` expression in `callTargetsToLocalize`.
It does **not** store the old heap type directly.

The source comment explains why:

- `GlobalTypeRewriter::updateSignatures(...)` rewrites every heap type into a new rebuilt world
- even unchanged types may no longer be represented by the exact same heap-type object identity
- the saved call expression is a stabler handle until after rewriting finishes

After the rewrite, the pass re-derives the updated heap types from those representative expressions and calls:

- `ParamUtils::localizeCallsTo(callTargetTypes, *module, getPassRunner())`

### What localization actually does

`localizeCallsTo(...)` uses `ChildLocalizer` from `localize.h`.
That helper can:

- hoist interacting or effectful operands into locals
- replace the moved children inside the call with `local.get`
- turn unreachable children into outer dropped / `unreachable` setup

If that introduces blocks around EH pops, the helper then runs:

- `EHUtils::handleBlockNestedPops(...)`

The lit file has explicit catch/pop regressions for this family.

### Why this implies one extra cycle

Localization itself does not prune the blocked param immediately.
It only reshapes the call so another `iteration(module)` might succeed.
That is why the pass returns `true` here and gives itself one more cycle.

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no result pruning
- no parameter type refinement
- no table / `call_indirect` support today
- no open-world mode
- no optimization of public, imported, tag-used, continuation-used, or JS-called signature types
- no optimization of function-subtyped signature clusters today
- no full fixed point beyond two cycles

## Bottom line

Binaryen `signature-pruning` in `version_129` is a **closed-world, GC-gated, heap-type-level dead-argument-elimination pass with constant-actual promotion and one delayed localization rerun**.

The pass name sounds flatter than the implementation really is.
The source says otherwise:

- aggregate liveness by heap type
- freeze externally visible or currently unsupported signature families
- materialize constant actuals inside the callee when profitable
- prune unused params across all sibling functions and users together
- rewrite nominal signature types atomically
- localize blocked call operands and try once more

That is the strategy a future strict-parity port must preserve.

## Sources

- [`../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
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
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>
