---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./wat-shapes.md
---

# Profitability, indirection, and type barriers in `merge-similar-functions`

This page covers the half of the pass that is easiest to misread from the name alone.

A beginner might expect:

- if two functions are almost the same,
- Binaryen merges them.

That is **not** the real rule.

The real rule is closer to:

- if two functions are almost the same **in one narrow supported way**,
- and the synthetic helper can be typed safely,
- and the extra thunks do not lose code size,
- and the final helper signature stays under the hard limit,
- then Binaryen merges them.

## Why profitability matters

The pass exists for **size reduction**.
So a legal merge that makes the module larger is still a bad merge.

Binaryen's heuristic counts rough costs on both sides.
The reviewed `version_129` implementation is still approximate, but it is not hand-wavy: it uses fixed weights for removed duplicated instructions versus thunk forwarding, helper-local declarations, code-section entry overhead, and function-section entry overhead.

### Positive side

You delete duplicate large bodies.
If several wrappers are long and mostly identical, one shared helper can save many instructions.

### Negative side

You must add:

- one new shared helper entry
- one thunk per original function
- `local.get` forwarding inside every thunk
- literal or `ref.func` payload materialization inside every thunk
- extra local declarations / code-section overhead in the shared helper
- function-section overhead for the retained wrappers

So tiny wrappers often lose.
That is why the lit tests deliberately keep some tiny constant-only wrappers unchanged.

## Why the 255-param limit matters

Binaryen also enforces a hard width ceiling:

- original params
- plus synthetic params
- must stay `<= 255`

The dedicated `merge-similar-functions-param-limit.wast` file proves that this is not a theoretical note.
It is part of the public behavior.

Practical meaning:

- even a very profitable large merge is rejected if it would make the helper too wide
- a future port must preserve this hard stop, not merely rely on later validation to fail

## Why call-target parameterization is feature-gated

The most interesting merge family is when two wrappers differ only by which same-signature direct callee they invoke.

Binaryen can merge that family only by turning the difference into a function reference parameter.
That requires:

- reference types
- GC

Why?
Because the shared helper needs a function-ref param that can be used with `call_ref`.
Without that feature surface, Binaryen cannot safely express the rewritten helper body.

So the source's `isCallIndirectionEnabled(...)` check is not an optional convenience.
It is the gate that decides whether call-target differences are even eligible for parameterization.

## Why same callee signature is required

Even with reference types and GC enabled, the differing callees must still have the **same function type**.

If they do not, the shared helper would need one synthetic param type that somehow accepts both.
The reviewed pass does not try to invent that.
It simply rejects the merge.

The official `merge-similar-functions_types.wast` file is the cleanest demonstration of this rule.

## Why subtype-looking cases can still fail

The all-features test also proves an easy beginner trap:

- two callees may each be callable with the same concrete operand in some local sense
- but if there is no single safe merged function-ref parameter type for the helper
- Binaryen still leaves the wrappers separate

So “both calls look compatible to me” is not enough.
The helper's synthetic signature has to make sense too.

## Why repeated difference-vectors reuse one param

Suppose two wrappers differ at multiple sites, but the per-function payload vector is identical each time.

Example:

- wrapper A uses `42` twice
- wrapper B uses `43` twice

A naïve implementation might create two synthetic params.
Binaryen does not.
It reuses one.

Why this matters:

- fewer helper params
- better chance of staying under the 255-param limit
- less thunk overhead
- better profitability

So synthetic-param reuse is both a correctness detail and a profitability detail.

## Why local-index repair matters to the economics too

Adding synthetic params changes the index boundary between params and non-param locals.
If a port gets that wrong, the shared helper becomes invalid semantically.

But it also matters to the code-size model:

- a broken port might invent unnecessary extra temporaries to paper over index mistakes
- Binaryen's actual implementation avoids that by simply shifting existing non-param locals upward

So the local-repair rule is part of keeping the merge compact.

## Tail-call detail beginners often miss

If a wrapper had a returning call shape and tail calls are enabled, the thunk and shared helper preserve that style using `return_call` / `return_call_ref` where appropriate.

That means the pass is not just copying code-size intent; it is also preserving the source-level control-transfer shape where the feature model allows it.

## Practical teaching rule

When deciding whether a near-duplicate family should merge, ask these questions in order:

1. are the wrappers structurally the same except for supported differences?
2. are those differences only literals or eligible direct-call targets?
3. if calls differ, are reference types + GC enabled?
4. if calls differ, do the callees share one function type?
5. after synthetic-param reuse, does the helper stay at 255 params or fewer?
6. does the helper-plus-thunks rewrite still seem smaller than keeping the duplicates?

If any answer becomes “no,” expect a bailout.

## Easy-to-miss teaching summary

If someone remembers only one sentence from this page, it should be this:

> Binaryen `merge-similar-functions` is only willing to merge near-duplicates when it can express the differences as a safely typed compact helper signature and still win on size after paying for the helper and thunks.

## Sources

- [`../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md`](../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
