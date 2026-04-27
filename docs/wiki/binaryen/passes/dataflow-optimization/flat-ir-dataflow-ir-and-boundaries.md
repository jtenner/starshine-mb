---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
---

# Flat IR, DataFlow IR, and boundaries for `dataflow-optimization` / `dfo`

## The core teaching problem

`dfo` only makes sense once you separate **three** things that are easy to blur together:

1. ordinary Binaryen tree IR
2. Binaryen **Flat IR**
3. Binaryen **DataFlow IR**

If those layers get mixed together, the pass becomes almost impossible to explain correctly. The 2026-04-25 and 2026-04-27 current-main rechecks found no reason to change this layer split: upstream still begins from flatness verification, then builds the separate DataFlow graph, then writes only proven constants back into the flat wasm. The Starshine port-readiness page keeps the resulting substrate choice explicit instead of assuming local HOT IR is already equivalent.

## Layer 1: ordinary Binaryen tree IR

This is the normal structured expression tree representation.
It allows nested value expressions directly.

`dfo` is **not** defined directly over this form.

## Layer 2: Flat IR

`flatten` converts nested structured value traffic into explicit local traffic.
For example, values that used to be nested under control flow get routed through temporary locals.

That matters because `dfo` needs:

- explicit local definitions and uses
- easy child replacement points
- branch-merging behavior that can be summarized as local-state merges

This is why the pass begins with `Flat::verifyFlatness(func)`.

## Layer 3: DataFlow IR

Once the code is flat, `dfo` builds another representation on top of it:

- an SSA-like dataflow graph

This graph has synthetic nodes such as:

- `Phi`
- `Cond`
- `Block`
- `Var`
- `Bad`

So the pass is **not** just optimizing Flat IR directly.
It is:

- reading Flat IR
- translating selected parts into DataFlow IR
- optimizing the graph
- writing some improvements back to the flat wasm

## Why the relevant-type filter matters so much

The reviewed helper code says relevant types are integer types.
That means the pass is primarily about:

- integer locals
- integer arithmetic
- integer comparisons
- integer-ish select and merge behavior

It is **not** a broad typed DataFlow IR optimizer over all wasm value kinds.

That is one of the most important boundaries in the whole pass.

## Why loops are intentionally lossy

A beginner might expect an SSA-style graph pass to love loop phis.
The reviewed source explicitly does the opposite.

The loop logic says, in effect:

- if a loop really carries changing values across iterations,
- stop pretending the trace is a fixed known value,
- and use an unknown `Var` instead.

This makes the pass less powerful, but much easier to keep honest for its intended use.

The real contract is therefore:

- **straight-line and branch-merge precision are the goal**
- **true loop-varying precision is mostly abandoned**

## Why unsupported instructions become unknowns instead of hard errors

Another easy misunderstanding is to think the pass only works on tiny toy code because it supports a narrow opcode set.
That is not quite right.

What actually happens is:

- many unsupported instructions are still traversed
- but their precise result becomes `Var` or `Bad`

That means the graph can still observe some surrounding local-flow structure without claiming unsupported facts.

This is a major reason the pass composes with larger flattened functions at all.

## The exact optimization surface

The pass name sounds huge.
The actual optimization surface is small.

## Surface A: identical constant-phi collapse

If a merged local state yields a phi whose incoming values are all the same constant-equivalent node, `dfo` can replace the phi's uses with that constant.

## Surface B: all-constant expression folding

If a supported `Expr` node has only constant inputs and a concrete result type, `dfo` tries nested `precompute` and accepts the rewrite only if that produces a literal constant.

That is almost the whole real rewrite story.

## Why nested `precompute` is part of the real contract

A tempting oversimplification would be:

- build graph
- see all inputs constant
- evaluate the node directly

That is **not** what `version_129` does.
It deliberately routes actual constant evaluation through nested `precompute`.

That preserves real Binaryen folding semantics for things like:

- trap-sensitive operations
- non-folded corner cases
- only-if-really-a-const final acceptance

So a future port that skips this and invents a looser evaluator could easily become less correct than upstream.

## Positive boundaries

These are the families where the pass is genuinely at home:

- flat integer-local arithmetic chains
- branch merges through explicit local states
- supported unary/binary/select nodes
- values that become constant after earlier replacements
- aggressive flattened pipelines that still plan to do normal cleanup later

## Negative boundaries

These are the families where the pass intentionally stops or loses precision:

- non-flat input
- EH instructions
- unsupported opcodes
- non-integer-focused value traffic
- real loop-varying state
- all-constant inputs whose nested `precompute` result still is not a `Const`

## What a future Starshine port must not silently change

- do not silently drop the flatness requirement
- do not silently widen the relevant-type filter without explicit intent
- do not silently turn loops into rich precise SSA if the goal is Binaryen parity
- do not replace nested `precompute` with a broader local evaluator and still call the result the same pass
- do not teach the pass as if it owns later cleanup of the flattened code shape

## Beginner mental checklist

When reading a candidate `dfo` shape, ask these questions in order:

1. Is the function already flat?
2. Is the interesting value traffic mostly integer-local traffic?
3. Are the operations in the supported unary/binary/select subset?
4. Are merges branch merges rather than true loop-carried variation?
5. If everything becomes constant, would nested `precompute` actually fold it to a literal constant?

If several of those answers are no, the right prediction is usually:

- `dfo` will either do nothing, or only recover a much smaller local simplification than its name suggests.

## Sources

- [`../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md)
- [`../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md`](../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md)
- [`../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md`](../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
