---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
related:
  - ./implementation-structure-and-tests.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./wat-shapes.md
  - ../flatten/binaryen-strategy.md
---

# Binaryen strategy for `dataflow-optimization` / `dfo`

## One-sentence summary

Binaryen `dfo` is a small function-parallel pass that requires already-flat code, builds a narrow SSA-like DataFlow graph over mainly integer local traffic, and then performs two tiny graph-driven simplifications: identical constant-phi collapse and constant-input expression folding through nested `precompute`.

## Why this needs its own page

The pass name is much broader than the actual implementation.
If a future port starts from the name instead of the source, it is easy to overbuild the wrong thing.

The real strategy has four layers:

1. require **Flat IR** first
2. build a separate **DataFlow SSA IR** side graph
3. run a tiny **user-driven worklist** over that graph
4. write simplified constant results back into the flattened wasm

## Phase 1: require flat input

`DataFlowOpts::doWalkFunction` begins by calling:

- `Flat::verifyFlatness(func)`

That is not an optional optimization hint.
It is a correctness boundary.

The pass expects flatten-era invariants such as:

- explicit local traffic instead of deep nested value trees
- branch payloads already routed through locals
- easy child replacement points inside the remaining wasm expressions

This is why the file comment itself recommends using the pass like:

- `--flatten --dfo -Os`

and then running regular cleanup afterwards.

## Phase 2: build DataFlow IR

After flatness verification, the pass builds a separate graph:

- `graph.build(func, getModule())`

This is where most of the real semantics live.

## What the DataFlow IR keeps

From the helper headers, the graph uses synthetic nodes such as:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

Important teaching consequences:

- `Expr` reuses Binaryen expressions when possible
- `Phi` / `Cond` / `Block` are graph-only helpers
- unsupported cases do not always fail the pass; many are summarized as unknown values

## Relevant-type filter: mostly integer-only

`graph.h`'s helper says:

- `isRelevantType(type) { return type.isInteger(); }`

and relevant locals are defined in terms of that filter.

That means the reviewed `version_129` pass is not a broad GC/f32/f64 optimizer.
It focuses on flattened integer-value traffic.

This one detail changes how a future port should be scoped.

## Initial local state

During graph construction:

- relevant params begin as `Var`
- relevant non-param locals begin as zero nodes

So the graph begins with a simple SSA-ish abstract state rather than trying to preserve original stack semantics directly.

## Phase 3: model control flow conservatively

## Blocks

Named block exits are collected in `breakStates` and merged later.
Unnamed blocks mainly sequence children.

## Ifs

`doVisitIf`:

- visits the condition
- records true and false branch states
- synthesizes condition nodes when possible
- merges local states with `mergeIf(...)`

The merged state can create phi nodes when different branch-local values meet.

## Breaks and switch

- `br` records outgoing locals to the target block and may make the current path unreachable
- `switch` records outgoing locals for each possible target and then makes the current path unreachable

So structured branch traffic is modeled through state merging rather than by mutating the source wasm directly.

## Loops: deliberate precision cutoff

This is the most important non-obvious part of the builder.

The loop code explicitly says it avoids ordinary loop phis because it does not want traces that depend on values changing across loop iterations.
Instead it:

- replaces loop-entry relevant locals with fresh `Var`s
- analyzes the loop body
- checks later whether any local really required a loop phi
- keeps the unknown var if the value really varies across iterations
- restores the original known value only when no true loop-varying merge was needed

So the pass is conservative by design around loops.
A future port that tries to be more precise here would no longer be implementing the same contract.

## Phase 4: represent only a narrow opcode subset precisely

## Supported unary families

Reviewed `doVisitUnary` handles:

- `clz`
- `ctz`
- `popcnt`
- `eqz` (via a zero-comparison helper)

## Supported binary families

Reviewed `doVisitBinary` handles integer families such as:

- add / sub / mul
- signed and unsigned div / rem
- and / or / xor
- shifts and rotates
- eq / ne / lt / le directly
- gt / ge by flipping them to the opposite comparison with swapped operands

That last part is easy to miss.
`dfo` normalizes some comparisons to the smaller relation vocabulary expected by the graph/Souper-oriented design.

## Supported select

`select` is modeled precisely when:

- both arm values are representable
- the condition can be turned into the graph's boolean form

## Generic fallback

Anything outside the precise supported set is usually visited recursively and then summarized as:

- `makeVar(curr->type)`

So many instructions are observed for local-flow purposes without becoming first-class optimization targets.

## Explicit unsupported families

The builder contains an explicit fatal boundary for EH instructions like:

- `try`
- `throw`
- `rethrow`

That is an actual source-level boundary, not just an untested surface.

## Phase 5: build the user graph

After graph construction, `DataFlow::Users` computes which nodes use which other nodes.

That structure provides:

- `getUsers(node)`
- `getNumUses(node)`
- `stopUsingValues(node)`
- `addUser(node, newUser)`

This is what makes the later worklist and cascading rewrites possible.

## Phase 6: run a tiny worklist

The pass inserts every graph node into `workLeft`, then repeatedly pops a node and calls `workOn(node)`.

Important early filters in `workOn`:

- constant nodes are skipped
- nodes with zero uses are skipped

That is the pass's first profitability rule.
It only spends effort where graph facts might matter to a live user.

## Actual optimization family 1: identical-input phi collapse

The first real optimization checks:

- node is a phi
- `DataFlow::allInputsIdentical(node)`

If so, it grabs one incoming value and, if that value is a constant node, replaces all uses of the phi with that constant.

Important nuance:

- the replacement helper asserts the replacement target is constant today

So the practical `version_129` contract is narrower than generic phi simplification.
It is really:

- identical incoming values
- where the replacement target is constant

## Actual optimization family 2: all-constant expression folding

The second real optimization checks:

- node is an `Expr`
- `allInputsConstant(node)`
- expression type is concrete

Then it calls `optimizeExprToConstant(node)`.

### How constant folding actually happens

The implementation does **not** contain a giant custom evaluator.
Instead it:

1. rewrites constant DataFlow inputs back into the Binaryen expression children
2. creates a temporary module and function containing that expression
3. runs nested Binaryen `precompute`
4. accepts the result only if the temp function body becomes a `Const`
5. rewrites the graph node into a constant node
6. updates users so the simplification can cascade

This is one of the most important facts in the whole dossier.

The pass is best understood as:

- graph-side constant discovery
- tree-side constant execution delegated to `precompute`

## Why some all-constant nodes still stay unchanged

If nested `precompute` does not reduce the temp body to a `Const`, `dfo` leaves the node unchanged.

The source comment explicitly mentions cases like division-by-zero not folding into a harmless constant.
So the pass inherits `precompute`'s real trap-aware semantics rather than inventing a looser rule.

## Replacement propagation

`replaceAllUsesWith(node, with)` updates both:

- the graph edge structure
- the child pointers in underlying Binaryen expressions

It also re-adds all affected users to `workLeft`.
That is how one constantization can trigger more constantizations later in the same function.

## What the pass does not do

The reviewed implementation does **not** do any of these broad things:

- generic whole-program dataflow
- rich non-integer value reasoning
- aggressive loop invariant analysis
- full symbolic simplification beyond the narrow constant-driven rules
- late cleanup of the flattened code shape it leaves behind

Those non-goals are as important as the positive rules.

## Pipeline interactions

## Required predecessor: `flatten`

This is mandatory, not advisory.

## Typical neighbors: `simplify-locals-nonesting` and later cleanup

The checked combo lit file proves an aggressive real-world usage shape:

- `--flatten --simplify-locals-nonesting --dfo -O3`

That teaches two things:

- `dfo` belongs in a flatten-era aggressive pipeline neighborhood
- later ordinary optimization is expected to clean up whatever flattened form remains

## Internal dependency on `precompute`

Even though `precompute` is not a required external scheduler predecessor, it is a required **nested helper dependency** because `dfo` uses it to validate actual constant folds.

## Relationship to Souper-oriented DataFlow IR

The helper headers say the DataFlow IR was designed first for a use case that could convert easily to Souper IR.
That explains several otherwise surprising choices:

- narrow supported opcode vocabulary
- explicit phi/cond/block helper nodes
- comparison normalization
- conservative loop handling

## Important positive shapes

- flat integer local traffic through supported unary/binary/select nodes
- if-merge states where both incoming values are the same constant
- arithmetic chains where earlier constant rewrites make later nodes fully constant too
- aggressive flattened pipelines that will perform ordinary cleanup afterwards

## Important negative and bailout shapes

- non-flat input
- EH instructions
- unsupported opcodes that degrade to `Var`
- non-integer local/value traffic outside the relevant set
- genuinely loop-varying values that become unknown loop-entry vars
- all-constant graphs whose nested `precompute` result is still not a constant

## Easy misunderstandings to correct

### Misunderstanding 1: "This is Binaryen's generic dataflow optimizer"

No.
In `version_129` it is a small flat-integer side-graph simplifier.

### Misunderstanding 2: "The pass itself knows how to evaluate everything"

No.
It delegates real constant evaluation to nested `precompute`.

### Misunderstanding 3: "Loops get ordinary SSA phis"

No.
The implementation intentionally avoids that precision in loops.

### Misunderstanding 4: "It is safe to run whenever later in the pipeline"

Not without recreating flatness and the same assumptions.
The pass explicitly requires Flat IR.

## What a future Starshine port must preserve

- flatness as a real precondition
- function-parallel scope
- integer-local relevance filter
- the side-IR node model and conservative unsupported-value model
- deliberate loop precision cutoff
- identical-constant-phi collapse rule
- nested-`precompute`-driven constant expression folding
- user-driven cascading rewrite worklist
- expectation of later ordinary cleanup passes after the flatten-era run

## Sources

- [`../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md`](../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
