---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md
  - ../../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
---

# Starshine `precompute` strategy today

This page describes the **current in-tree Starshine implementation**, not the full upstream Binaryen `version_129` contract.

## Short version

Starshine currently implements a deliberately narrow HOT-IR `precompute` pass focused on:

- exact i32/i64 unary and binary folds
- exact i32/i64 comparisons to i32 boolean results
- immutable scalar `global.get` replacement
- constant-`if` arm picking
- dead pure-drop cleanup
- some root-region `nop` and empty-block cleanup around rewritten roots
- writeback-safety hardening for the old generated-artifact slot-19 failure family

That is useful and already artifact-tested.

But it is still much smaller than upstream Binaryen.

## What the current descriptor promises

`src/passes/precompute.mbt` describes the pass as:

- `Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots.`

That wording is honest for the current implementation.

It is much narrower than the upstream Binaryen dossier on purpose.

## What the current pass actually does

## 1. Exact scalar folding only

The local pass implements explicit helpers for:

- exact i32 constants
- exact i64 constants
- exact immutable global constants that resolve to scalar or null payloads

Then it folds a specific set of instructions:

### Unary

- `i32.eqz`
- `i64.eqz`

### Binary i32

- `i32.add`
- `i32.sub`
- `i32.mul`
- `i32.and`
- `i32.or`
- `i32.xor`
- `i32.shl`
- `i32.shr_u`
- `i32.shr_s`
- all signed/unsigned i32 comparisons currently listed in `precompute_try_fold_binary(...)`

### Binary i64

- `i64.add`
- `i64.sub`
- `i64.mul`
- `i64.and`
- `i64.or`
- `i64.xor`
- `i64.shl`
- `i64.shr_u`
- `i64.shr_s`
- all signed/unsigned i64 comparisons currently listed there

Important deliberate non-fold today:

- trapping operators like division/remainder are left alone

That matches the test named:

- `precompute preserves trapping exact operators it does not fold`

## 2. Immutable global replacement exists, but only for payloads the local IR already models simply

The pass can fold `global.get` when the module context resolves the global to a constant init.

Today that supports payloads already represented in local HOT builders such as:

- i32
- i64
- f32
- f64
- `ref.null`

String constants are explicitly declined in the current local helper.

So even on globals the local pass is still much smaller than upstream Binaryen's broader string and GC surface.

## 3. Constant-`if` folding is more aggressive locally than upstream `OptimizeInstructions`, but still much narrower than upstream `Precompute`

Starshine's current pass does fold constant `if`s directly.

That includes:

- result `if`s
- void `if`s
- chosen-arm replacement with `nop` fallback when the chosen arm is empty
- rebuilding a result block when the chosen arm has multiple roots

This local behavior is already important to artifact parity and is locked by several focused tests.

But it is still only one small piece of Binaryen's broader precompute family.

## 4. Local root cleanup is bundled into the current pass

The local implementation also includes cleanup that is not the main “evaluate to a constant” story.

Today it can:

- remove dead `drop` of pure values
- simplify empty root `block` / `loop` wrappers into `nop`
- splice constant false void-`if` bodies away inside regions
- trim non-root `nop`s from regions
- coalesce multiple root `nop`s to one
- trim root `nop` prefixes before a trailing final `const`

This is a pragmatic local design choice.
It helps keep rewritten HOT regions clean enough to write back safely.

## 5. The local implementation is iterative, but not Binaryen-shaped

`precompute_run(...)` loops until a round makes no more changes.

Inside each round it does:

1. region-root structural simplification
2. per-node scalar/global/if/drop folding
3. region `nop` trimming
4. root `nop` coalescing
5. root-prefix-before-trailing-const cleanup

That is a useful local fixpoint.

But it is **not** the same phase structure as upstream Binaryen, which has:

- main semantic compile-time evaluation
- optional partial-select precompute
- optional `LazyLocalGraph` propagation
- then refinalization

So even when the pass names align, the internal algorithm still does not.

## What Starshine does **not** implement yet

## 1. No `precompute-propagate` mode today

The biggest missing upstream surface is the explicit propagate variant.

Starshine currently exposes only one public pass name:

- `precompute`

It does **not** yet implement the Binaryen split between:

- plain `precompute`
- `precompute-propagate`

That means the repo still lacks:

- `LazyLocalGraph`-based constant propagation through locals
- the extra rerun of the main walk after propagation
- the stronger aggressive/nested-rerun semantics Binaryen uses in `-O4z`-style and optimize-after-inlining contexts

## 2. No general compile-time interpreter model

The local pass is mostly a direct pattern matcher over current HOT nodes.

It does **not** yet model Binaryen's broader interpreter behavior for:

- breaks / returns as general `Flow`
- tuple/multivalue constant execution beyond today's narrow cases
- stack-switching instruction boundaries
- general reference-typed value evaluation
- the richer child-retention logic used upstream when speculative evaluation walked through local/global writes

## 3. No partial-select precompute

The local pass does not implement Binaryen's separate upward partial-precompute algorithm that pushes parent operations into `select` arms.

So all of these upstream families are still missing locally:

- `i32.eqz(select(...)) -> select(const, const, cond)`
- binary op over select arms becoming constant arms
- multi-parent stack climbs through `select`
- the temporary heap-cache rule for speculative partial-precompute attempts

## 4. No GC identity cache or immutable-GC propagation

The local pass does not yet implement the upstream heap-identity story.

Missing upstream surfaces include:

- identity-aware `ref.eq` reasoning
- immutable struct-field propagation
- immutable array-element propagation
- nested immutable object / global-held vtable propagation
- array length propagation in the wider upstream sense
- descriptor-sensitive GC precompute families
- the emitability boundary for known-but-non-emittable non-null GC refs

## 5. No string precompute surface

Missing upstream string families include:

- `string.eq`
- `string.concat`
- `string.measure_wtf16`
- `stringview_wtf16.get_codeunit`
- valid UTF-16 string slicing
- immediate-child `string.new_wtf16_array`
- propagation of constant string locals / globals

## 6. No SIMD / relaxed-SIMD distinction

The local pass does not currently model Binaryen's wider deterministic SIMD precompute or its deliberate no-fold boundary for relaxed SIMD.

## 7. No atomic-order-aware GC get rules

The local pass does not yet model Binaryen's distinction between:

- unordered GC gets
- acqrel gets on unshared heaps
- preserved seqcst / shared synchronization cases

## Why the local writeback guards still matter

## The old slot-19 witness was real

The retired generated-artifact note `0096` captured a real earlier failure:

- direct `--precompute` replay emitted invalid raw wasm
- `func 108` lost a required `i32` result

That was not a synthetic unit test mistake.
It was an actual ordered-artifact corruption witness.

## The current tree keeps the replay safe

The follow-up note `0105` records that the same predecessor now replays cleanly and validates.

The local hardening surfaces most directly tied to that retirement are:

- `src/passes/pass_manager.mbt`
  - precompute-specific invalid-escape-carrier detection
  - precompute-specific writeback validation error reporting
- `src/passes/precompute_test.mbt`
  - focused structured branch-exit validity regression
  - full-module call-target validation regression
- `src/cmd/cmd_wbtest.mbt`
  - saved slot-19 predecessor replay
  - extracted `func 108` replay
  - debug-artifact replay

So the current local precompute story is:

- still narrower than Binaryen semantically
- but much stronger than the old landing page admitted on artifact safety and replay regression coverage

## Current scheduler surface in Starshine

The local optimize preset intentionally replays `precompute` in both visible `PC` slots.

That is locked by tests in `src/passes/optimize_test.mbt` for both:

- `optimize`
- `shrink`

So the repo already models the visible top-level slot count honestly.

What it does **not** yet model is the upstream mode split or nested propagate behavior.

## Practical mapping for future work

A future honest Starshine expansion should probably happen in this order:

1. keep the existing scalar/top-level pass correct and artifact-safe
2. separate the concept of plain `precompute` from `precompute-propagate`
3. add a proper constant-propagation substrate for locals
4. add partial-select precompute only after that substrate exists
5. add GC identity and immutable-GC reasoning only with a clear emitability boundary
6. add string / SIMD / atomic-order surfaces later, not by pretending they are just more arithmetic cases

That order matches the real upstream shape better than simply adding more scalar fold opcodes to the current file.

## Bottom line

Starshine today has a useful, tested, and artifact-hardened `precompute` pass.

But it is still best described as:

- **exact scalar HOT folding plus structural cleanup and writeback safety work**

not as:

- a full port of Binaryen `version_129` `precompute` / `precompute-propagate`

The dossier pages in this folder are meant to keep that difference explicit.
