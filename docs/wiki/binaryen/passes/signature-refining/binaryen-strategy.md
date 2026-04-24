---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../signature-pruning/index.md
  - ../global-refining/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `signature-refining` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass, anchored by the committed raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md).

Primary files:

- `src/passes/SignatureRefining.cpp`
- `src/passes/pass.cpp`
- `src/ir/lubs.h`
- `src/ir/lubs.cpp`
- `src/ir/module-utils.h`
- `src/ir/module-utils.cpp`
- `src/ir/type-updating.h`
- `src/ir/type-updating.cpp`
- `src/ir/subtypes.h`
- `src/ir/intrinsics.h`
- `src/ir/intrinsics.cpp`
- `test/lit/passes/signature-refining.wast`

This dossier also has a dedicated Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

I also did a narrow current-`main` check on the same surfaces.
Durable result:

- the checked `main` pass logic still matches the reviewed `version_129` algorithm on the important gates, phase split, and helper usage
- the checked dedicated lit file still matches the reviewed `version_129` surface exactly

So this dossier treats `version_129` as the normative algorithm oracle.

## High-level intent

Binaryen uses `signature-refining` to make **nominal function signature heap types** more specific when the module proves that:

- all actual arguments reaching that heap type have a tighter common subtype than the declared parameter type, and/or
- all returned values produced by functions with that heap type have a tighter common subtype than the declared result type

That is more precise than either of these summaries:

- refine function signature types
- tighten function params and results where possible

The real contract is closer to:

- **aggregate call-operand and return-value LUB facts by heap type, freeze public or unsupported type families, repair function bodies for sharper params, rewrite signature types atomically, then patch `call.without.effects` imports and refinalize**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate on GC + tables | Require GC and bail out if any table exists | The current implementation only handles the direct/`call_ref` world it can rewrite safely |
| Collect function-local facts in parallel | Gather direct calls, `call_ref`s, and result LUBs | The pass starts from per-function evidence |
| Combine by heap type | Union calls and result info per nominal signature type | Decisions are made per heap type, not per function |
| Freeze unsupported/public types | Exclude imports, public types, tags, and subtype-linked signatures; freeze params only for JS-called and continuation-used types | These surfaces are observable or not fully updated today |
| Compute param LUBs | Use all direct-call, `call_ref`, and `call.without.effects` actuals | Param refinement is driven by inputs |
| Compute result LUBs | Use function body and explicit/implicit returns | Result refinement is driven by outputs |
| Repair function bodies | `TypeUpdating::updateParamTypes(...)` inserts fixup locals as needed | Sharper params can otherwise invalidate broader local writes |
| Rewrite signature heap types | `GlobalTypeRewriter::updateSignatures(...)` | Type identities and `call_ref` users must update atomically |
| Repair intrinsics | Clone `call.without.effects` imports when refined target results demand it | The intrinsic import's own return type must stay consistent |
| Refinalize | Recompute enclosing types after all changes | Outer expression types can sharpen after the rewrite |

## Scheduler placement

`signature-refining` is not part of the repo's main open-world no-DWARF path.

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

## Important scheduler subtlety: closed world is a pipeline gate, not a pass-body gate

The default pipeline only adds `signature-refining` when:

- GC is enabled
- `optimizeLevel >= 2`
- `closedWorld`

But `SignatureRefining::run(Module* module)` itself checks only:

- `module->features.hasGC()`
- `module->tables.empty()`

So if a user invokes `--signature-refining` directly, the pass does not inspect `closedWorld` or `optimizeLevel` itself.
Those conditions belong to the default scheduler, not to the core algorithm.

That does **not** mean the pass is open-world-aggressive.
Instead, it stays conservative by freezing public/imported/tag/subtyped families.
I infer from the source that this is why direct invocation can still be sound without a hard `--closed-world` requirement, but the default optimizer keeps the pass in the closed-world GC cluster for normal preset behavior.

## Phase 0: strict early gates

`SignatureRefining::run(Module* module)` begins by:

- returning immediately on `!module->features.hasGC()`
- returning immediately if `!module->tables.empty()`

This is a real semantic boundary.
The pass is not trying to partially handle table-mediated signature users today.

## Phase 1: per-function facts come from parallel local analysis

Inside `run()` Binaryen defines:

- `Info { calls, callRefs, extraCalls, resultsLUB, canModify, canModifyParams }`

and runs `ModuleUtils::ParallelFunctionAnalysis<Info, Mutable>` over the module.

For each function:

- imports are immediately marked non-modifiable
- `FindAll<Call>` collects direct `call` sites
- `FindAll<CallRef>` collects `call_ref` sites
- `LUB::getResultsLUB(func, *module)` computes a possible refinement for the function's results

### Important side effect: result-LUB collection refinalizes first

`LUB::getResultsLUB(...)` is not just a read-only helper.
In `lubs.cpp` it first refinalizes the function so forced block types do not hide a sharper true result.
Then it notes:

- the body type
- `return` values
- `return_call` target results
- `return_call_indirect` heap-type results
- `return_call_ref` target-signature results

while skipping bottom / unreachable `call_ref` targets that only trap.

That means result refinement is driven by **what functions actually return**, not by what callers happen to expect.

## Phase 2: Binaryen combines facts by heap type, not by function

After the parallel scan, Binaryen folds those per-function summaries into:

- `allInfo: HeapType -> Info`

This is the main conceptual pivot of the whole pass.
Everything from this point on is about the **nominal function heap type**.

### Direct calls

For each direct `Call`, Binaryen finds the callee function and records the call under:

- `callee->type.getHeapType()`

### `call_ref`

For each `CallRef`, Binaryen records the call under:

- `callRef->target->type.getHeapType()`

when the target type is reachable.

### `call.without.effects` participates in param refinement

While combining direct calls, `SignatureRefining.cpp` checks:

- `Intrinsics(*module).isCallWithoutEffects(call)`

When that is true, Binaryen looks at the final operand, which is the referenced function, and appends the call to:

- `allInfo[targetType.getHeapType()].extraCalls`

The important detail is that later param-LUB collection ignores the final function-ref operand and only looks at the actual signature parameters.
So `call.without.effects` participates in parameter refinement of the target signature type.

That is a central source-backed difference from `signature-pruning`.

### Result LUBs also combine per heap type

For each function, the pass combines its `resultsLUB` into the heap type's shared `resultsLUB`.
So if multiple functions share the type, the final result type must be valid for all of them together.

## Phase 3: public and unsupported signature families are frozen

After combination, the pass excludes more heap types from optimization.

## 1. Public function heap types

Binaryen iterates `ModuleUtils::getPublicHeapTypes(*module)` and freezes any public function heap type.

This is broader than just exported functions.
`module-utils.cpp` shows that `getPublicHeapTypes` publicizes:

- imported functions, except `call.without.effects`
- exported functions
- imported tables / globals / tags with ref-typed boundaries
- transitively referenced types from already-public rec groups

So the true beginner rule is:

- public **rec-group reachability** freezes more than a plain export bit does

## 2. JS-called signatures freeze params only

The pass calls `Intrinsics(*module).getJSCalledFunctions()` and marks those heap types with:

- `canModifyParams = false`

not full `canModify = false`.

That means:

- result refinement can still happen
- parameter refinement cannot

This is one of the most important differences between what the pass sounds like and what it really does.

## 3. Continuation-used signatures also freeze params only

If stack switching is enabled, Binaryen scans all heap types and, for any continuation type, marks its underlying signature with:

- `canModifyParams = false`

again not full `canModify = false`.

The source comment is explicit that continuation users like `cont.bind` and `resume` are not updated today.

## 4. Tag-used signatures freeze the whole type

For each tag in the module, the pass sets:

- `allInfo[tag->type].canModify = false`

So any function signature type shared with a tag is frozen completely.

## 5. Function subtyping blocks refinement

The pass constructs `SubTypes subTypes(*module)` and then skips any heap type that has:

- any immediate subtype
- a declared signature supertype

The source comment explains the two reasons:

- changing a type with subtypes would require subtype-cluster updates too
- changing a type with a supertype would require contravariance-aware reasoning for params, which this pass does not handle

So the official implementation takes the conservative route:

- only refine signatures that are isolated from signature-subtyping relations

## Phase 4: parameter refinement comes from operand LUBs

For each surviving heap type, if `info.canModifyParams` is still true, Binaryen computes one `LUBFinder` per parameter.
It feeds those LUBs with operand types from:

- every direct call
- every `call_ref`
- every `extraCall` from `call.without.effects`

### What counts as a valid refinement here

If Binaryen successfully notes a non-bottom LUB for every parameter, it builds a new parameter tuple from those LUBs.
That can refine to things like:

- exact struct refs
- nullable exact refs
- parent struct refs from sibling subtype calls
- `eqref` from mixed struct/i31 traffic

### Important negative fact

If there are no calls, or some parameter is always `unreachable`, Binaryen gives up on parameter refinement for that heap type.
It does not infer a sharper param type from body usage.

So param refinement is strictly **caller-driven**.

## Phase 5: result refinement comes from returned-value LUBs

For results, Binaryen reads the heap type's combined `resultsLUB`.

If nothing was noted, the old results stay.
That happens when:

- no reachable reference result was observed
- the function never returns a reachable ref value
- the function only traps or otherwise bottoms out

Otherwise the new result type becomes:

- `resultsLUB.getLUB()`

This can refine result types to:

- exact struct refs
- nullable exact refs
- other sharper reference categories Binaryen's lattice supports

### Important asymmetry

- parameters refine from **incoming** values
- results refine from **outgoing** values

That asymmetry is the central teaching point of this pass.

## Phase 6: calls and `call_ref`s get updated cached result types immediately

If the result type changed for a heap type, the pass immediately updates the cached result type on:

- direct `call` nodes
- `call_ref` nodes

except when the node is already `unreachable`.

This matters because refinalization later needs enclosing control-flow expressions to see the sharper result type.

## Phase 7: Binaryen repairs function bodies for sharper params

If any signature changed at all, the pass launches an inner `CodeUpdater` walker.
For each affected function it calls:

- `TypeUpdating::updateParamTypes(func, newParamTypes, wasm, DoNotUpdate)`

This helper is one of the main hidden behavior surfaces.

### What `updateParamTypes(...)` actually does

In `type-updating.cpp`, the helper:

- scans all `local.set` uses of params
- if a set writes a value that is **not** a subtype of the new sharper param type
- creates a fresh fixup local with the old broader type
- prepends an initial `local.set(fixup, local.get(param))`
- rewrites later gets and sets to use the fixup local
- refinalizes the function
- runs `handleNonDefaultableLocals(...)` if new locals were added

That is why a future port cannot implement this pass as “just rewrite the type declarations.”

### Why `DoNotUpdate` matters

The source comment explains that this pass deliberately does **not** update `local.get` and `local.tee` types here.
That update is deferred to the later global signature rewrite so the IR never sits in a half-updated inconsistent state.

## Phase 8: the nominal signature rewrite is atomic

When Binaryen has collected all improvements, it stores them in:

- `newSignatures: HeapType -> Signature`

and commits them through:

- `GlobalTypeRewriter::updateSignatures(newSignatures, *module)`

This is the module-wide type-identity commit point.
It is exactly why the pass can refine signatures whose references are taken.

## Phase 9: `call.without.effects` needs custom result repair

After the signature rewrite, the pass calls:

- `updateIntrinsics(module, allInfo)`

The key issue is that `call.without.effects` is itself an imported function.
If the referenced function's result type was refined, the intrinsic import now has the wrong result type.

So Binaryen:

- creates a fresh intrinsic import with the same params and the sharper result type
- caches those cloned imports by new result signature so duplicates are reused
- rewrites the old intrinsic call targets to the cloned imports
- updates the intrinsic call nodes' cached result types

This is a real part of the algorithm, not bookkeeping noise.

## Phase 10: final refinalization

After all signature and intrinsic updates, Binaryen finishes with:

- `ReFinalize().run(getPassRunner(), module)`

This is mandatory because:

- sharper call results can tighten surrounding block/if types
- casts and locals may now finalize differently
- cached expression types across the module need to agree with the refined signatures

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no table / `call_indirect` support today
- no attempt to optimize types with subtypes or supertypes
- no multi-iteration or localization-driven fixed point
- no parameter refinement without call-site evidence
- no full update of tag users or continuation users
- no full closed-world check inside the pass body itself
- no signature deduplication between distinct nominal heap types

## Bottom line

Binaryen `signature-refining` in `version_129` is a **GC-gated, heap-type-level subtype-tightening pass for nominal function signatures**.

The source says to think of it this way:

- aggregate input LUBs and output LUBs by heap type
- freeze externally visible or currently unsupported type families
- repair bodies so sharper params remain valid
- rewrite the signature types atomically
- repair special intrinsic users
- refinalize afterward

That is the strategy a future strict-parity port must preserve.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>
