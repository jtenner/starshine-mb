---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - ../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
  - ./wat-shapes.md
---

# Clone construction, signature rebuild, and dropped-call rewrites in `monomorphize`

This page covers the part of `monomorphize` that is easiest to under-teach once the pass has already been summarized as “reverse-inline callsite context into a cloned callee.”

That summary is directionally right, but it hides the real implementation bridge between:

- a built `CallContext`, and
- the concrete specialized function and rewritten callsite that Binaryen emits.

The exact `version_129` contract is more specific:

- derive the new signature from the transformed context IR itself,
- turn old params into locals,
- shift old vars by the param-count delta,
- materialize the reverse-inlined context as a prelude of `local.set`s,
- optionally change the clone’s result type to `none`,
- remove returns from the clone in dropped-call cases,
- and rewrite the original call plus surrounding `drop` to match.

## Why this page exists

The existing dossier already explained:

- candidate scanning,
- effect-safe context extraction,
- trivial-context rejection,
- usefulness measurement,
- dropped-result and return-call boundaries.

But it did not yet isolate the exact clone-and-rewrite mechanics in one compact source-confirmed page.

That gap mattered because a future port can easily go wrong by:

- assuming every original operand becomes one new param,
- forgetting that old params become locals inside the clone,
- remapping locals incorrectly after the new signature is built,
- changing the clone to return `none` without also removing returns,
- or rewriting the clone without also repairing the caller-side `(drop (call ...))` form.

## 1. `processCall(...)` memoizes both successful and failed contexts

Before the clone mechanics even start, Binaryen does one subtle but important thing:

- it memoizes a `(target, context)` pair whether specialization succeeds **or** fails.

So the memo table can contain both:

- `(foo, contextA) -> foo$mono`
- `(foo, contextB) -> foo`

The second case means “this context was already proven not worth specializing.”

That is part of the real implementation contract, not just an optimization detail.

## 2. The new specialized signature comes from surviving `LocalGet`s in the context IR

This is the biggest beginner surprise in `makeMonoFunctionWithContext(...)`.

Binaryen does **not** say:

- “keep one new param for each original call operand that stayed dynamic.”

Instead it walks every transformed context operand with `FindAll<LocalGet>` and appends the types of all discovered `LocalGet`s into `newParams`.

That means the signature is derived from the **actual transformed context tree**, not from original call arity alone.

### Why that matters

A context operand can be partly moved and partly still dynamic.
So the real boundary is:

- moved structure becomes internal prelude code,
- surviving `LocalGet`s become external params of the specialized clone.

## 3. Dropped-call specialization changes the clone’s result type immediately

If the original call was immediately dropped, the context records `dropped = true`.

In that case Binaryen rebuilds the cloned function type with:

- the new derived params, and
- `Type::none` as the result.

So a dropped-call specialization is not just “later DCE might remove the drop.”
It is a deliberate boundary rewrite in the clone itself.

## 4. Old params become locals inside the specialized clone

After the new signature is chosen, Binaryen builds a `mappedLocals` table.

For each old local index:

- if it was an old param, Binaryen allocates a fresh var in the clone and maps the old param index to that new local;
- if it was already a var, Binaryen shifts it by the param-count delta.

This is the key source-confirmed rule:

- old external params are no longer preserved as params by index,
- they become internal locals populated by the reverse-inlined prelude.

## 5. Old non-param locals shift by the param delta, not by ad hoc renumbering

For old vars, the rule is exact:

- `new index = old index + (new param count - old param count)`

That is why the pass can preserve the body with one systematic remap instead of synthesizing a completely new local layout.

## 6. Local names are copied through the remap with fresh validity checks

If the source function had local names, Binaryen clears the clone’s default local-name tables and rebuilds them using the mapped indexes plus `Names::getValidLocalName(...)`.

This proves two things:

- the pass takes debug-facing structure seriously enough to preserve it,
- and the clone’s local space is treated as genuinely rebuilt, not as a casual shallow copy.

## 7. The reverse-inlined context becomes a prelude of `local.set`s

After the clone and local mapping exist, Binaryen emits one prelude assignment per original parameter slot:

- the target local is the mapped old parameter local,
- the value is a copied version of the transformed context operand.

In plain language:

- the specialized function recreates the old callee entry state,
- but it computes some of that entry state internally from reverse-inlined context.

If any such prelude work exists, Binaryen wraps:

- all prelude `local.set`s,
- then the old cloned body

into one outer block.

## 8. The cloned body then gets a systematic local-index rewrite walk

Binaryen uses a small `LocalUpdater` postwalk over the cloned body to rewrite every `LocalGet` and `LocalSet` index through `mappedLocals`.

This is the body-side repair that makes the new signature and prelude actually line up with the cloned old body.

A future port that rebuilds the signature and prelude but forgets this body walk would not be implementing the same pass.

## 9. Dropped-call specialization also removes returns from the clone

When `context.dropped` is true, Binaryen calls:

- `ReturnUtils::removeReturns(newFunc.get(), wasm)`

after the prelude/body assembly.

So the dropped-call rule is two-sided:

- cloned result type becomes `none`, and
- explicit returns are removed from the specialized body.

This is the source-backed reason `monomorphize-drop.wast` can show the drop disappearing cleanly instead of leaving a mismatched result-producing clone behind.

## 10. Caller rewrite changes the call target, operands, and maybe the surrounding `drop`

`updateCall(...)` is small, but it carries the visible rewrite contract.

It:

1. replaces the direct call target with the chosen specialized function name,
2. replaces the operand list with the reduced `newOperands`,
3. and, if the call was originally dropped, replaces `(drop (call ...))` with the updated call itself after forcing the call type to `none`.

So a faithful port must update both halves:

- the specialized callee boundary,
- and the caller-side wrapper around the call.

## 11. The measured usefulness includes the rebuilt clone shape

The clone mechanics are not just output formatting details.
They feed directly into the usefulness gate.

Binaryen compares:

- optimized original callee cost plus the cost of the context operands that still live at the callsite,
- versus optimized specialized-clone cost.

That means the following are part of the actual decision rule:

- rebuilt signature,
- param-to-local conversion,
- prelude `local.set`s,
- dropped-result return removal,
- reduced caller operand list.

So if a future port changes these mechanics, it changes the economics of `monomorphize`, not just its emitted WAT shape.

## 12. Best mental model for the specialized clone

A beginner-friendly accurate model is:

- keep only the still-dynamic pieces as the new external params,
- turn the old params into internal locals,
- reconstruct those old param locals with reverse-inlined prelude code,
- then run the old body under a remapped local space,
- and if the original call was dropped, make the clone effect-only and remove returns.

That is much closer to the real Binaryen implementation than simply saying “clone the callee with constants substituted.”

## Porting checklist

A faithful future port should preserve all of these exact mechanics:

- memoize failed as well as successful `(target, context)` pairs,
- derive the new signature from surviving `LocalGet`s in context operands,
- change clone results to `none` for dropped-call contexts,
- convert old params into internal locals,
- shift old vars by the param-count delta,
- rebuild local names through the remap,
- emit a prelude of `local.set`s for the reverse-inlined context,
- rewrite local indexes in the cloned old body,
- remove returns from dropped-result clones,
- update the original call target and operands,
- replace `(drop (call ...))` with the updated `call` when needed.

## Easy-to-miss summary

If someone remembers only one sentence from this page, it should be this:

> Binaryen `monomorphize` does not merely clone a callee with some constants baked in; it rebuilds the specialized function boundary from the transformed call context, remaps locals systematically, and couples dropped-call clone repair with caller-side `drop` removal.

## Sources

- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- [`../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md`](../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp>
