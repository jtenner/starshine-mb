---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `signature-pruning`: implementation structure and tests

This page exists because `SignaturePruning.cpp` is not a self-contained pass.
If you read only that one file, you will miss where most of the real behavior comes from.
For the exact 2026-04-24 source capture, use [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md).
For the current Starshine status and future-port code map, use [`./starshine-strategy.md`](./starshine-strategy.md).

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/SignaturePruning.cpp` | Core pass logic: gates the pass, aggregates facts by heap type, applies constant actuals, attempts parameter removal, rewrites signatures, and schedules one delayed localization rerun |
| `src/passes/pass.cpp` | Registers `signature-pruning` and places it in the closed-world GC/type prepass cluster after `type-refining` and before `signature-refining` / `global-refining` |
| `src/passes/param-utils.h` / `src/passes/param-utils.cpp` | Supplies `getUsedParams`, `applyConstantValues`, `removeParameters`, and `localizeCallsTo`, which are most of the real parameter-editing machinery |
| `src/ir/module-utils.h` / `src/ir/module-utils.cpp` | Supplies `ParallelFunctionAnalysis` and `getPublicHeapTypes`, which define the per-function parallel analysis shape and the public-rec-group boundary |
| `src/ir/type-updating.h` | Holds `GlobalTypeRewriter::updateSignatures(...)` and `handleNonDefaultableLocals(...)`, which make safe module-wide signature rewriting possible |
| `src/ir/subtypes.h` | Supplies the subtype query surface used to skip signature-subtyped families |
| `src/ir/intrinsics.h` / `src/ir/intrinsics.cpp` | Supplies `isCallWithoutEffects(...)` and `getJSCalledFunctions()`, which drive two important exclusion rules |
| `src/ir/possible-constant.h` | Supplies `PossibleConstantValues`, which powers constant-actual promotion before pruning |
| `src/ir/localize.h` | Supplies `ChildLocalizer`, used when effectful or interacting call operands block direct pruning |
| `src/ir/eh-utils.h` | Supplies EH pop fixups after localization adds new blocks |
| `src/cfg/liveness-traversal.h` | Supplies the liveness walker `getUsedParams(...)` relies on for entry-liveness-based parameter usage |
| `test/lit/passes/signature-pruning.wast` | Main contract surface for positive and negative pruning families |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `SignaturePruning::run(Module* module)`

This pass method does five big things:

1. enforce GC / closed-world / table gates
2. run one pruning iteration
3. optionally run exactly one more pruning iteration
4. rely on helper code to rewrite params, calls, and types safely
5. stop after at most two cycles

### 2. `ParamUtils::getUsedParams(...)`

The pass does not decide parameter use by raw textual search.
It delegates that to entry liveness over parameter locals.

### 3. `ParamUtils::applyConstantValues(...)`

This helper is the first half of the real optimization story.
It can rewrite callee bodies before any parameter removal happens.

### 4. `ParamUtils::removeParameters(...)`

This helper performs the real synchronized parameter rewrite across:

- all functions sharing the heap type
- all direct calls to that heap type
- all `call_ref` users of that heap type

### 5. `GlobalTypeRewriter::updateSignatures(...)`

The pass does not hand-edit signature heap types or `call_ref` types itself.
It delegates the atomic nominal type rewrite to the global type rewriter.

### 6. `ParamUtils::localizeCallsTo(...)`

When removal was blocked by operand placement, this helper runs after the type rewrite and may unlock more pruning for the second cycle.

## Why `SignaturePruning.cpp` is deceptively small

The file is substantial, but still smaller than the behavior it owns.
That is because Binaryen has already pushed the hard reusable pieces into helpers:

- parameter entry-liveness analysis in `param-utils.cpp` + `liveness-traversal.h`
- constant-actual reasoning in `possible-constant.h`
- synchronized parameter removal in `param-utils.cpp`
- public-rec-group discovery in `module-utils.cpp`
- nominal signature rewriting in `type-updating.h`
- delayed operand localization in `localize.h`
- EH pop repair in `eh-utils.h`

So the correct teaching model is:

- `SignaturePruning.cpp` defines pass policy, phase order, and which helper results are composed
- the helper files define most of the mechanics

## What the dedicated lit file proves

`test/lit/passes/signature-pruning.wast` is large enough to teach most of the real contract.
The most important families are below.

## 1. Direct-call and `call_ref` positives

The file starts with cases where a nominal function type loses unused middle parameters and both:

- direct `call` users
- `call_ref` users

update consistently.
That proves the pass is not just editing function declarations.

## 2. All-parameter removal

Several tests show that a heap type can shrink all the way to `(func)`.
The interesting detail is that the body still gets fresh locals for internal uses of the removed params.

## 3. Entry-liveness beats raw mention counting

There is a regression where a parameter index is still mentioned in the body, but the incoming value is overwritten before it matters.
The pass still removes that parameter.
That proves `getUsedParams(...)` is using entry liveness, not textual use counting.

## 4. Side-effectful actuals can still optimize after localization

There are paired tests for both:

- direct `call`
- `call_ref`

where an otherwise removable argument has side effects.
The pass first fails removal, then localizes the operand, then succeeds on the rerun.

## 5. Imports and same-type siblings block pruning

The lit file has several negative families showing that:

- an imported function sharing the heap type freezes the type
- a non-imported sibling function using the param freezes the type
- a different heap type with the same final textual shape does **not** freeze a sibling type

Those cases teach the “per heap type, not per shape string” rule clearly.

## 6. Constant-actual promotion is a real optimization phase

The lit file has dedicated positive and negative families for:

- integer constants
- `ref.func`
- `ref.null`
- mixed ref values that must stay unoptimized

Those tests show that constant-actual promotion is a real part of the pass contract, not a helper detail.

## 7. Distinct types stay distinct after shrinking

There is a dedicated regression where two different function heap types both shrink to `(func)`.
The expected output keeps them as distinct nominal types.
Without that test it would be easy to overstate the optimization as plain signature deduplication.

## 8. Public and unsupported boundary cases

The lit file explicitly covers these no-op families:

- module contains a table
- exported/public signature types
- `call.without.effects` target signatures
- tag-used signatures
- continuation-used signatures
- function-subtyping-related signatures

That negative surface is just as important as the positive pruning cases.

## 9. Local-index and EH repair regressions

The later half of the file has non-obvious regression coverage for:

- v128 params turned into locals
- nested `local.tee` plus `struct.get` use chains
- EH catch-pop localization with nested blocks

These cases are the reason the helper surface matters so much.

## The tests teach four especially important misconceptions to avoid

### Misconception 1: the pass is basically DAE on each function

It is not.
Several tests show that the real decision unit is the nominal heap type shared by multiple functions and `call_ref` users.

### Misconception 2: constant actuals are a bonus optimization after pruning

They are not.
The pass may need constant promotion **before** pruning in order to prove a parameter is dead.

### Misconception 3: localization is just cleanup noise

It is not.
The source and tests both show that some removals happen only because `ChildLocalizer` runs between the two cycles.

### Misconception 4: atomic type rewriting is an implementation detail

It is not.
The test that preserves distinct nominal types after shrinking shows that the type-rewrite strategy is part of the visible contract.

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/SignaturePruning.cpp`
- `src/passes/pass.cpp`
- `src/passes/param-utils.*`
- `src/ir/module-utils.*`
- `src/ir/type-updating.h`
- `src/ir/intrinsics.*`
- `src/ir/possible-constant.h`
- `src/ir/localize.h`
- `test/lit/passes/signature-pruning.wast`

Durable result:

- the checked core pass structure still matches `version_129` on the important reviewed surfaces
- no teaching-relevant drift surfaced in the reviewed owner, registration, helper, or dedicated lit surfaces

That is a narrow freshness note, not a proof that every neighboring helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module-pass entry point, not a HOT pass
- GC + closed-world + no-tables gate behavior
- per-function entry-liveness analysis for parameter usage
- heap-type-level aggregation across sibling functions and `call_ref` users
- public/import/tag/continuation/JS-called/subtyping freeze rules
- constant-actual promotion before pruning
- synchronized removal of parameters from bodies, direct calls, and `call_ref`s
- atomic module-wide signature rewriting
- delayed operand localization and one rerun cycle
- EH nested-pop repair after localization

Any port that implements only the small top-level pass file without helper-equivalent machinery will not match Binaryen's real behavior.

## Bottom line

For `signature-pruning`, the real implementation structure is:

- **small pass file + param-utils machinery + public-type analysis + global type rewriting + one large lit file**

That is exactly why this pass is easy to underestimate from the name alone.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md)
- [`../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md`](../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/cfg/liveness-traversal.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>
