---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-26-signature-pruning-port-readiness-primary-sources.md
  - ../../../raw/research/0404-2026-04-26-signature-pruning-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md
  - ../../../raw/research/0470-2026-05-05-signature-pruning-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../signature-refining/starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/index.md
---

# Starshine port readiness and validation for `signature-pruning`

Use this page as the implementation bridge between Binaryen's source-backed `signature-pruning` contract and Starshine's current boundary-only status.
The 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md) repeated the same narrow source-level check and found no teaching-relevant drift.
The pass is still unimplemented locally; this page exists so a future port starts with the right module/type rewrite shape instead of a misleading HOT peephole.

## Current local decision

Keep `signature-pruning` boundary-only until Starshine can run a closed-world module pass that updates all of these surfaces together:

- function heap types and their nominal declarations;
- function section / imported-function type references;
- callee parameter locals and body expressions;
- direct `call` and `return_call` actual lists;
- `call_ref` and `return_call_ref` type immediates and operands;
- validator and binary round-trip behavior after the type rewrite.

The current registry behavior is therefore correct:

- [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139) keeps `signature-pruning` in `pass_registry_boundary_only_names()`.
- [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263) omits it from the active `optimize` / `shrink` presets.
- [`src/passes/optimize.mbt#L455-L470`](../../../../../src/passes/optimize.mbt#L455-L470) rejects explicit boundary-only requests instead of silently no-oping.

## Why direct-call DAE is not enough

The tempting first implementation is: find an unused parameter, remove it from the function body, and delete one actual from each direct call.
That is not Binaryen parity.

Binaryen decides by **nominal function heap type**:

- all functions with the same heap type share one pruning decision;
- all direct calls to those functions must be updated;
- all `call_ref` uses of that heap type must also be updated;
- distinct heap types remain distinct even if pruning makes their shapes textually identical;
- the type graph is rewritten atomically after body/call-site edits.

So the smallest honest Starshine port is still module-wide.
A direct-call-only first slice is acceptable only if it is explicitly scoped to a private, non-shared, non-public function heap type and keeps every unsupported family as a no-op.

## Safe first mutating slice

A conservative first slice should require all of the following:

- GC-aware type-section parsing and validation are available;
- an explicit closed-world mode exists and is required;
- the module has no tables;
- the candidate function heap type is private and not exported, imported, tag-used, continuation-used, JS-called, or subtyped;
- exactly the functions using that heap type are in the module and all are analyzable;
- the first slice ignores `call_ref` unless direct text/binary fixtures are ready;
- only direct `call` / `return_call` users are rewritten;
- entry-liveness proves the incoming parameter value is dead in every sibling function;
- the pass can remove the parameter from the function type, function locals, and every direct actual list in one transaction;
- validation succeeds after every rewrite.

A minimal positive should look like:

```wat
;; before
(type $t (func (param i32 i64) (result i32)))
(func $f (type $t) (param $dead i32) (param $live i64) (result i32)
  local.get $live
  i32.wrap_i64)
(func $g (result i32)
  i32.const 10
  i64.const 20
  call $f)

;; after, preserving the nominal type rewrite consistently
(type $t (func (param i64) (result i32)))
(func $f (type $t) (param $live i64) (result i32)
  local.get $live
  i32.wrap_i64)
(func $g (result i32)
  i64.const 20
  call $f)
```

The important point is that the removed `i32.const 10` is an argument shell, not an independently useful expression.
If the dropped actual has effects, the first slice should refuse it or preserve effects by an explicit localization/drop strategy with tests.

## Must-stay-negative first-slice families

Keep these families as no-op or boundary-only until each has a source-backed local design:

- imported function types;
- exported or otherwise public function heap types;
- any table or indirect-call-mediated use;
- `call_ref` / `return_call_ref` until the fixture and type-immediate rewrite path is proven;
- tags and continuations using the signature;
- `call.without.effects` and JS-call intrinsics;
- function type subtyping relationships;
- constant-actual promotion;
- delayed operand localization and second-cycle pruning;
- multiple nominal heap types that would become textually identical after pruning.

These are not polish. They are the families Binaryen explicitly treats as blockers or separate source phases.

## Local code surfaces to inspect before implementation

### Registry and dispatch

- [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139) - boundary-only name list.
- [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268) - boundary-only registry entry construction.
- [`src/passes/optimize.mbt#L455-L470`](../../../../../src/passes/optimize.mbt#L455-L470) - active request rejection.

### Type and call representation

- [`src/lib/types.mbt#L98-L105`](../../../../../src/lib/types.mbt#L98-L105) - typed `TypeIdx` and `FuncIdx` indices.
- [`src/lib/types.mbt#L147-L168`](../../../../../src/lib/types.mbt#L147-L168) - subtype / rec-group representation relevant to public and subtype blockers.
- [`src/lib/types.mbt#L416-L433`](../../../../../src/lib/types.mbt#L416-L433) - `FuncType`, `TypeSec`, and `FuncSec` rewrite surfaces.
- [`src/lib/types.mbt#L525-L532`](../../../../../src/lib/types.mbt#L525-L532) - `Call`, `CallIndirect`, `ReturnCall`, `ReturnCallIndirect`, `CallRef`, and `ReturnCallRef` instruction variants.

### Validation

- [`src/validate/env.mbt#L179-L190`](../../../../../src/validate/env.mbt#L179-L190) - type-index-to-function-type resolution.
- [`src/validate/env.mbt#L332-L340`](../../../../../src/validate/env.mbt#L332-L340) - function type and original type-index lookup.
- [`src/validate/typecheck.mbt#L894-L956`](../../../../../src/validate/typecheck.mbt#L894-L956) - direct, indirect, and `call_ref` call validation.
- [`src/validate/typecheck.mbt#L990-L1049`](../../../../../src/validate/typecheck.mbt#L990-L1049) - tail-call-family validation.

### Binary and WAT fixtures

- [`src/binary/decode.mbt#L2568-L2575`](../../../../../src/binary/decode.mbt#L2568-L2575) - binary `call_ref` / `return_call_ref` decode with `TypeIdx` immediates.
- [`src/binary/encode.mbt#L2032-L2040`](../../../../../src/binary/encode.mbt#L2032-L2040) - corresponding encode path.
- [`src/wast/parser.mbt#L1875-L1890`](../../../../../src/wast/parser.mbt#L1875-L1890) - current visible type-use-bearing call-family text parser surface includes `return_call_ref`.
- [`src/wast/lower_to_lib.mbt#L1934-L1981`](../../../../../src/wast/lower_to_lib.mbt#L1934-L1981) - lowerer surface for type-use-bearing indirect and return-call-ref forms.

Caveat: before writing direct `call_ref` text fixtures for this pass, verify the direct `call_ref` parser/lowerer path or use library/binary fixtures.

## Validation ladder

1. **Registry honesty**
   - keep the current boundary-only rejection until a mutating module pass exists;
   - add a registry test when moving the pass out of boundary-only.
2. **No-op gates**
   - no GC;
   - no closed-world mode;
   - module has any table;
   - candidate type is imported, exported/public, tag-used, continuation-used, JS-called, or subtype-linked.
3. **Direct-call first positives**
   - one dead middle parameter removed;
   - first and last parameter removed;
   - all parameters removed;
   - overwritten incoming parameter counts dead by entry liveness.
4. **Sibling heap-type aggregation**
   - two functions share one heap type and both agree a param is dead;
   - one sibling uses the param and blocks removal for the whole family.
5. **Effect and constant boundaries**
   - effectful dropped actual is refused or localized explicitly;
   - constant-actual promotion remains disabled until implemented, then gets its own tests.
6. **`call_ref` slice**
   - direct `call_ref` type immediates and operand lists update together;
   - `return_call_ref` matches the same rule;
   - WAT fixture support is verified or binary fixtures cover it.
7. **Binaryen oracle comparison**
   - compare focused fixtures with `wasm-opt --closed-world --signature-pruning`;
   - only then add fuzz lanes or broad pass-comparison harness support.

## Health rule for future edits

When `signature-pruning` becomes implemented, update all of these together:

- this page;
- [`./index.md`](./index.md);
- [`./starshine-strategy.md`](./starshine-strategy.md);
- [`../tracker.md`](../tracker.md);
- [`../index.md`](../index.md);
- [`../../../index.md`](../../../index.md);
- [`../../../log.md`](../../../log.md);
- `CHANGELOG.md`.

Do not let the page keep saying boundary-only after the registry category changes.
