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
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `signature-refining`: implementation structure and tests

This page exists because `SignatureRefining.cpp` is not a self-contained pass.
If you read only that one file, you will miss where most of the real behavior comes from.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/SignatureRefining.cpp` | Core pass logic: gates the pass, aggregates facts by heap type, computes param and result LUBs, repairs function bodies for sharper params, rewrites signatures, updates `call.without.effects`, and refinalizes |
| `src/passes/pass.cpp` | Registers `signature-refining` and places it in the closed-world GC/type prepass cluster after `signature-pruning` and before `global-refining` |
| `src/ir/lubs.h` / `src/ir/lubs.cpp` | Supplies `LUBFinder` and `LUB::getResultsLUB(...)`, which are most of the real result-refinement logic |
| `src/ir/module-utils.h` / `src/ir/module-utils.cpp` | Supplies `ParallelFunctionAnalysis`, `collectHeapTypes`, and `getPublicHeapTypes`, which define the per-function analysis shape and the public-rec-group boundary |
| `src/ir/type-updating.h` / `src/ir/type-updating.cpp` | Supplies `GlobalTypeRewriter::updateSignatures(...)` and `updateParamTypes(...)`, which make safe module-wide signature rewriting and param-body repair possible |
| `src/ir/subtypes.h` | Supplies the subtype query surface used to skip subtype-linked signatures |
| `src/ir/intrinsics.h` / `src/ir/intrinsics.cpp` | Supplies `isCallWithoutEffects(...)` and `getJSCalledFunctions()`, which drive two important special cases |
| `test/lit/passes/signature-refining.wast` | Main contract surface for both positive and negative refinement families |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `SignatureRefining::run(Module* module)`

This pass method does five big things:

1. enforce GC / no-table gates
2. collect call and returned-value information by heap type
3. compute refined param and result signatures where legal
4. repair function bodies and atomically rewrite nominal signatures
5. patch `call.without.effects` imports and refinalize

### 2. `LUB::getResultsLUB(...)`

The pass does not compute result refinement inline.
It delegates that to `lubs.cpp`, which:

- refinalizes the function first
- notes the body type
- scans `return`
- scans `return_call`
- scans `return_call_indirect`
- scans `return_call_ref`

So the result side is much richer than a one-line `Type::getLeastUpperBound` summary suggests.

### 3. `TypeUpdating::updateParamTypes(...)`

This helper is the real body-repair engine.
It inserts fixup locals when sharper params would otherwise break broader local writes.

### 4. `GlobalTypeRewriter::updateSignatures(...)`

The pass does not hand-edit signature heap types or `call_ref` users itself.
It delegates the atomic nominal rewrite to the shared global type rewriter.

### 5. `updateIntrinsics(...)`

The pass owns one special post-rewrite step itself:

- cloning `call.without.effects` imports when refined target results require a sharper import signature

That helper is unique enough that it is part of the visible pass contract.

## Why `SignatureRefining.cpp` is deceptively small

The file is substantial, but still smaller than the behavior it owns.
That is because Binaryen has already pushed the hard reusable pieces into helpers:

- result-LUB discovery in `lubs.cpp`
- public-rec-group discovery in `module-utils.cpp`
- parameter-body repair in `type-updating.cpp`
- nominal type rewriting in `type-updating.h`
- JS-called and `call.without.effects` handling in `intrinsics.cpp`

So the correct teaching model is:

- `SignatureRefining.cpp` defines pass policy, phase order, and which helper results are composed
- the helper files define most of the mechanics

## What the dedicated lit file proves

`test/lit/passes/signature-refining.wast` is large enough to teach most of the real contract.
The most important families are below.

## 1. Direct-call and `call_ref` parameter positives

The file starts with cases where a nominal function type refines from `anyref` to a sharper exact struct ref and both:

- direct `call` users
- `call_ref` users

update consistently.
That proves the pass is not just editing function declarations.

## 2. Mixed-call LUB outcomes

The early file also includes mixed direct plus `call_ref` traffic where the final LUB lands on:

- a common parent struct type
- `eqref`
- nullable exact refs

Those tests prove the pass is using the type lattice, not just exact-equality matching.

## 3. Multiple functions sharing one heap type

Several tests show that:

- multiple functions sharing the same heap type are updated together
- even when only one of them is directly called

That is the clearest proof that the real decision unit is the nominal heap type, not the function.

## 4. Body repair for sharper params

One of the most valuable mid-file regressions refines a parameter from `funcref` to `(ref (exact $sig))` and then shows that the body needs a broader fixup local so old assignments remain valid.

That is the visible consequence of `TypeUpdating::updateParamTypes(...)`.
Without that family it would be easy to think the pass only edits signatures and call sites.

## 5. Unreachable and no-call behavior

The file has three important families here:

- some reachable calls plus one unreachable call still allow refinement
- only unreachable values means no refinement, but also no crash
- no calls at all means no refinement, but also no crash

Those tests clearly prove that parameter refinement requires real call-site evidence.

## 6. Result refinement and call result-type updates

The middle of the file has a large result-focused section showing that:

- a function returning a sharper struct ref can refine its result type
- a function returning only unreachable cannot
- surrounding direct `call` and `call_ref` users must have their cached result types updated too
- enclosing `if` expressions then refinalize to the new sharper result type

That is the main contract surface for the result-refinement half of the pass.

## 7. Public, imported, subtype, and table no-op surfaces

The file has explicit negatives for:

- exported/public signatures
- imported functions
- tables present in the module
- types with subtypes
- types with supertypes

Those are the big “do nothing” fences a port must preserve.

## 8. Bottom / unreachable-printing regressions

The later file has a regression where a `call_ref` uses a bottom target.
The expected output becomes a block that drops the bottom target and then traps.
This proves the pass must keep invalid post-rewrite emission shapes out of the printed IR.

## 9. `call.without.effects` is part of the real contract

The later sections include two especially important intrinsic families:

- one where refined target results require cloning new intrinsic imports with sharper return types
- one where intrinsic-mediated parameter traffic participates in the target function's parameter LUB, both positively and negatively

Without those tests it would be very easy to misdescribe `call.without.effects` as irrelevant bookkeeping.

## 10. Tag and continuation boundaries

The final tests show:

- signatures used by tags are frozen completely
- signatures used by continuations keep their params unchanged
- a different signature in the same continuation-using module can still refine

Those families matter because the source applies different blocker strengths to tags and continuations.

## The tests teach four especially important misconceptions to avoid

### Misconception 1: this is just `signature-pruning`, but for types

It is not.
This pass refines types; it does not remove params, and it also refines results.

### Misconception 2: parameter and result refinement are one symmetric computation

They are not.
Parameters come from caller operand LUBs.
Results come from returned-value LUBs.

### Misconception 3: the closed-world scheduler slot means the pass body itself requires `--closed-world`

It does not.
The lit file and pass source both show a more conservative pass body that instead relies on public/imported/type-family blockers.

### Misconception 4: `call.without.effects` is outside the pass contract

It is not.
The dedicated late-file tests show it matters for both param and result refinement.

## Freshness note

The 2026-05-05 raw manifest in [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md) refreshes the official source and test URLs used for this dossier.
I did a 2026-05-05 current-`main` recheck on:

- `src/passes/SignatureRefining.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/signature-refining.wast`

Durable result:

- the checked core pass structure still matches `version_129` on the important reviewed surfaces
- the dedicated lit file still matches exactly on the reviewed surface
- the new freshness manifest records the no-drift result on the reviewed surfaces

That is a narrow freshness note, not a proof that every neighboring helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module-pass entry point, not a HOT pass
- GC + no-table gate behavior
- per-function direct-call, `call_ref`, and returned-value collection
- heap-type-level aggregation across sibling functions
- public/import/tag/JS-called/continuation/subtyping freeze rules
- caller-driven parameter LUB computation
- returned-value-driven result LUB computation
- body repair for sharper params via fixup locals when needed
- atomic module-wide signature rewriting
- `call.without.effects` import cloning when results sharpen
- final refinalization

Any port that implements only the small top-level pass file without helper-equivalent machinery will not match Binaryen's real behavior.

## Bottom line

For `signature-refining`, the real implementation structure is:

- **small pass file + result-LUB helper + param-body repair helper + public-type analysis + one large lit file**

That is exactly why this pass is easy to underestimate from the name alone.

## Sources

- [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>
