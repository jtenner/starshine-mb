# Binaryen `souperify` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: official Binaryen `version_129` `souperify` / `souperify-single-use`, why the tracker expansion is justified, how the pass is really implemented, what shapes it emits, and how it relates to the existing `flatten`, `simplify-locals-nonesting`, and `dataflow-optimization` dossiers.

## Why this note exists

The pass tracker no longer has an obvious remaining `none` target.
So this note is an explicit tracker expansion.

I chose `souperify` because:

- it is **not** on this thread's exclusion list,
- it is a real public upstream Binaryen pass name in `version_129`, with a public sibling `souperify-single-use`,
- the local wiki already mentions it repeatedly in the neighboring `flatten`, `simplify-locals-nonesting`, and `dataflow-optimization` / `dfo` docs,
- but the tracker and pass folder map did **not** yet give it a canonical folder of its own.

`agent-todo.md` currently has **no dedicated `souperify` slice**.
That is expected: this is upstream-only research and not a current Starshine implementation task.

## Main conclusion

Binaryen `version_129` `souperify` is **not** a normal optimization pass.
It is a flat-IR-only extraction / instrumentation pass that walks a function, builds Binaryen's small DataFlow IR plus a `LocalGraph`, then prints Souper-style left-hand-side traces for traceable integer computations.

A better beginner summary is:

- require flat wasm-like Binaryen IR first,
- build a side DataFlow graph over locals and control merges,
- pick a unary / binary / `select` expression to infer,
- pull in a bounded backwards slice of data dependencies,
- optionally add `if`-based path conditions,
- and print the result as Souper text.

The public sibling `souperify-single-use` uses the same engine, but it truncates child traces at nodes with more than one downstream use by replacing those subtrees with fresh `var`s.

## Why `souperify` matters next to nearby dossiers

The neighboring docs already teach:

- `flatten` as the hard flat-IR precondition,
- `simplify-locals-nonesting` as a good cleanup step before extraction,
- and `dataflow-optimization` / `dfo` as another consumer of Binaryen's DataFlow IR.

Without a dedicated `souperify` dossier, those pages can only point at it as a vague later pipeline neighbor.
That makes it easy to confuse:

- DataFlow IR as an internal optimization engine,
- with `souperify` as the pass that actually emits Souper-style text.

## Official sources reviewed

### Core implementation and registration

- `src/passes/Souperify.cpp`
- `src/passes/pass.cpp`

### Supporting helper surface

- `src/dataflow/graph.h`
- `src/dataflow/node.h`
- `src/dataflow/utils.h`
- `src/ir/flat.h`
- `src/ir/local-graph.h`

### Official tests

- `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

### Current-main freshness spot check

I also compared current upstream `main` against `version_129` for:

- `src/passes/Souperify.cpp`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

Result:

- the two lit files are unchanged on the reviewed surfaces,
- and `Souperify.cpp` only differs by a typo fix in one unreachable-string literal (`"unexecpted"` -> `"unexpected"`).

So the documented contract below is stable on the reviewed surfaces.

## Public-pass identity

`pass.cpp` registers both public pass names:

- `souperify`
- `souperify-single-use`

So this is not an internal debug helper hidden from users.
It is a real public upstream extraction pass family.

For this repo it is currently **upstream-only**:

- it is not in the local Starshine pass registry,
- it is not in the canonical no-DWARF `-O` / `-Os` path,
- and it does not appear in the saved generated-artifact `-O4z` skipped-slot queue.

## What the implementation actually does

## 1. It hard-requires flat IR

`Souperify.cpp` calls `Flat::verifyFlatness(func)` before doing anything else.
The reviewed `flat.h` contract means:

- child operands must already be locals / consts / `unreachable` / nested `ref.as_non_null`,
- control flow must not carry concrete values,
- `local.tee` must already be gone,
- and `local.set` values must not themselves be control flow.

So `souperify` is not a pass that prepares its own input shape.
It assumes `flatten` already ran, and upstream comments explicitly recommend a cleanup prefix such as:

- `flatten`
- `simplify-locals-nonesting`
- `reorder-locals`

## 2. It builds Binaryen DataFlow IR, not Souper IR directly from AST nesting

The pass first builds a `DataFlow::Graph`.
That graph is Binaryen's small SSA-like side IR, not the main AST.

The reviewed `dataflow/node.h` surface has these node kinds:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

Important meanings:

- `Expr` reuses a Binaryen expression opcode and immediate data,
- `Phi` models joined local values,
- `Cond` models a block-path condition (`blockpc`),
- `Block` is the common source object for phis and path-condition branches,
- `Zext` repairs Souper's `i1` comparison results back to wasm-width integer uses,
- `Var` means “unknown value; stop expanding here”,
- `Bad` means “unsupported / unusable for extraction”.

That is the most important structural teaching point:

- `souperify` is a **DataFlow-IR printer**, not a direct AST pretty-printer.

## 3. The graph builder is deliberately conservative around loops and unsupported values

The reviewed `dataflow/graph.h` code explicitly avoids loop phis.
At loop entry it replaces relevant locals with fresh `Var`s, analyzes the loop body, and only restores the old value when no real phi would have been necessary.

Beginner summary:

- if loop-carried flow would require a true loop phi,
- Binaryen does **not** encode that in a Souper trace here,
- it cuts the trace off with unknown variables instead.

This matches the upstream comment that the pass follows Souper's LLVM extractor in avoiding loop phis.

## 4. `LocalGraph` is used for real use-count / influence reasoning

After building the DataFlow graph, the pass builds a `LocalGraph` and calls `computeInfluences()`.
That powers two key behaviors:

### `UseFinder`

`UseFinder` starts from the value of a `local.set` and walks through:

- influenced `local.get`s,
- copy-only `local.set` chains,
- and non-set uses such as `return` / call-argument / other external consumers.

The pass models non-set uses as `nullptr` “other” uses.
That distinction matters because a trace can still be valid Souper text even when some internal node also escapes elsewhere; the printer annotates those with `hasExternalUses`.

### `souperify-single-use`

The single-use sibling scans all nodes with real wasm origins and asks `UseFinder` for their uses.
If a node has more than one use, it is inserted into `excludeAsChildren`.
Later, when building a trace, such a node may still be the **root** to infer, but it cannot be expanded as a child of some larger trace.
Instead the trace builder replaces it with a fresh `Var`.

That means `souperify-single-use` is **not** “emit only roots with exactly one use.”
It is:

- “when a reused node would become a child dependency, stop there and summarize it as an unknown variable.”

## 5. Trace building is bounded and intentionally lossy

The core extraction work lives in `DataFlow::Trace`.

Important bounds and heuristics:

- default depth limit: `10`
- default total node limit: `30`
- env var override: `BINARYEN_SOUPERIFY_DEPTH_LIMIT`
- env var override: `BINARYEN_SOUPERIFY_TOTAL_LIMIT`

If a dependency slice grows too deep, too large, or hits an excluded child node, the pass replaces that subtree with a fresh `Var` of the same wasm type.

The trace is also discarded entirely when it is too trivial:

- zero nodes,
- or only one `Var` node before path conditions are added.

So the pass does **not** promise exact whole-expression extraction.
It promises a bounded, useful trace.

## 6. Only a narrow computation surface is traceable

`Trace::isTraceable(...)` only accepts node kinds whose wasm origin is one of:

- unary integer ops in the supported set,
- binary integer ops in the supported set,
- `select`.

The printer's actual opcode map in `printExpression(...)` is also narrow.
The reviewed surface includes:

### Unary

- `clz` / `ctlz`
- `ctz` / `cttz`
- `popcnt` / `ctpop`

### Binary

- add / sub / mul
- signed and unsigned div / rem
- and / or / xor
- shifts and rotates
- equality / inequality
- signed and unsigned less-than / less-equal

### Ternary

- `select`

That means this is **not** a generic Souper extractor for every wasm operation.
Loads, calls, memory ops, floating-point ops, and many other AST forms are outside the printed opcode surface here.

## 7. Phis and path conditions are real, but narrowly sourced

The DataFlow graph can create `Phi`, `Block`, and `Cond` nodes for merged local state.
The printer emits them as:

- `block`
- `phi`
- `blockpc`
- `pc`

The reviewed `Souperify.cpp` comments and code show an important limitation:

- path conditions and blockpcs are currently only sourced from `if` structure.

The file header explicitly lists a TODO for:

- `pcs and blockpcs for things other than ifs`

So a correct beginner summary is:

- merged locals can become Souper-style phis,
- but extra path-condition information is only generated for `if`-based control flow today.

## 8. External-use annotation is part of the contract

After collecting the main work nodes but before adding path conditions, the trace calls `findExternalUses()`.
For every non-root expression or phi node, the printer may append:

- `(hasExternalUses)`

That is not decorative noise.
It tells downstream readers that the subcomputation being reasoned about is also used somewhere outside the inferred root.

In `souperify-single-use`, the pass asserts that the printed trace never carries that marker.

## 9. The pass prints text and does not optimize the function body

`doWalkFunction(...)` prints:

- a function header comment,
- then one or more `; start LHS` trace blocks,
- but it does not rewrite the function body into a new optimized form.

So despite living in `src/passes/`, this pass is best taught as:

- extraction / instrumentation,
- not transformation.

## What the pass is not

## Not `dataflow-optimization`

`dataflow-optimization` / `dfo` also uses Binaryen's DataFlow IR, but it is a separate optimization pass family.
`Souperify.cpp` even carries a TODO about possibly generalizing DataFlow IR use so that internal Binaryen optimizations could subsume some propagate-style work later.

So the relationship is:

- `souperify` prints traces,
- `dfo` rewrites code.

## Not `flatten`

`flatten` creates the precondition.
`souperify` assumes the precondition.
It does not itself flatten nested control/value shapes.

## Not `simplify-locals-nonesting`

That neighboring pass is useful because it reduces boring copies before extraction, but it is still ordinary Binaryen IR cleanup.
`Souperify` is the later trace-emission consumer.

## Not full-program Souper integration

The upstream file header still lists TODOs for:

- wider path-condition support,
- possible inlining through calls,
- and broader internal DataFlow-IR reuse.

So the current `version_129` pass is a narrow extractor, not a complete Souper-backed optimization pipeline.

## Important positive families

## Straight-line integer expression slices

Classic shape:

```wat
(local.set $i
  (i64.eq
    (local.get $a)
    (local.get $x)))
(local.set $j
  (i64.ne
    (local.get $a)
    (local.get $y)))
(local.set $r
  (i32.and
    (local.get $i)
    (local.get $j)))
(return (local.get $r))
```

This becomes a small Souper LHS with the computation nodes and inferable root.

## `if`-guarded traces with path conditions

If the root lives under an `if` arm, the trace can carry path conditions describing that arm.
That is where `pc` and `blockpc` lines come from.

## Merge-driven traces with `phi`

When a flat local gets different incoming values from multiple reachable branches, the DataFlow graph can model that with `phi` nodes over a shared `block` source.

## Important preserved / bailout families

## Loop-carried values

Real loop phis are intentionally avoided; the pass falls back to `Var` boundaries.

## Deep or overly wide slices

Too-deep or too-large subgraphs are truncated to `Var`s.

## Unsupported ops

Only the narrow printed unary/binary/select opcode families survive to emitted traces.
Unsupported expressions become `Bad` or terminate expansion before printing.

## Trivial roots

A trace that would amount to no useful work, or just a single unknown variable, is dropped entirely.

## Best short teaching sentence

The most accurate short teaching sentence I found is:

> `souperify` is a flat-IR DataFlow-graph extractor that prints bounded Souper-style traces for traceable integer computations; `souperify-single-use` is the same extractor with multi-use child slices truncated to fresh variables.

## Implications for future Starshine work

If Starshine ever wants to mirror or study this pass faithfully, the key things to preserve are:

1. public upstream identity as `souperify` and `souperify-single-use`,
2. hard `flatten` precondition via `Flat::verifyFlatness`,
3. DataFlow-IR construction instead of direct AST printing,
4. `LocalGraph`-powered use discovery,
5. bounded trace extraction with depth / total limits and `Var` replacement,
6. narrow opcode printing surface,
7. `if`-only path-condition generation,
8. loop-phi avoidance,
9. single-use mode as child truncation, not root filtering.

## Planned wiki fileback

Create a new upstream-only dossier under:

- `docs/wiki/binaryen/passes/souperify/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `flat-dataflow-traces-and-single-use-boundaries.md`
- `wat-shapes.md`

and update:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Souperify.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
- current-main spot checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Souperify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
