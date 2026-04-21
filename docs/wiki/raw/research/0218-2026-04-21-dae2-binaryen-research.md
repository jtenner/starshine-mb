# Binaryen `dae2` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: official Binaryen `version_129` `dae2` pass, why it deserves its own wiki dossier, how it is actually implemented, what IR families it rewrites, and how it differs from plain `dae` / `dae-optimizing`.

## Why this note exists

The pass tracker no longer has an obvious remaining `none` target.
So this note is an explicit tracker expansion.

I chose `dae2` because:

- it is **not** on this thread's exclusion list,
- it is a real upstream public pass name in Binaryen `version_129`,
- the existing `dead-argument-elimination` dossier already has to mention it as a separately registered experimental pass,
- but the tracker and pass folder map did **not** yet give `dae2` its own canonical home.

`agent-todo.md` currently has **no dedicated `dae2` slice**.
That is expected: this is upstream-only research and not a current Starshine implementation task.

## Main conclusion

Binaryen `version_129` `dae2` is **not** just a rename of plain `dae`, and it is not a tiny optimizing wrapper.
It is a separate experimental reimplementation built around a **backward fixed-point analysis of used parameters and forwarded parameters**.

A better beginner summary is:

- scan each function once to find which incoming params are directly used,
- also find params that are only forwarded through direct calls, `call_ref`, or `call_indirect`,
- propagate “used” backward through those forwarding edges until a fixed point,
- then remove unused params and corresponding arguments,
- and, when Binaryen is allowed to rewrite referenced function types, also rebuild the relevant function-type trees and repair all affected reference-holding locations.

That makes `dae2` much closer to a **call-graph and function-type-tree analysis pass** than to the iterative direct-call boundary mutator used by plain `dae`.

## Why `dae2` matters next to `dae`

The existing plain-`dae` dossier already had to warn readers not to treat `dae2.wast` as the oracle for normal DAE.
That is a sign the neighboring docs were missing a canonical home for the sibling.

`dae2` also teaches a different set of ideas than plain DAE:

- smallest-fixed-point backward propagation instead of iterative localization rounds,
- parameter forwarding cycles as first-class analysis objects,
- indirect-call and `call_ref` participation through root function-type trees,
- global type rewriting for referenced functions under `--closed-world` + GC,
- and explicit current non-goals like no result removal and no constant/type propagation yet.

## Official sources reviewed

### Core implementation and registration

- `src/passes/DeadArgumentElimination2.cpp`
- `src/passes/pass.cpp`

### Official tests

- `test/lit/passes/dae2.wast`

### Supporting helper surface

- `src/ir/local-graph.h`
- `src/ir/module-utils.h`
- `src/ir/type-updating.h`
- `src/ir/intrinsics.h`
- `src/ir/eh-utils.h`
- `src/ir/effects.h`
- `src/support/mixed_arena.h`
- `src/wasm-type-shape.h`

## Public-pass identity

`pass.cpp` registers `dae2` as its own public pass name, with the description:

- experimental reimplementation of DAE.

So this is not just a comment-only experiment hidden behind plain `dae`.
It is a real public Binaryen pass.

It is also **upstream-only** for this repo right now:

- it is not part of the local no-DWARF default optimize path page,
- it is not part of the saved generated-artifact `-O4z` skipped-slot queue,
- and it is not currently named in the local Starshine pass registry.

That makes this a justified upstream-only tracker expansion, similar in spirit to `ssa`, `type-ssa`, and `string-lowering`.

## What the implementation actually does

## 1. The file states its own current ambition and current limits

The top comment of `DeadArgumentElimination2.cpp` is unusually explicit.
It says the pass currently performs:

- a smallest fixed-point backward analysis of used parameters,
- collection of call-graph and forwarding information,
- one optimization traversal to remove unused params and arguments,
- and an optional final global-type update step for referenced functions.

The same comment also says what `dae2` does **not** yet do:

- no unused-result analysis yet,
- no forward constant propagation,
- no forward type propagation through params/results.

That is a major teaching point.
`dae2` is narrower than plain `dae` today on result and constant/value refinement, even though it is broader on forwarding-graph reasoning.

## 2. The core analysis unit is “used or unused parameter”, not “callsite mutation opportunity”

The main lattice is just:

- top / `true` = used,
- bottom / `false` = unused.

The pass tracks usage per:

- function parameter,
- and, for referenced/indirect cases, per **root function-type tree**.

So the pass is asking:

> which params are definitely required once all direct and indirect forwarding is accounted for?

not:

> which direct-call boundary can I mutate safely this iteration?

That is a very different framing from plain `dae`.

## 3. `FunctionInfo` reveals the real algorithmic surface

Per function, Binaryen stores:

- `paramUsages`
- `directForwardedParams`
- `indirectForwardedParams`
- `callerParams`
- `paramGets`
- `contTypes`
- `referenced`
- `usedInIntrinsic`
- `replacementType`

Those fields imply the real contract.

### `directForwardedParams`

Tracks params that are merely forwarded into direct calls.

### `indirectForwardedParams`

Tracks params forwarded into `call_ref` / `call_indirect`, keyed by the **root** of the callee function-type tree.

### `paramGets`

Tracks the local gets that may still disappear later if they only participate in removable forwarding expressions.

### `referenced`

Marks functions whose identity escapes through `ref.func`, imports, exports, element segments, or other module-level reference sites.

### `replacementType`

Exists because unreferenced functions may need a temporary replacement function type so later global type rewriting does not accidentally optimize them as if they were still referenced siblings.

That last point is one of the most non-obvious parts of the pass.

## 4. The scan phase uses `LazyLocalGraph` to distinguish incoming-param uses from reused local slots

Like plain DAE's helper story, `dae2` cannot treat every `local.get` of a parameter index as a real use of the incoming boundary value.

Instead it builds a `LazyLocalGraph` and asks where the incoming parameter value may flow.

This matters because:

- overwriting a param local does not make the original incoming value used,
- forwarding chains through side-effect-free wrapper expressions can still count as removable forwarding,
- but values flowing into effectful or control-sensitive contexts must be marked used.

## 5. The forwarding notion is broader than “passed directly as an argument”

The source comment and walker logic make forwarding more general than a raw `call $f (local.get $x)` matcher.

A param can still be considered only forwarded when its `local.get` is consumed by:

- another call argument,
- or a side-effect-free intermediate expression that is itself forwarded to a call.

So simple wrappers like arithmetic or tuple construction can remain in the forwarding graph if they are pure enough.

But there are important conservative boundaries.

## 6. `If` conditions are always treated as real uses

The walker has a dedicated rule for `if` conditions:

- if the parameter flows into the condition, it is considered used.

The comment explains why:

- changing that value could visibly change which arm executes,
- and the general effects analysis is not trusted to capture that control sensitivity by itself.

So `dae2` is deliberately conservative on branch conditions.

## 7. Effectful parents stop forwarding-based removal

The walker runs `EffectAnalyzer` on parents while climbing outward from a candidate `local.get`.
If a parent has unremovable side effects, the param is treated as used.

This is the key reason the optimizer can later delete whole forwarded expression trees without duplicating or dropping visible effects incorrectly.

## 8. `call_ref` / `call_indirect` participate only in the referenced-functions mode

`dae2` has a major mode split:

- `optimizeReferencedFuncs = closedWorld && GC`.

When that is false:

- referenced functions are not optimized through global type rewriting,
- indirect/reference calls are not analyzed precisely enough to propagate removable params through type trees,
- and the pass limits itself to unreferenced-function cleanup.

When that is true:

- `call_ref` and `call_indirect` forwarding edges are keyed by root function-type tree,
- and later optimization can rewrite referenced function types globally.

So `--closed-world` + GC is not a tiny extra aggression knob here.
It changes which whole family of rewrites is even available.

## 9. Imports, exports, `ref.func`, JS-called functions, continuations, and `call.without.effects` all become blockers

The scan and module-level preparation explicitly mark some surfaces as non-optimizable or unrewritable.

These include:

- imported functions,
- exported functions,
- `ref.func`-referenced functions,
- JS-called functions,
- functions used in `call.without.effects`,
- continuation function types,
- public function types and private subtypes of public function types,
- and tag-associated function-type roots.

This is not one generic “escape” bit.
It is a matrix of reasons why either:

- the params themselves must stay used,
- or the enclosing function-type tree cannot be rewritten globally.

## 10. The fixed point is over the **reverse** forwarding graph

After the scan, `dae2` builds reverse edges:

- from callee parameter to caller parameter for direct calls,
- from root-type-tree parameter to indirect/reference caller parameter for indirect calls.

Then it seeds the worklist with params already observed as used in the IR.

Propagation rule:

- if a callee param is used,
- then any caller param forwarded into it becomes used too.

Because the analysis runs to a fixed point, cycles of forwarded params can be optimized away when nothing outside the cycle ever uses them.
That is one of the pass's signature wins.

## 11. The optimization pass removes params, arguments, and sometimes whole forwarded expression trees

The optimization walk updates each function by:

- renumbering kept params/locals,
- removing call operands corresponding to unused params,
- removing direct and indirect call operands when the analyzed usage says they are dead,
- and deleting forwarded expression trees rooted at now-dead parameter gets.

But the optimizer is conservative about structural repair.
It preserves control/effect structure and does not simply erase wrappers blindly.

The shipped regressions show why:

- loops must stay if their effects matter,
- `if` structure must survive when effect placement depends on it,
- and incorrectly marking a `call_ref` / `call_indirect` subtree removable can duplicate effects.

## 12. Referenced-function optimization requires a separate global type rewrite stage

If referenced-function optimization is enabled, `dae2` does more after local body rewrites:

1. rebuild function types through `DAETypeUpdater`,
2. compute old-to-new type mappings,
3. manufacture replacement types for unreferenced functions when needed,
4. optimize function bodies,
5. globally update referenced function types and all locations that may hold them.

This is the hardest conceptual difference from plain `dae`.
`dae2` is not only editing direct callsites.
It is sometimes editing the module's function-type graph.

## 13. Replacement types are the subtle “do not optimize the wrong sibling” mechanism

A major non-obvious problem arises when:

- a referenced function and an unreferenced function originally share a function type,
- only the unreferenced one should lose parameters,
- but a later global type rewrite would otherwise force them back together incorrectly.

Binaryen solves that by creating or reusing **replacement types** for the unreferenced functions before the global rewrite applies.

The shipped lit file contains several regressions around:

- public types,
- subtype trees,
- inhabited vs uninhabited signatures,
- self-recursive referenced types,
- and brand conflicts.

So this is a core part of the real contract, not an implementation footnote.

## 14. The current implementation deliberately leaves some precision on the table

The source and tests openly record current limits.
Important ones include:

- no unused-result optimization yet,
- no constant actual propagation,
- no type propagation through params/results yet,
- indirect calls are keyed only by root type tree, not by exact table identity,
- stack-switching instruction params are not analyzed yet,
- tuple extraction is treated conservatively as a use,
- `call.without.effects` remains a blocker,
- sharedness matching for freshly generated replacement types still has a TODO.

This is useful for the wiki because it prevents readers from over-generalizing the pass from its name.

## How `dae2` differs from plain `dae` and `dae-optimizing`

## Compared with plain `dae`

`dae2` adds:

- fixed-point forwarding-cycle reasoning,
- explicit `call_ref` / `call_indirect` participation through type trees,
- global type rewriting for referenced functions.

But `dae2` currently lacks several plain-DAE families:

- dropped-return elimination,
- result-type refinement,
- constant actual materialization,
- GC param/result LUB refinement,
- iterative localization rounds as the main strategy.

## Compared with `dae-optimizing`

`dae2` also does **not** include the nested `optimizeAfterInlining(...)` rerun contract.
So even when it removes params successfully, it is not the same end-to-end cleanup surface as `dae-optimizing`.

## Important positive rewrite families

## Trivial unused params in plain direct functions

The pass removes obviously unused params and the matching call operands.

## Recursive and mutually recursive forwarding cycles

A param used only to re-forward itself through a cycle can still disappear when nothing outside the cycle observes it.

## Caller-used / callee-unused split

A caller may still need its own param while a callee can drop the forwarded copy.

## Indirect/reference-call function-type-tree optimization

Under `--closed-world` + GC, the pass can remove dead params from referenced function types and from indirect/reference call operands, while preserving public/unrewritable type boundaries.

## Expression-tree removal around dead forwarded gets

Pure wrapper expressions around a dead forwarded get can disappear together with the dead argument, but effectful or control-sensitive wrappers are preserved.

## Important preserved / bailout families

## Branch conditions

If a param influences an `if` condition, it is used.

## Effectful parents

If removing a forwarded tree would cross unremovable side effects, the param is used.

## `call.without.effects`

These are still a blocker today.

## Public / continuation / tag-related referenced type trees

Those function-type roots are treated as unrewritable.

## Tuple extraction precision

`tuple.extract` currently counts conservatively as a use.

## Results

Returned values are still out of scope for optimization in `dae2` today.

## The most important beginner takeaway

If plain `dae` is best taught as:

- direct-call boundary mutation plus refinement/localization,

then `dae2` is best taught as:

- backward fixed-point liveness over forwarded params,
- plus optional function-type-tree rewriting for referenced functions.

That is a materially different design, even before considering that `dae2` is still experimental and openly incomplete.

## Open questions / future-followup hooks

- If the local wiki later needs another `dae`-family follow-up, the most obvious gap inside `dae2` itself is a source-confirmed focused page for replacement-type generation and the referenced-vs-unreferenced function-type split.
- If upstream later extends `dae2` to results, constants, or type propagation, this dossier should be updated explicitly rather than silently assuming parity with plain `dae`.

## Sources

- Binaryen `version_129` core sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination2.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
- Supporting sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-shape.h>
- Neighboring local context:
  - [`../0159-2026-04-21-dead-argument-elimination-binaryen-research.md`](../0159-2026-04-21-dead-argument-elimination-binaryen-research.md)
  - [`../../binaryen/passes/dead-argument-elimination/index.md`](../../binaryen/passes/dead-argument-elimination/index.md)
  - [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
  - [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md)
  - [`../../binaryen/no-dwarf-default-optimize-path.md`](../../binaryen/no-dwarf-default-optimize-path.md)
  - [`../../../../agent-todo.md`](../../../../agent-todo.md)
