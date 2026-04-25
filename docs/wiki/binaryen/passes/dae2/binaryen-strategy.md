---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/index.md
  - ../dae-optimizing/index.md
---

# Binaryen `dae2` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for `dae2`.
- The 2026-04-25 immutable manifest is [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md).
- The core implementation is `src/passes/DeadArgumentElimination2.cpp`.
- Public registration lives in `src/passes/pass.cpp`.
- The reviewed official test surface is `test/lit/passes/dae2.wast`.
- Important helper context comes from:
  - `src/ir/local-graph.h`
  - `src/ir/module-utils.h`
  - `src/ir/type-updating.h`
  - `src/ir/intrinsics.h`
  - `src/ir/effects.h`
  - `src/ir/eh-utils.h`
  - `src/wasm-type-shape.h`

## The pass in one sentence

Binaryen `dae2` is an **experimental dead-argument reimplementation** that computes a backward fixed point over direct and indirect parameter-forwarding edges, removes unused params and matching operands, and under `--closed-world` + GC can also rewrite referenced function types through global type-tree repair.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Analyze | Scan every function for truly-used params, forwarded params, param-reading gets, references, continuations, and intrinsic blockers | Build the forward graph and the initial used seeds |
| Prepare reverse graph | Reverse direct-call and root-type-tree forwarding edges | Make backward fixed-point propagation cheap |
| Fixed point | Propagate “used” backward from observed uses through caller-param edges | Remove cycles only when nothing outside them forces usage |
| Optimize bodies | Remove dead params, matching call operands, and removable forwarded expression trees | Produce the visible IR rewrite |
| Rewrite referenced types | When allowed, rebuild types and repair all reference-holding locations | Keep indirect/reference-call surfaces valid after signature changes |
| Install replacement types | Give unreferenced functions temporary alternative types when needed | Prevent global type rewriting from optimizing the wrong sibling functions |

## The biggest naming fact

`pass.cpp` registers three separate public `dae` family names relevant here:

- `dae`
- `dae-optimizing`
- `dae2`

That matters because `dae2` is **not** implemented by flipping a flag on the original DAE engine.
It is a separate file and a separate design.

So the correct teaching split is:

- `dae` / `dae-optimizing` = direct-call boundary mutation family,
- `dae2` = experimental fixed-point forwarding and type-tree family.

## Phase 1: the top comment tells you what is in scope and what is not

The `DeadArgumentElimination2.cpp` header comment says the pass currently does:

- smallest-fixed-point dead-arg analysis,
- one scan to collect call-graph and forwarding facts,
- one optimization traversal to remove params and arguments,
- one final global type update step for referenced functions when that mode is enabled.

It also says the pass does **not yet** do:

- unused result analysis,
- constant propagation through params/results,
- type propagation through params/results.

That is a core strategy fact, not a temporary footnote.
A future port should not assume parity with plain `dae` on those features.

## Phase 2: `FunctionInfo` shows the true analysis surface

Per function, the pass tracks:

- `paramUsages`
- `directForwardedParams`
- `indirectForwardedParams`
- `callerParams`
- `paramGets`
- `contTypes`
- `referenced`
- `usedInIntrinsic`
- `replacementType`

Those fields mean `dae2` is solving two problems at once:

1. whether a parameter is semantically required,
2. whether later function-type rewriting must distinguish referenced and unreferenced functions.

## Phase 3: forwarding is broader than raw local-get-as-argument matching

The walker treats a parameter as forwarded when its `local.get` is consumed by:

- a direct-call operand,
- a `call_ref` operand,
- a `call_indirect` operand,
- or a side-effect-free wrapper expression whose result is then forwarded to such a call.

So the pass is not limited to:

```wat
(call $f (local.get $x))
```

It can also recognize forwarding through pure intermediate expression trees.

## Phase 4: `LazyLocalGraph` separates true incoming-param use from later slot reuse

A parameter local index may be overwritten inside a function.
So a later `local.get` of that index does not necessarily mean the original incoming value is used.

`dae2` therefore relies on `LazyLocalGraph` to ask whether a get may still read from the incoming param.
That is why the pass can safely optimize recursive or forwarded shapes without confusing them with local slot reuse.

## Phase 5: some surfaces are always treated as real use or nonrewritable boundaries

Important conservative rules include:

- `if` conditions are always treated as uses;
- effectful parents stop forwarding-based removal;
- imports and exports are treated as references;
- `ref.func` marks a function as referenced;
- JS-called functions keep their params;
- `call.without.effects` users keep their params;
- continuation and tag-related function-type roots are not rewritten;
- public function types and private subtypes of public function types are not rewritten.

This is why `dae2` is safe even though it can erase surprisingly large forwarded subtrees in positive cases.

## Phase 6: the mode split is `closedWorld && GC`

The pass stores:

- `optimizeReferencedFuncs = getPassOptions().closedWorld && wasm->features.hasGC()`.

That switch is crucial.

### When false

Binaryen:

- optimizes only unreferenced functions directly,
- does not use indirect/reference-call function-type-tree optimization fully,
- and skips the later global type rewrite machinery.

### When true

Binaryen:

- tracks indirect forwarding by root function-type tree,
- may optimize referenced functions too,
- and later rewrites function types globally.

So this is not an incidental enhancement.
It changes the pass's entire reachable surface.

## Phase 7: referenced functions are grouped by root function-type tree

For indirect/reference calls, `dae2` does not track exact destination function identities.
Instead it groups by the **root declared supertype** of the callee heap type.

That means:

- a whole subtype tree must agree on which params are used or unused,
- referenced functions in the same tree can force each other's params to remain live,
- and the later rewrite logic works at the type-tree level, not just per function.

## Phase 8: the fixed point is over the reverse graph

After scanning, `prepareReverseGraph()` builds reverse caller-param edges.
Then `computeFixedPoint()` seeds the worklist with params already known to be used in the actual IR.

Propagation rule:

- if a callee param is used,
- then any caller param forwarded into it becomes used too.

This is what lets the pass remove pure forwarding cycles:

- if nothing outside the cycle seeds a real use,
- the cycle stays bottom / unused.

## Phase 9: optimization is not “just drop the operand”

The optimizer performs several coordinated edits:

- rebuild kept param lists,
- renumber locals,
- remove dead direct-call operands,
- remove dead `call_ref` / `call_indirect` operands when the type-tree analysis allows it,
- mark dead forwarded expression trees for removal,
- preserve control/effect structure around surviving expressions.

This means visible output can include repaired wrappers rather than a maximally flattened result.
That is still faithful Binaryen behavior.

## Phase 10: referenced-function optimization requires global type rewriting

When referenced-function mode is enabled, `dae2` cannot stop after body edits.
It also needs to:

- rebuild old-to-new types,
- keep public/unrewritable roots stable,
- rewrite referenced function types and all holders of those types,
- and distinguish unreferenced siblings that should not inherit the referenced rewrite result.

This is the most important place where `dae2` departs from plain `dae`.

## Phase 11: replacement types are the key non-obvious mechanism

If an unreferenced function shares a type with a referenced function, the later global rewrite could otherwise give it the wrong optimized type.
So `dae2` may assign that unreferenced function a `replacementType` first.

The implementation:

- tries to reuse public or already-rewritten types when possible,
- otherwise creates fresh unique rec groups as placeholders,
- and then installs those replacement types before the global rewrite finishes.

This is not optional polish.
The big `dae2.wast` file has dedicated regressions proving it matters for:

- public brands,
- self-recursive function types,
- inhabited vs uninhabited signatures,
- and subtype-tree conflicts.

## What is easy to misunderstand

## Misunderstanding 1: “`dae2` is just plain DAE but newer”

False.
It is a different algorithmic design, not a tiny refresh.

## Misunderstanding 2: “`dae2` is strictly stronger than `dae` today”

Not in every direction.
It is stronger on forwarding-cycle and referenced-type-tree reasoning, but weaker today on result removal, constant actuals, and type propagation.

## Misunderstanding 3: “Indirect calls are fully precise here”

No.
The source has an explicit TODO about making `call_indirect` more precise by considering the target table.

## Misunderstanding 4: “Closed world only matters for a few extra wins”

No.
It controls whether referenced-function optimization and the entire global type-rewrite half are available.

## Misunderstanding 5: “If a param disappears then every surrounding expression just disappears too”

No.
The pass carefully preserves effect and control structure, and many wrappers remain to keep semantics identical.

## What a future Starshine port must preserve

- Backward fixed-point usage propagation over reverse forwarding edges.
- The distinction between direct forwarding and root-type-tree forwarding.
- `LazyLocalGraph`-based incoming-value reasoning.
- Explicit blockers for `if` conditions, effectful parents, `call.without.effects`, JS-called functions, public roots, continuations, and tags.
- The `closedWorld && GC` mode split.
- The referenced-vs-unreferenced function-type handling and replacement-type mechanism.
- Structural effect-preserving expression removal rather than naive operand deletion.
- The fact that current `dae2` does **not** yet optimize results or propagate constants/types.

## Bottom line

Binaryen `dae2` is best taught as:

- backward liveness over parameter-forwarding graphs,
- plus optional function-type-tree rewriting,
- not as a small scheduling variant of plain `dae`.

## Sources

- Raw source manifest: [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- Source bridge: [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- Original research note: [`../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md`](../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md)
- Binaryen `DeadArgumentElimination2.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination2.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `dae2.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
