---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
  - ../code-folding/index.md
---

# `dae-optimizing`: signature updates and nested reruns

This page focuses on the parts of Binaryen `dae-optimizing` that are easiest to misunderstand:

- when Binaryen decides a function boundary is still safe to rewrite
- how it changes params and results
- why call localization exists
- why the optimizing rerun is part of the real pass contract

## The big beginner warning

If you summarize the pass as:

- “remove parameters that are never read”

you will miss most of the implementation.

The real boundary story is closer to:

- “rewrite a function boundary only if Binaryen still owns the whole direct-call surface, update both sides of that boundary together, and then clean up the debris.”

## 1. Closed-world boundary checks

Binaryen only performs signature-changing rewrites when it can still reason about the function through collected direct calls.

## Exported functions are not safe signature targets

Exports are treated as unseen calls.

The intuition is simple:

- an export is part of the module’s external ABI
- callers outside the currently scanned direct-call set may exist
- so DAE cannot safely delete or retype params or results there

## `ref.func` makes a function escape

If Binaryen sees `ref.func $f`, it marks `$f` as having unseen calls too.

That means even if the current module also has direct calls to `$f`, DAE still refuses signature-changing rewrites because some later `call_ref` or external flow may depend on the old boundary.

## `call_ref` and `call_indirect` are conservatism signals, not easy rewrite surfaces

DAE is mainly a **direct-call** boundary optimizer.

Indirect-style calls matter for tail-call or escape conservatism, but they are not the main thing the pass rewrites the way it rewrites plain `call`.

## Imports stay fixed

Imported functions are skipped.

That is both:

- an ABI constraint
- and a strong hint that this pass is about module-internal boundary cleanup, not arbitrary signature mutation

## 2. Parameter updates are a family, not one rewrite

Binaryen has several different ways to improve a parameter slot.

## Family A: the param is truly unused

This is the simplest and most obvious case.

If the function body never needs an incoming param, Binaryen can try to remove that slot from:

- the function type
- the function body’s param list
- every direct callsite

But even that “simple” family still requires whole-boundary rewriting, not just body cleanup.

## Family B: every direct call passes the same constant

A parameter may still be read in the body and still be removable.

If every direct call passes the same constant actual, Binaryen can:

1. materialize that constant inside the callee body
2. mark the old incoming param unused
3. remove it later like Family A

That is why `dae-optimizing` is partly a call-boundary constant propagation pass.

## Family C: the param type can become more precise

When GC is enabled and the parameter is a reference type, Binaryen can make it **narrower** without deleting it.

It uses the least upper bound of all direct-call operand types for that slot.

So the pass can change a boundary from “broad ref family” to “narrower ref family” even when the parameter is still semantically needed.

This often matters because later cleanup can remove redundant casts or tests once the incoming boundary already promises something narrower.

## 3. Why `type-updating.h` matters

Changing a parameter type is not just a function-type edit.

Inside the callee, the old parameter may participate in:

- `local.get`
- `local.set`
- `local.tee`
- copied-local flows

If the incoming type narrows, those local operations may need repair.

That is why Binaryen uses `TypeUpdating::updateParamTypes(...)` instead of only swapping out the function signature and hoping validation survives.

## 4. Why Binaryen does not refine already-unused params first

The source comments explain that DAE intentionally skips type-refining params already marked unused.

That is easy to overlook, but it is a smart stability rule.

The reason is roughly:

- unused params may soon be turned into callee locals or removed entirely
- refining them too early can create defaultability or local-conversion complications
- so Binaryen keeps the rewrite order simple and robust

A future port should preserve that ordering discipline unless it has a clearly justified alternative.

## 5. Return updates are also a family

Just like params, function results can improve in more than one way.

## Family A: result type refinement

If all returned values prove a narrower result type, Binaryen can refine the function result using LUB logic.

That change must also propagate to:

- direct call expression types
- surrounding expression typing after refinalization

So this is another “both sides of the boundary move together” story.

## Family B: full return removal

If every observed direct call drops the result, DAE may be able to remove the result entirely.

That changes:

- the function result type
- the function body’s returns
- every `drop(call ...)` site

That is much bigger than a peephole.

## 6. Why `call; unreachable` exists after dropped-return removal

One of the trickiest correctness corners is when the old dropped call had an uninhabitable result type.

In that case, the caller knew something stronger than “this returns a value we ignore.”
It knew something like:

- normal execution does not continue meaningfully here

If Binaryen removed the surrounding `drop` and left only `call`, it could weaken that typing/control-flow fact.

So the pass sometimes rewrites the caller conceptually as:

```wat
(call $f ...)
(unreachable)
```

That detail is very easy to miss, and it is exactly the kind of behavior a future port must preserve to stay validation-correct.

## 7. Tail calls create negative families

Dropped-return removal is deliberately conservative around tail calls.

Binaryen tracks:

- whether a function contains tail calls
- whether other functions tail-call into it

Those facts can block full return removal even if all visible direct callers seem to drop the result.

So a good beginner rule is:

- “all direct callers drop the result” is necessary, not always sufficient

## 8. Why call localization exists

This is another major misunderstanding trap.

Suppose a parameter is unused and could disappear semantically, but some direct callsites pass the argument through nested or effectful expressions.

Deleting the operand in place might:

- change evaluation order
- drop effects that still must happen
- or otherwise make the caller invalid or semantically different

Binaryen handles that by first localizing those difficult call operands.

Conceptually, it turns a hard call shape into a safer one like:

```wat
(local.set $tmp_effectful_arg <old argument expr>)
(call $f ... (local.get $tmp_effectful_arg) ...)
```

and only later removes the now-easy boundary slot.

So DAE is not blindly deleting children from a call node. It has a repair path for hard operands.

## 9. The optimizing rerun is not optional polish

The biggest single scheduler lesson is this:

- the optimizing variant is not just “DAE but maybe a little nicer”
- it is DAE plus a deliberately chosen nested cleanup replay

`OptUtils::optimizeAfterInlining(...)` does two important things:

1. prepends `precompute-propagate`
2. reruns the default function optimization pipeline on the touched functions only

That means DAE’s output boundary is designed with follow-up cleanup in mind.

## What the rerun can clean up

After DAE changes a function boundary, the touched functions may contain fresh debris such as:

- newly injected locals for constant actuals
- localized call operands
- dead casts after param or result refinement
- dead code after result removal
- new common-subexpression or local simplification opportunities

The nested replay is how Binaryen cashes in on those opportunities immediately.

## Why the saved `-O4z` debug log matters

The repo’s saved generated-artifact log proves this is not just source-comment theory.

Inside the DAE section of `.artifacts/o4z-wasm-opt-debug.log`, the nested pipeline replay shows up repeatedly.
That visible replay is why the pass belongs in the tracker as a boundary-only pass with nested-rerun support, not just as “yet another missing module pass.”

## 10. The pass intentionally avoids some low-value work

Binaryen also contains a practical stop rule for long one-caller chains.

If one iteration only removes params from exactly one function, and that function has exactly one caller, Binaryen can decide that continuing deeper right now is not worth it.

The practical takeaway is:

- DAE aims for profitable boundary cleanup inside the pipeline
- not a perfect exhaustive elimination walk in one invocation

That is a very Binaryen-style scheduler choice.

## 11. Good mental model for future Starshine work

If you need one durable porting mental model, use this:

- DAE rewrites **owned direct-call boundaries**,
- does so in a careful order,
- repairs both body and caller typing,
- refuses ABI-visible or escaped surfaces,
- and expects a nested cleanup replay to finish the job.

That is what the implementation really preserves.
