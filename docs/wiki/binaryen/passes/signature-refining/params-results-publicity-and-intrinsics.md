---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `signature-refining`: params, results, publicity, and intrinsics

This page exists because the easiest way to misunderstand `signature-refining` is to flatten four different ideas into one vague story:

- refining params
- refining results
- deciding which signatures are allowed to change at all
- handling `call.without.effects`

Binaryen treats those as separate problems.
The official source URLs and the 2026-05-05 freshness check are captured in [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md), and the local Starshine status is tracked in [`./starshine-strategy.md`](./starshine-strategy.md).

## The most important split: `canModify` vs `canModifyParams`

The pass tracks two related but different booleans per heap type:

- `canModify`
- `canModifyParams`

That split is the key to the whole pass.

## `canModify = false`

When this is false, Binaryen does **not** refine that signature type at all.
Neither params nor results change.

The pass sets this for:

- imported functions
- public function types
- tag-used function types
- signature types with subtypes
- signature types with supertypes

Those are full blockers.

## `canModifyParams = false`

When this is false, Binaryen keeps the **params** unchanged, but can still refine **results**.

The pass sets this for:

- JS-called function types
- continuation-used function types

Those are params-only blockers.

## Why that split exists

Binaryen's source comments make the reasoning explicit:

- refining params can make old callers invalid if the callers are not fully updated
- refining results is often safer because callers can still accept a more specific result than before

That is why `signature-refining` is not one generic “tighten the whole signature” action.

## Publicity is about type reachability, not just exports

The pass calls `ModuleUtils::getPublicHeapTypes(...)` and then freezes public function types.

That helper makes several families public:

- imported function types
- exported function types
- imported ref-typed table/global/tag boundaries
- any heap types transitively referenced from those public rec groups

So the true rule is not:

- exported function => no optimization

The true rule is closer to:

- public **rec-group reachability** => no optimization for those function heap types

That is why the lit file includes a case where exporting a global of a struct type can indirectly block refining a function type in the same rec group.

## Params come from callers

Parameter refinement uses actual argument types from:

- direct `call`
- `call_ref`
- `call.without.effects` extra-call handling

The pass builds one `LUBFinder` per parameter index and feeds it those operand types.

### What that means in practice

If all callers pass exact `$struct`, Binaryen can refine:

- `anyref -> (ref (exact $struct))`

If one call passes exact `$struct` and another passes `null`, Binaryen can refine to:

- `(ref null (exact $struct))`

If callers pass unrelated-but-joinable eqref values, the LUB may land on:

- `eqref`

If callers never provide real type evidence because there are no calls or only bottom/unreachable values, then params do not refine at all.

## Results come from functions, not callers

Result refinement uses `LUB::getResultsLUB(...)`.
That helper looks at:

- the refinalized body type
- explicit `return`
- `return_call`
- `return_call_indirect`
- `return_call_ref`

So results refine from what functions **produce**, not what callers consume.

### Why that difference matters

A beginner might assume that if all callers immediately cast a result to `$struct`, the pass can refine the result to `$struct`.
That is not what the source does.
The pass asks instead:

- what values do functions with this heap type actually return?

That is a different question.

## Body repair matters only on the param side

Sharper params can invalidate old local writes inside the function body.
That is why the pass calls:

- `TypeUpdating::updateParamTypes(...)`

This helper creates broader fixup locals when necessary.

Results do not need that same kind of in-body local fixup.
Instead, result refinement mainly needs:

- call / `call_ref` cached result-type updates
- later `ReFinalize`

So the repair surfaces are deliberately asymmetric.

## `call.without.effects` is a two-sided special case

This intrinsic is the strangest part of the pass because it matters in **two different directions**.

## 1. It participates in parameter refinement of the referenced function type

When Binaryen sees a direct call to `call.without.effects`, it also treats the intrinsic as an `extraCall` for the referenced function type.

That means:

- its ordinary operands count toward the target signature's parameter LUB
- the last operand, the function reference, is ignored for that LUB calculation

So `call.without.effects` can help refine a target function's params.

This is source-backed and test-backed.

## 2. It needs custom result repair after target functions refine

If the referenced function's result type becomes sharper, the intrinsic import itself still advertises the old result type.
So Binaryen must:

- create a new intrinsic import with the sharper result type
- retarget matching intrinsic calls to the new import
- reuse the same cloned import when multiple calls need the same refined intrinsic signature

So `call.without.effects` is not just a blocker or just a bystander.
It is both:

- part of the param-side evidence
- part of the result-side repair work

## Why tags and continuations differ

The pass treats tags and continuations differently.
That is easy to miss.

## Tags

Tag-used signatures get:

- `canModify = false`

So params and results are both frozen.

Reason from the source:

- Binaryen does not analyze and optimize EH or stack-switching instructions here

## Continuations

Continuation-used signatures get:

- `canModifyParams = false`

So params stay unchanged, but the pass does not explicitly freeze result refinement the same way.

Reason from the source:

- Binaryen does not yet update continuation users like `cont.bind` / `resume` with new param types

The dedicated lit file proves the param-freeze story directly.
It does not include a standalone continuation-result refinement example, so that narrower point should stay labeled as source-backed but only partially test-backed.

## Why subtype-linked signatures are a hard no-op

The pass refuses to optimize signatures that:

- have subtypes
- or have a declared supertype

These two halves exist for different reasons.

### Has subtypes

If a parent signature changes, its subtype cluster may need coordinated updates too.
This pass does not attempt that.

### Has a supertype

Parameter refinement is contravariant territory.
A child parameter cannot just be made more specific unless the parent relationship still remains valid.
This pass does not attempt that either.

So subtype-linked signatures are not just “annoying edge cases.”
They are a core unsupported surface.

## Single-pass behavior is part of the contract

Unlike `signature-pruning`, `signature-refining` does **not** do:

- delayed `ChildLocalizer` reruns
- two-cycle retries
- iterative constant-actual exposure

It analyzes once and commits once.

That matters because it keeps the real teaching boundary clear:

- `signature-pruning` can remove params after a staged cleanup sequence
- `signature-refining` sharpens types in one pass based on already visible evidence

## Quick beginner checklist

If you want the safest mental model, use this checklist.
A heap type can be fully refined only when all of these are true:

- GC is enabled
- the module has no tables
- the heap type is not imported/public/tag-used/subtype-linked
- parameter refinement is not blocked by JS-called or continuation usage
- there is enough call-site evidence for every parameter you want to refine
- there is enough returned-value evidence for every result you want to refine
- body-local writes can be repaired when params get sharper
- any affected `call.without.effects` users can be retargeted to refined intrinsic imports

If any one of those fails, the pass becomes narrower or does nothing.

## Bottom line

The hardest part of `signature-refining` is not the type lattice itself.
It is keeping these four stories separate:

- param LUBs from callers
- result LUBs from returns
- full blockers vs params-only blockers
- special intrinsic repair after the nominal signature rewrite

Once that split is clear, the pass becomes much easier to teach and to port.

## Sources

- [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
