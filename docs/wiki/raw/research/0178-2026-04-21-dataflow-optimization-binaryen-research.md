# Binaryen `dataflow-optimization` / `dfo` research

Date: 2026-04-21
Author: Codex recursive wiki campaign thread
Status: source-backed upstream-only dossier input

## Scope and candidate selection

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

The original no-DWARF / saved-`-O4z` queue is already dossier-covered.
The first expanded upstream-only queue is dossier-covered too.
So this thread needed to justify a **new** eligible tracker expansion rather than picking an old `none` entry.

I chose the local removed-registry pass name **`dataflow-optimization`**, whose official upstream public pass name is **`dfo`**.
That expansion is justified because:

- it is still explicitly named in `src/passes/optimize.mbt`
- it is a real public Binaryen pass registered in upstream `pass.cpp`
- it has a real `version_129` implementation file (`DataFlowOpts.cpp`)
- it sits directly beside already-documented neighbors `flatten` and `simplify-locals*`
- its real contract is easy to misunderstand from the name alone
- `agent-todo.md` currently has **no dedicated slice** for `dataflow-optimization` / `dfo`

## Main source set reviewed

### Core implementation

- Binaryen `version_129` `src/passes/DataFlowOpts.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`

### Helper and analysis surfaces

- Binaryen `version_129` `src/dataflow/graph.h`
- Binaryen `version_129` `src/dataflow/node.h`
- Binaryen `version_129` `src/dataflow/users.h`
- Binaryen `version_129` `src/dataflow/utils.h`
- Binaryen `version_129` `src/ir/flat.h`

### Representative shipped test surface

- Binaryen `version_129` `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`

That combo lit file is important even though it is not a pure isolated `dfo.wast` file, because it proves the pass is used in a real aggressive pipeline context:

- `--flatten --simplify-locals-nonesting --dfo -O3`

## Freshness check

I also did a narrow current-`main` check.

Durable result:

- current `main` `DataFlowOpts.cpp` differs from `version_129` only by a typo fix in a comment (`constanat` -> `constant`)
- the checked combo lit file `flatten_simplify-locals-nonesting_dfo_O3.wast` is identical between `version_129` and current `main`

So the `version_129` release file is a safe oracle for the behavior documented here.

## High-level conclusion

Binaryen `dfo` is **not** a broad generic dataflow optimizer.
It is a **small function-parallel pass** that:

1. requires already-**flat** code
2. builds a separate **DataFlow SSA IR** for relevant integer locals and expressions
3. tracks node users inside that IR
4. performs a tiny fixed-point worklist over those nodes
5. only does two real optimization families in `version_129`:
   - replace a phi whose incoming values are all the same constant-equivalent node
   - precompute an expression when all of its DataFlow inputs are constant and the expression type is concrete
6. writes the simplified constantized results back into the flattened wasm IR
7. expects ordinary cleanup passes afterwards

The official file itself says the intended usage is:

- `--flatten --dfo -Os`

and explicitly says full regular opts should run after flattening.

## Why the pass exists

The helper headers say DataFlow IR is an SSA representation whose first use case was an IR that could easily convert to **Souper IR**.
That matters for teaching the pass correctly.

The pass is not trying to be Binaryen's main optimizer.
It is a narrow SSA-like side IR for flattened integer computation, especially for optimization styles that want a more direct dataflow graph than ordinary Binaryen tree IR.

A good beginner summary is:

- `flatten` makes the code easy to reason about as straight-line local traffic
- `dfo` builds a small SSA-ish graph over that flattened code
- `dfo` performs a tiny amount of graph-local constant reasoning
- later passes clean up the now-flattened and simplified code shape

## Exact implementation structure

## 1. Pass registration and surface

Upstream `pass.cpp` registers the public pass name:

- `dfo`

with the description:

- `optimizes using the DataFlow SSA IR`

Local Starshine registry currently exposes the removed-name spelling:

- `dataflow-optimization`

That naming split is worth preserving explicitly in the living wiki.

## 2. Hard flatness precondition

`DataFlowOpts::doWalkFunction` begins with:

- `Flat::verifyFlatness(func)`

So this pass is not merely helped by flat input.
It **requires** the function to satisfy Binaryen Flat IR rules.

This is one of the most important porting facts.
A future Starshine port must either:

- run only after a true flatten step with the same guarantees, or
- re-create the same invariants inside another IR layer first.

## 3. Build DataFlow IR from wasm IR

`graph.build(func, getModule())` creates the alternate SSA-ish graph.

The reviewed helper code shows these important facts:

- only **integer** types are relevant (`isRelevantType(type) { return type.isInteger(); }`)
- only locals of relevant integer type participate
- parameters start as `Var` nodes
- non-parameter relevant locals start as zero nodes
- unsupported instructions usually degrade to `Var` or `Bad`, rather than causing the pass to optimize them directly

So `dfo` in `version_129` is narrower than its name suggests.
It is an integer-centered flattened-local pass, not a broad all-type optimizer.

## 4. Node vocabulary in DataFlow IR

From `node.h`, the core node kinds are:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

Important teaching consequences:

- `Expr` nodes reuse ordinary Binaryen expressions where possible
- `Phi` and `Cond` are synthetic graph-only nodes
- comparisons conceptually return `i1` in this IR, with helpers to expand them back out when needed
- `Bad` means unsupported or unusable for the current reasoning path

This is not a full replacement IR for wasm.
It is a selective side graph.

## 5. Control-flow modeling

`graph.h` shows how the builder models structured control flow.

### Blocks

Named block exits are collected in `breakStates` and merged afterwards.
Unnamed blocks just sequence their children.

### Ifs

`doVisitIf`:

- visits the condition
- visits true and false arms from copied local states
- merges outgoing local states with `mergeIf(...)`
- creates branch conditions when possible

### Loops

The loop contract is subtle and very important.
The code explicitly says it avoids ordinary loop phis because it does not want traces to represent values that differ across loop iterations.
Instead it:

- resets locals at loop entry to fresh `Var` nodes
- analyzes the loop body
- checks whether a real phi was actually needed for each local
- keeps the unknown `Var` if the loop really mixes values across iterations
- restores the original fixed value only when no true loop-varying merge is needed

So loops are a **deliberate precision cutoff**.
That is a core non-obvious boundary.

### Breaks and switch

- unconditional `br` records outgoing local state and makes the current path unreachable
- conditional `br_if` still visits its condition
- `switch` records outgoing local state to all reachable targets, then ends the current path

## 6. Supported expression surface

The builder supports only a narrow opcode family precisely.

### Unary ops supported precisely

Reviewed `doVisitUnary` supports:

- `clz`
- `ctz`
- `popcnt`
- `eqz` (lowered internally via zero-comparison helper)

Other unary ops degrade to unknown `Var` values.

### Binary ops supported precisely

Reviewed `doVisitBinary` supports integer arithmetic and bitwise families such as:

- add / sub / mul
- signed and unsigned div / rem
- and / or / xor
- shifts and rotates
- eq / ne / lt / le directly
- gt / ge by flipping to the opposite relation with swapped operands

Unsupported binary operations become `Var`.

### Select

`select` is modeled when:

- both arm values are representable
- the condition can be turned into the IR's boolean form

### Generic instructions

For all other expressions, `doVisitGeneric` simply visits children so local traffic is still observed, then returns `makeVar(curr->type)`.

That means many instructions are traversed but not optimized directly.

## 7. Explicit unsupported or limited families

The builder contains an explicit hard stop for EH:

- `Try`
- `Throw`
- `Rethrow`

The source says:

- `DataFlow does not support EH instructions yet`

Other important limits:

- the pass is flat-IR-only
- non-integer value types are mostly irrelevant to the graph
- unsupported instructions become unknown values
- loop-varying precision is intentionally cut off with `Var`

So this is not a pass a future port should casually generalize.

## 8. User graph construction

After graph build, the pass constructs `DataFlow::Users`.

`users.h` shows that this tracks:

- which nodes use each node
- how many total use positions there are
- how to stop using prior values when a node is rewritten

This powers the worklist and later replacement propagation.

## 9. Optimization loop

After building the graph and user map, `DataFlowOpts` inserts every node into `workLeft` and repeatedly calls `workOn(node)` until the work set is empty.

This is a small graph worklist, not a pass-pipeline scheduler.

### Early bailouts inside `workOn`

`workOn` immediately returns when:

- the node is already a constant
- the node has zero uses

That is an important profitability / simplicity boundary.
The pass does not bother optimizing dead graph nodes.

## Real rewrite family 1: identical-input phi collapse

If a node is a phi and `DataFlow::allInputsIdentical(node)` returns true, then:

- the pass grabs one incoming value
- if that incoming value is constant, it replaces all uses of the phi with that constant

So the phi rewrite is narrower than “all identical means collapse.”
In the reviewed implementation, the replacement helper asserts the replacement target is a **constant**.

That means the practical rewrite surface today is:

- identical-input phi -> constant replacement

not a generic arbitrary-node phi elimination engine.

## Real rewrite family 2: all-constant expression precompute

If a node is an `Expr` and `allInputsConstant(node)` is true, then the pass checks:

- `node->expr->type.isConcrete()`

and only then tries to constant-fold it.

The actual fold strategy is interesting:

1. rewrite any constant DataFlow inputs back into the Binaryen expression children
2. create a temporary one-function module containing that expression
3. run nested Binaryen `precompute` on the temp function
4. accept the result only if the temp function body became a `Const`
5. rewrite the DataFlow node itself into a constant node
6. update users

So `dfo` does **not** embed a giant bespoke evaluator.
It reuses Binaryen's existing `precompute` pass as the actual constant folder.

That is a major teaching point.

## Why some all-constant expressions still do not change

The source explicitly notes an example like:

- `0 / 0`

may not optimize to a constant.

The nested `precompute` must actually return a `Const` result.
If it does not, `dfo` leaves the node alone.

So the pass preserves trap-sensitive or otherwise non-folded cases by delegating to `precompute`'s real semantics rather than inventing a looser rule.

## Replacement mechanics

`replaceAllUsesWith(node, with)` updates both:

- the DataFlow graph users
- the underlying flattened wasm expression children

Important explicit constraints from the reviewed code:

- replacement target is asserted to be a constant today
- all users are re-added to `workLeft`
- child pointers in Binaryen expressions are updated through `getIndexPointer(...)`

This is why successful constantization can cascade.
Once one node becomes constant, its users go back on the worklist and may then qualify for the all-constant-expression rule.

## Important positive shapes

The real positive shapes are narrower than the pass name suggests.

### Positive shape A: flat integer local SSA-like traffic

Typical input after `flatten`:

- integer locals carry intermediate values
- structured merges create phi-like situations
- operations are in the supported unary/binary/select subset

### Positive shape B: identical constant merge

If both branches feed the same constant to a later merged local, the synthetic phi can collapse to that constant.

### Positive shape C: constantized arithmetic chain

If earlier replacements make all inputs to a supported arithmetic node constant, `dfo` can route that expression through nested `precompute` and replace it with one constant.

### Positive shape D: combo-pipeline wins after flatten and before later cleanup

The combo lit file shows that `dfo` is meant to participate in an aggressive sequence with:

- `flatten`
- `simplify-locals-nonesting`
- `dfo`
- later `-O3`

That fits the source comment in `DataFlowOpts.cpp`: use it after flattening and before ordinary cleanup.

## Important negative and bailout shapes

### Flatness failure

If the function is not flat, `Flat::verifyFlatness(func)` makes that a hard precondition violation.

### EH

Exception-handling instructions are explicitly unsupported.

### Non-integer focus

Only integer-typed locals are relevant.
This is not a general ref/f32/f64/tuple optimizer.

### Unsupported opcode families

Many instructions are only traversed generically and degrade to `Var`, which cuts off precision.

### Loop-varying values

Real loop-carried variation is intentionally summarized as unknown `Var` values instead of rich loop phis.

### Non-concrete result types

Even if all inputs are constant, the node must have a concrete type before the pass tries nested `precompute`.

### Nested precompute refusal

If nested `precompute` does not actually turn the temp body into a constant, `dfo` does nothing.

## What the pass sounds like vs what it really is

### What the name suggests

A beginner may hear `dataflow-optimization` and imagine:

- full reaching-constants analysis
- broad copy propagation
- generic global dataflow
- a major optimizer pass family

### What `version_129` actually does

The reviewed source shows something much smaller:

- a side SSA-like graph over **flat integer local traffic**
- a user-tracked worklist
- **identical constant phi collapse**
- **all-inputs-constant expression folding via nested `precompute`**
- lots of unsupported or summarized cases

That mismatch between name and real scope is exactly why the pass deserved a dedicated dossier.

## Pipeline interactions

## Required predecessor: `flatten`

This is the most important pipeline interaction.
Without real flattening, the pass is not valid.

## Typical neighbors: `simplify-locals-nonesting` and later cleanup

The combo lit file proves `dfo` is used with:

- `flatten`
- `simplify-locals-nonesting`
- `dfo`
- ordinary optimizing cleanup (`-O3` in the test)

That means a future port should think of `dfo` as part of an **aggressive flattened locals micro-pipeline**, not as a standalone substitute for later cleanups.

## Nested dependency on `precompute`

`dfo` internally reuses `precompute` to do actual constant evaluation.
So one can think of it as:

- graph-side constant discovery
n- tree-side constant execution through nested `precompute`

## Relation to Souper-oriented DataFlow IR

The helper headers repeatedly note the DataFlow IR's origin as something easy to convert to Souper IR.
That helps explain why the pass accepts a narrower supported subset and prefers explicit SSA-ish nodes, blocks, conds, and phis instead of trying to represent everything.

## What a future Starshine port must preserve

- the explicit local-name split: local registry `dataflow-optimization` vs upstream public `dfo`
- the hard flatness precondition
- the fact that this is a **function-parallel** pass
- the integer-local relevance filter
- the synthetic side IR with `Var` / `Expr` / `Phi` / `Cond` / `Block` / `Zext` / `Bad`
- the deliberate loop-precision cutoff using fresh loop-entry vars
- the narrow actual rewrite families
- nested `precompute` as the real constant evaluator
- the need for later ordinary cleanup after running on flat code
- the explicit EH unsupported boundary

## Easy misunderstandings to prevent

1. **It is not generic dataflow optimization.**
   In `version_129` it is a small flat integer SSA-side-IR pass.

2. **It is not a replacement for `flatten`.**
   It requires flat input.

3. **It does not own a giant evaluator.**
   It delegates constant execution to nested `precompute`.

4. **It is not rich loop optimization.**
   It intentionally gives up precision on real loop-varying values.

5. **It is not obviously safe to run late on ordinary structured IR.**
   The official file itself tells you to run flatten first and regular opts later.

## Suggested living wiki pages distilled from this note

- landing page
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `flat-ir-dataflow-ir-and-boundaries.md`
- `wat-shapes.md`

## Sources

- `src/passes/optimize.mbt`
- `agent-todo.md`
- Binaryen `version_129` official sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
- current-main spot checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DataFlowOpts.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
