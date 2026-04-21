# 0152 - Binaryen `signature-refining` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `signature-pruning` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the prompt excludes the already-deepened parity passes, expand into another nearby upstream-only Binaryen pass that still has no dedicated living dossier.
- Create a new beginner-friendly but source-backed dossier for `signature-refining`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/signature-refining/`
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

- the main no-DWARF / saved-`-O4z` queue still had no pass with wiki status `none`
- the implemented-landing queue was already closed
- the prompt still excluded the recently refreshed parity dossiers and the newly added `remove-unused-types`, `type-refining`, and `signature-pruning` upstream-only dossiers
- the tracker's clearest still-`none` upstream-only candidates were `signature-refining`, `global-type-optimization`, `abstract-type-refining`, `unsubtyping`, `minimize-rec-groups`, and `reorder-types`
- `agent-todo.md` still had **no dedicated `signature-refining` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed another explicit queue-expansion pick from the tracker's upstream-only registry table.

I picked `signature-refining` for six source-backed reasons:

- It was still listed as `none` in the tracker's additional upstream-only registry table.
- It is already tracked in the local boundary-only registry in `src/passes/optimize.mbt`, so this is a real Starshine-facing pass name and not just an upstream tangent.
- It sits immediately after `signature-pruning` and immediately before `global-refining` in Binaryen's closed-world GC/type prepass cluster, so documenting it now keeps the growing cluster understandable instead of leaving a hole between neighboring dossiers.
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The official Binaryen implementation is more specific than the name suggests: it is not generic signature cleanup, but a heap-type-level subtype-tightening pass that refines **parameter types from actual call operands** and **result types from actual returned values**.
- The implementation hides multiple beginner traps that are worth documenting explicitly:
  - the default scheduler places it only in the closed-world GC cluster, but the pass body itself does **not** require `--closed-world`
  - any table in the module disables the entire pass today
  - imported, public, tag-used, and function-subtyping-related signatures are frozen for different reasons
  - JS-called and continuation-used signatures only freeze **parameter** refinement, while result refinement can still proceed
  - `call.without.effects` participates in **parameter** LUB computation for the referenced target signature, unlike the more conservative blocking rule in `signature-pruning`
  - `call.without.effects` also needs custom result-type repair by creating new intrinsic imports after refinement
  - the pass is a **single analysis/commit pass**, not a delayed two-cycle pipeline like `signature-pruning`

So this thread is not re-opening an old parity item.
It is the first explicit living dossier for the closed-world-cluster `signature-refining` pass that sits between the repo's new `signature-pruning` docs and the older `global-refining` docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit file checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `SignatureRefining.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed surfaces that matter most here:
  - same GC gate
  - same whole-module table bailout
  - same imported/public/tag/subtyping blockers
  - same split between `canModify` and `canModifyParams`
  - same `call.without.effects` extra-call handling for params
  - same `LUB::getResultsLUB(...)` result-refinement flow
  - same `TypeUpdating::updateParamTypes(...) -> GlobalTypeRewriter::updateSignatures(...) -> updateIntrinsics(...) -> ReFinalize()` structure
- the checked `pass.cpp` diff on these reviewed surfaces did not change the `signature-refining` registration or scheduler slot
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
- `docs/wiki/binaryen/passes/signature-pruning/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `signature-refining`
- the local registry tracks the pass name `signature-refining` only as a boundary-only upstream surface
- the current living `signature-pruning` and `global-refining` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `signature-refining` slice today**, so this note must say that explicitly rather than pretending a backlog slice already exists

## High-level conclusion

Binaryen `signature-refining` is not generic “make signatures better.”

The real `version_129` contract is narrower and more concrete:

1. require GC features and bail out entirely if the module contains any table
2. group functions, direct calls, `call_ref`s, and certain `call.without.effects` uses by **function heap type**, not by individual function name
3. compute better **parameter** types from the least upper bound of all actual operands reaching that heap type
4. compute better **result** types from the least upper bound of the function body and every explicit or implicit returned value of functions with that heap type
5. freeze types that are imported, public, tag-used, or participate in unsupported signature-subtyping relationships
6. freeze only parameter refinement for JS-called and continuation-used signatures, while still allowing result refinement
7. repair function bodies for refined parameter types with `TypeUpdating::updateParamTypes(...)`
8. atomically rewrite nominal signature heap types module-wide through `GlobalTypeRewriter::updateSignatures(...)`
9. repair `call.without.effects` imports so their own return types stay consistent with refined referenced functions
10. refinalize after the type changes so surrounding expression types stay valid

A better short summary is:

- **Binaryen `signature-refining` is a heap-type-level subtype-tightening pass for nominal function signatures, driven by call-operand LUBs for params and returned-value LUBs for results.**

The three biggest beginner corrections are:

- the pass refines **results as well as params**, unlike `signature-pruning`
- the pass is keyed by **heap type**, so one shared imported/public/tag/subtyped sibling can freeze an otherwise optimizable function type
- the pass is a **single analysis/commit pass**, not a localization-driven rerun pipeline

## Upstream naming and scheduler surface

`pass.cpp` registers `signature-refining` with the summary:

- `apply more specific subtypes to signature types where possible`

That summary is accurate, but too small.
It hides several central details:

- the pass rewrites **function heap types**, not just function declarations
- it refines **parameter types and result types**
- it explicitly considers both direct `call` users and `call_ref` users
- it gives special treatment to `call.without.effects`
- it uses returned-value LUBs, not only call-site information

### Relation to nearby passes

The source comment at the top of `SignatureRefining.cpp` compares the pass to DAE-style type refinement:

- DAE can refine a function's type only when the function type is unobservable
- `signature-refining` instead rewrites the **signature types themselves**
- that lets it optimize functions whose references are taken, as long as it considers all users of the heap type together

That is the most useful mental model:

- **DAE-style per-function boundary reasoning** is too narrow here
- **signature-refining** works per **nominal signature heap type**

### Scheduler placement

`signature-refining` is not part of the repo's main open-world no-DWARF path.

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

- this pass is a **closed-world pre-`global-refining`** signature-tightening step
- it belongs to the early GC/type cluster, not the later function-pass cluster
- its default-pipeline optimize-level gate lives in `pass.cpp`
- its pass body itself checks only:
  - `hasGC()`
  - `tables.empty()`

So if you invoke `--signature-refining` directly, the pass body does **not** inspect `closedWorld` or `optimizeLevel` itself.
That is a scheduler rule, not a pass-local semantic rule.

I infer from the source that Binaryen considers the pass safe enough for direct invocation because it freezes public/imported and other unsupported type families conservatively, but the default optimization pipeline still keeps it inside the closed-world GC cluster for normal optimize presets.
That inference should stay labeled as an inference.

## Phase-by-phase reading of the official implementation

## Phase 0: hard gates

`SignatureRefining::run(Module* module)` begins with two strong gates:

- if `!module->features.hasGC()` -> return immediately
- if `!module->tables.empty()` -> return immediately

The table gate is especially important.
It is not a per-table-use bailout.
The entire pass returns on **any** table because the current implementation does not yet model:

- `call_indirect`
- element segments
- table-mediated signature reachability in general

So the official `version_129` pass is all-or-nothing here.

## Phase 1: parallel per-function collection

Inside `run()` the pass defines an `Info` summary with:

- `std::vector<Call*> calls`
- `std::vector<CallRef*> callRefs`
- `std::vector<Call*> extraCalls`
- `LUBFinder resultsLUB`
- `bool canModify = true`
- `bool canModifyParams = true`

Then it runs `ModuleUtils::ParallelFunctionAnalysis<Info, Mutable>`.

For each function:

- imported functions are immediately marked `canModify = false`
- `FindAll<Call>` collects direct calls in the body
- `FindAll<CallRef>` collects `call_ref` users in the body
- `LUB::getResultsLUB(func, *module)` computes a possibly improved LUB for the function's results

That `Mutable` analysis mode matters because `LUB::getResultsLUB(...)` can refinalize the function body before computing the result LUB.
So the pass is not purely read-only even during collection.

### What `LUB::getResultsLUB(...)` really does

This helper is much more informative than its name alone suggests.
In `lubs.cpp` it:

- returns early if GC is off or the result type has no refs
- refinalizes the function before analysis so hidden forced block types do not mask more specific result values
- notes the function body's own type
- scans `return`
- scans `return_call`
- scans `return_call_indirect`
- scans `return_call_ref`
- skips bottom / unreachable `call_ref` targets that only trap

So result refinement is based on **returned-value shapes inside the function**, not on call sites.
That is a crucial difference from parameter refinement.

## Phase 2: combine information by heap type, not by function name

The pass then folds the per-function summaries into:

- `allInfo: HeapType -> Info`

This is the heart of the pass.
Everything from this point on is keyed by the **function heap type**.

### Direct calls

For each direct `call`, Binaryen looks up the callee function and appends the call to:

- `allInfo[callee->type.getHeapType()].calls`

### `call_ref`

For each `call_ref`, Binaryen uses the target expression's type and appends the call to:

- `allInfo[target->type.getHeapType()].callRefs`

if the target type is not `unreachable`.

### `call.without.effects` extra calls

This pass does something easy to miss:

- if a direct call is actually the `call.without.effects` intrinsic
- then its final operand is a function reference
- and Binaryen also appends that intrinsic call to
  - `allInfo[targetRefType.getHeapType()].extraCalls`

The key consequence is:

- `call.without.effects` contributes operand information to **parameter refinement** of the referenced function signature

That is much less conservative than `signature-pruning`, which simply freezes those target signatures.

### Result LUB aggregation

For results, the pass combines each function's `resultsLUB` into the heap type's shared `resultsLUB`.
That means:

- if multiple functions share a heap type, the final result refinement must be valid for all of them together

This is another easy wrong assumption to make if you think only in terms of individual functions.

## Phase 3: external and unsupported boundary filters

After aggregation, the pass excludes more heap types from optimization.

### Public function types

It loops over `ModuleUtils::getPublicHeapTypes(*module)` and marks public **function** heap types unmodifiable.

This is broader than just exported functions.
`getPublicHeapTypes` in `module-utils.cpp` treats as public:

- imported function types, excluding the `call.without.effects` intrinsic import itself
- exported function types
- imported table / global / tag boundary types with ref reachability
- transitively referenced types from already-public rec groups

So the real boundary is public **type reachability**, not just a visible export bit.

### JS-called functions

The pass calls `Intrinsics(*module).getJSCalledFunctions()` and marks those signature types as:

- `canModifyParams = false`

not `canModify = false`.

That means:

- parameter refinement is blocked for JS-called signatures
- result refinement can still proceed

This helper covers:

- `@binaryen.js.called` annotations
- functions named in `configureAll` inside the start function

So the real boundary is “signature-called from JS,” not just “exported from wasm.”

### Continuations

If stack switching is enabled, Binaryen scans all heap types and, for any continuation type, marks its underlying signature type as:

- `canModifyParams = false`

again not fully unmodifiable.

The source comment is explicit:

- users such as `cont.bind` / `resume` are not updated today

So continuation-sharing signatures keep their parameters, but result refinement is still not explicitly blocked by this rule.
The dedicated lit file only proves the parameter-side behavior, so that distinction should stay labeled as source-backed but only partially test-backed.

### Tags

For each tag in the module, the pass marks `tag->type` as fully unmodifiable.
So any function type shared with a tag is frozen completely.

This is stricter than the continuation rule.
The test file has an explicit tag regression for this.

### Function subtyping

The pass constructs `SubTypes subTypes(*module)` and then refuses to optimize any type that has either:

- an immediate subtype
- a declared signature supertype

The source comments explain the reasons:

- when a type has subtypes, modifying it would require modifying the subtype cluster too
- when a type has a supertype, contravariant parameter constraints are not handled here

So the official implementation takes the simple conservative path:

- only refine signature types that are isolated from signature-subtyping relations

The lit file has explicit no-op cases for both directions.

## Phase 4: compute parameter LUBs from actual call operands

Once a type survives those gates, the pass computes parameter refinements if `info.canModifyParams` is still true.

It builds one `LUBFinder` per parameter index and feeds it operand types from:

- every direct `call`
- every `call_ref`
- every `extraCall` coming from `call.without.effects`

For `extraCall`s it intentionally ignores the final function-reference operand and only looks at the real signature parameters.

### What counts as an improvement here

If every parameter got enough non-bottom information, Binaryen builds a new parameter tuple from the parameter LUBs.
This can refine:

- nullability
- heap-type parent/child precision
- exactness when the LUB is exact
- high-level ref kinds such as `anyref -> eqref`

### Important negative fact

If there are no calls, or some parameter position is always `unreachable`, Binaryen gives up on parameter refinement for that heap type.
It does **not** invent a refined parameter type from the body.

So parameter refinement is purely **call-input-driven**.

## Phase 5: compute result LUBs from actual returned values

For results, the pass reads the heap type's combined `resultsLUB`.

If nothing was noted, the old result type stays.
That happens when:

- the function does not return a reachable ref value
- the function only traps / is unreachable
- the result has no ref types

Otherwise the new result type becomes:

- `resultsLUB.getLUB()`

This can tighten result types to:

- exact struct refs
- nullable exact refs
- other more specific ref kinds supported by Binaryen's type lattice

### Important difference from params

- params refine from **incoming call operands**
- results refine from **outgoing returned values**

The pass name hides that asymmetry, so the docs should not.

## Phase 6: update call and `call_ref` expression result types immediately

If a heap type gets a refined result type, the pass immediately updates the cached expression types on its users:

- direct `call` nodes
- `call_ref` nodes

except when the call type is already `unreachable`.

This matters because later refinalization needs surrounding control constructs to see the sharper result types.

## Phase 7: repair function bodies for refined parameter types

If any heap type changed, the pass first runs an inner `CodeUpdater` walker.
For each function whose heap type was refined, it calls:

- `TypeUpdating::updateParamTypes(func, newParamTypes, wasm, DoNotUpdate)`

This helper is a hidden teaching surface.
It does much more than rename the declared params.

### What `updateParamTypes(...)` really does

In `type-updating.cpp`, the helper:

- scans `local.set` uses of params
- if a set writes a value that is **not** a subtype of the new refined param type
- creates a fresh fixup local with the old broader type
- prepends `local.set(fixup, local.get(param))`
- rewrites matching gets and sets to use the fixup local instead
- refinalizes afterward
- runs `handleNonDefaultableLocals(...)` if new fixup locals were introduced

That is how Binaryen avoids validation failures when refining a parameter that the function body later reuses as a broader scratch local.

### Why `DoNotUpdate` matters

The pass does **not** update `local.get` / `local.tee` types here yet.
The source comment explains why:

- doing so now would create a partially updated IR
- the full nominal type update will happen later through `GlobalTypeRewriter::updateSignatures(...)`

So this stage repairs body structure without yet committing the final global heap-type rewrite.

## Phase 8: rewrite signature heap types atomically

When the pass has collected all improvements, it stores them in:

- `newSignatures: HeapType -> Signature`

and then calls:

- `GlobalTypeRewriter::updateSignatures(newSignatures, *module)`

This is the module-wide commit point.

The rewriter updates signature heap types atomically across the module, which is exactly why the pass can optimize signatures that are taken by reference.

## Phase 9: `call.without.effects` needs custom result repair

After the signature rewrite, the pass calls:

- `updateIntrinsics(module, allInfo)`

This helper is one of the most distinctive parts of `signature-refining`.

### Why the intrinsic needs extra work

Suppose a function reference passed to `call.without.effects` originally had result type `(ref null $A)`.
If the referenced function's signature is refined to `(ref (exact $B))`, then the intrinsic call expression should also now return that sharper type.

But the intrinsic import itself still has the old result type.
So Binaryen:

- creates a fresh intrinsic import with the same params and a refined result type
- reuses one cloned import per new result signature type
- rewrites matching `call.without.effects` calls to target the cloned import
- updates the call node's cached result type too

That is a real algorithm step, not optional polish.

## Phase 10: final refinalization

After rewriting signatures and intrinsic imports, the pass finishes with:

- `ReFinalize().run(getPassRunner(), module)`

This is mandatory because:

- refined call or param types can sharpen enclosing block/if types
- cast and local traffic may now finalize differently
- cached expression result types need consistent recomputation

The lit file includes explicit regressions where the visible printed output only becomes correct after this refinalization.

## Important official test families

The single shipped `signature-refining.wast` file is large enough to teach most of the contract.
The most useful families are:

- direct-call parameter refinement to exact struct refs
- `call_ref` parameter refinement with the same nominal signature
- mixed direct plus `call_ref` inputs where the LUB lands on `eqref` or a common parent struct
- multiple functions sharing one heap type, including the case where only one function is called but both definitions must still update
- body-repair regressions where refining params requires fixup locals because the old broader type is still assigned inside the body
- unreachable-argument cases that still allow refinement when some reachable calls remain, and no-op cases when only unreachable values are seen
- no-call no-op cases
- nullable-exact parameter refinement when some calls pass `null`
- result refinement through actual returned struct refs and nullable refs, including `call` and `call_ref` user-type updates
- table-present whole-pass bailout
- export/public-rec-group no-op cases
- imported-function no-op cases
- subtype/supertype no-op cases
- bottom `call_ref` / unreachable emission regressions
- array/non-null refinalization regressions after param sharpening
- `call.without.effects` result-import cloning and param-LUB participation cases
- tag no-op cases
- continuation param-freeze cases

That one lit file is effectively the user-facing specification for the pass.

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no table / `call_indirect` support today
- no attempt to optimize types that participate in signature subtyping
- no multi-iteration fixpoint search
- no parameter refinement from body usage or return values alone when there is no call-site evidence
- no special closed-world requirement inside the pass body itself
- no full update of continuation users or tag users
- no signature deduplication between distinct nominal heap types

## What a future Starshine port must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- the algorithm is keyed by **heap type**, not by function name or textual signature string
- params refine from **call operand LUBs**, while results refine from **returned-value LUBs**
- imported/public/tag/subtyped types stay frozen
- JS-called and continuation-used signatures only freeze **param** refinement
- the whole pass bails out if the module contains any table
- `call.without.effects` contributes to target param LUBs as an extra-call surface
- `call.without.effects` result sharpening requires cloned intrinsic imports after signature rewriting
- body repair for refined params needs fixup locals when broader assignments still happen later
- nominal signature rewriting must happen atomically across the module through a global type rewrite step
- final refinalization is required after the type updates
- the pass is a single analysis/commit run, not a two-cycle localization pipeline

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.

## Bottom line

Binaryen `signature-refining` in `version_129` is a **GC-gated, heap-type-level subtype-tightening pass for nominal function signatures**.

The real contract is:

- collect calls and returned-value facts per function
- combine decisions per heap type
- freeze externally visible or currently unsupported type families
- refine params from actual operand LUBs
- refine results from actual returned-value LUBs
- repair function bodies for sharper params
- rewrite signature heap types atomically
- repair `call.without.effects` imports
- refinalize the module

That is much more specific, and much more teachable, than the short pass summary alone.
