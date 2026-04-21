---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
---

# Binaryen `souperify` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass family.
The core sources are:

- `src/passes/Souperify.cpp`
- `src/passes/pass.cpp`
- `src/dataflow/graph.h`
- `src/dataflow/node.h`
- `src/dataflow/utils.h`
- `src/ir/flat.h`
- `src/ir/local-graph.h`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Souperify.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>

## The pass family in one sentence

Binaryen `souperify` is a flat-IR extraction pass that builds Binaryen's DataFlow IR plus local influence information, then prints bounded Souper-style traces for traceable integer computations; `souperify-single-use` is the same pass with multi-use child slices cut off to fresh variables.

## Biggest naming fact

The easiest mistake is to read `souperify` as if it meant:

- “run Souper optimizations on the function.”

That is not the real `version_129` contract.

A better reading is:

- “turn suitable parts of flat Binaryen IR into Souper-style text traces.”

So this family is closer to:

- extraction,
- instrumentation,
- or offline optimization input preparation,

than to an ordinary Binaryen optimizer.

## Public-pass fact

`pass.cpp` registers both public pass names:

- `souperify`
- `souperify-single-use`

So these are not hidden debug helpers.
They are real public upstream passes.

## Scheduler fact

For this repo, both are currently upstream-only:

- not in the local Starshine registry,
- not in the no-DWARF default optimize path,
- and not in the saved generated-artifact `-O4z` skipped-slot queue.

So this dossier is a justified upstream-only expansion rather than a missing preset-parity pass.

## Hard precondition: flat IR

The first concrete action in `doWalkFunction(...)` is:

- `Flat::verifyFlatness(func);`

That reviewed `flat.h` contract matters a lot.
By this point Binaryen requires:

- non-`local.set` instruction children must already be local gets, consts, `unreachable`, or nested `ref.as_non_null`,
- control flow must not return values,
- `local.tee` must already be gone,
- and even `local.set` values cannot themselves be control flow.

That means `souperify` is not flattening code on the fly.
It assumes the work was already done.

## Core state 1: DataFlow IR

The pass next builds a `DataFlow::Graph`.
That graph is Binaryen's small SSA-like side IR, not the main AST.

The reviewed node kinds are:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

The best beginner mapping is:

- `Expr` = a supported computation node based on a Binaryen expression,
- `Phi` = a merged local value,
- `Cond` + `Block` = control-path metadata for phis and path conditions,
- `Zext` = repair from Souper-style `i1` comparison results back to wasm integer widths,
- `Var` = unknown boundary value,
- `Bad` = unsupported / unusable node.

## Core state 2: `LocalGraph`

After the DataFlow graph, the pass builds a `LocalGraph` and calls:

- `computeInfluences()`

That data powers use discovery.
The key helper is `UseFinder`, which starts from a set value and walks:

- influenced gets,
- copy-only set chains,
- and non-set uses such as returns or call arguments.

That is how the pass distinguishes:

- internal uses that belong to the same trace,
- from outside uses that should become `hasExternalUses` annotations,
- and from multi-use child nodes that `souperify-single-use` must truncate.

## Trace roots are narrow

Not every DataFlow node becomes a root.
`Trace::isTraceable(...)` accepts only nodes with real wasm origins whose expression is one of:

- supported unary integer ops,
- supported binary integer ops,
- `select`.

So the pass is intentionally **not** a generic whole-function Souper exporter.
It focuses on a small useful integer subset.

## Trace growth is bounded and lossy on purpose

`DataFlow::Trace` keeps two main limits:

- `depthLimit = 10`
- `totalLimit = 30`

and supports env-var overrides:

- `BINARYEN_SOUPERIFY_DEPTH_LIMIT`
- `BINARYEN_SOUPERIFY_TOTAL_LIMIT`

When a slice gets too deep, too large, or hits an excluded child node, Binaryen replaces that subtree with a fresh `Var` of the same wasm type.

This is a major strategy fact.
The pass is not trying to preserve entire exact dependency trees at all costs.
It wants bounded, practical traces.

## Trivial traces are discarded

The constructor for `Trace` rejects slices that are too trivial, including:

- no work nodes,
- or just one `Var` before path conditions are added.

So the pass is opinionated about signal-to-noise.
It does not print every technically possible root.

## Loop policy is intentionally conservative

The reviewed `dataflow/graph.h` loop handling is explicit:

- Binaryen avoids loop phis here.

It temporarily replaces loop-entry locals with `Var`s and only restores the old proper value when no real phi would be necessary.
Otherwise, the `Var` stays and the trace stops there.

So `souperify` is deliberately conservative around loop-carried values.
That is part of the real algorithm, not a missing feature in the docs.

## Path conditions are real, but only from `if`

The file header TODOs explicitly say Binaryen still lacks:

- pcs and blockpcs for things other than `if`s.

The reviewed `addPathTo(...)` logic only handles `If` parents.
So a correct summary is:

- `souperify` can emit `pc` and `blockpc`,
- but its path-condition surface is currently `if`-only.

## Single-use mode is child truncation, not root filtering

This is the easiest sibling detail to misread.

`Souperify(true)` computes a set of nodes to exclude as **children** when they have more than one use.
Later, the trace builder may still choose such a node as a root, but it cannot expand it as a dependency of a larger trace.
Instead it becomes a fresh `Var`.

So `souperify-single-use` does **not** mean:

- “print only nodes with one use.”

It means:

- “when a child dependency is reused, summarize it as an unknown input instead of embedding the larger reused subtree.”

## Printed opcode surface is intentionally tiny

The printer only maps a narrow set of operations.
In the reviewed `version_129` source that includes:

### Unary

- `ctlz`
- `cttz`
- `ctpop`

### Binary

- `add`, `sub`, `mul`
- `sdiv`, `udiv`
- `srem`, `urem`
- `and`, `or`, `xor`
- `shl`, `lshr`, `ashr`, `rotl`, `rotr`
- `eq`, `ne`
- `slt`, `ult`, `sle`, `ule`

### Other emitted forms

- `select`
- `block`
- `phi`
- `blockpc`
- `pc`
- `zext`
- `var`

That narrow printer surface is why this pass should not be taught as a broad wasm-to-Souper exporter.

## Output fact

`doWalkFunction(...)` prints function headers and trace blocks to standard output.
It does not rewrite the function body into an optimized new AST.

So the family is best understood as:

- output-producing instrumentation.

## Important pass interactions

## 1. With `flatten`

`flatten` is a prerequisite, not a sibling mode.
Without flat IR, `souperify` refuses to run.

## 2. With `simplify-locals-nonesting`

The `Souperify.cpp` header explicitly recommends running some locals cleanup first because flattening can introduce many copies.
So the relationship is:

- `simplify-locals-nonesting` is useful preparation,
- `souperify` is the later extractor.

## 3. With `dataflow-optimization`

Both use Binaryen's DataFlow IR, but for different purposes.
`dfo` optimizes code.
`souperify` prints traces.

This split is important because the name `DataFlow IR` can otherwise make the two folders sound interchangeable.

## 4. With loop-heavy code

Because loop-carried values are summarized conservatively with `Var`s instead of full loop phis, `souperify` is much stronger on:

- straight-line,
- branch-merged,
- and lightly structured flat code

than on genuinely iterative dataflow.

## What a future Starshine port would need to preserve

A faithful port would need to preserve at least these boundaries:

1. hard flatness verification,
2. DataFlow-IR construction instead of direct AST emission,
3. `LocalGraph`-powered use tracking,
4. bounded trace extraction with `Var` replacement,
5. narrow printed opcode coverage,
6. `if`-only path-condition generation,
7. loop-phi avoidance,
8. single-use child truncation rather than root filtering.

## Current-main drift check

I compared current upstream `main` against `version_129` for the reviewed core file and the two official lit tests.
On those surfaces:

- the tests are unchanged,
- and the implementation only differs by a typo fix in one unreachable diagnostic string.

So the documented contract here does not sit on a known semantic drift.

## Most important beginner correction

If someone says:

- “`souperify` is the Souper optimization pass”

that points in the wrong direction.

A much better sentence is:

- “`souperify` is Binaryen's flat-IR DataFlow trace emitter for Souper-style reasoning.”
