# 0266 - Generated `-O4z` slot 43 `precompute` rooted continuation retired by HOT-lower carried-prefix label guard

## Status

- Date: 2026-04-23
- Type: Follow-up retirement note
- Retires the remaining live blocker in the rooted continuation chain under `.tmp/o4z-post-5d2fd48/current-chain/`
- Earlier related `precompute` retirement: [0105 - Generated `-O4z` slot 19 `precompute` replay is now retired](./0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md)
- Earlier related HOT-lower guards:
  - [0103 - Generated `-O4z` slot 16 `optimize-instructions` `Func 652` carrier-wrapper guard follow-up](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
  - [0104 - Generated `-O4z` slot 16 `optimize-instructions` `Func 1818` split parent-exit payload guard](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)
- Shared ordered-audit context: [0093 - Generated `cmd.wasm` ordered `-O4z` pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)

## Scope

- Rooted continuation chain: `.tmp/o4z-post-5d2fd48/current-chain/`
- Live blocker before this fix: slot `43`
- Observed Binaryen pass family: later `precompute` / `precompute-propagate` replay position
- Starshine pass: `--precompute`
- Fixed replay directory: `.tmp/o4z-post-5d2fd48/current-chain/slot43-precompute-continued-2026-04-22b/`
- Extracted witnesses:
  - stable check: `.tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f2754-recheck-out.wasm`
  - fixed former blocker: `.tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f3867-after-fix-out.wasm`
- Implemented fix: `src/ir/hot_lower.mbt`
- Focused regression: `src/ir/hot_lower_test.mbt`

## Failure recap before the fix

After slot `42` (`merge-blocks`) was already retired and the first extracted slot-43 witness (`func 2754`) stayed green, the rooted continuation still had one remaining live blocker in extracted `func 3867`.

Observed failing symptoms before the fix:

- full slot-43 continued replay failed validation in `func 3867`
- validator message:
  - `type mismatch: expected i32 but nothing on stack`
- full replay offset:
  - `0x1a3a8b`
- extracted witness failure:
  - `func 15 failed to validate`
  - same validator message at offset `0x1024`
- localized mismatch against Binaryen:
  - Starshine lowered one nested exit as `br 3`
  - Binaryen kept the corresponding exit as `br 2`

That evidence again pointed at branch-depth corruption introduced during HOT lowering rather than at a pass-local `precompute` fold mismatch.

## Root cause

The bad rewrite was again in `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` in `src/ir/hot_lower.mbt`.

This was **not** the earlier slot-19 `precompute` writeback-validation family from [0105](./0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md), and it was also **not** a new `precompute` algorithm bug.

The remaining rooted slot-43 blocker came from a narrower HOT-lower stackification case:

- a wrapped carried-local / typed-wrapper prefix was being stackified
- the source local itself did **not** need to be rewritten in the failing shape
- but a doubly nested child branch still targeted the carried-prefix block's **own** label
- inserting the new typed wrapper shifted that nested branch depth
- the resulting Starshine output used `br 3` where Binaryen still used `br 2`
- the rebased branch then landed on a typed carrier without the required `i32` payload, producing the final validation underflow

So the real missing conservatism was broader than the earlier “removed enclosing label” check: stackification also has to refuse cases where deeper children still target the carried-prefix block's **own** label.

## Fix

The landed guard change keeps `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` from stackifying a wrapped `local.set` prefix when a doubly nested child exit still targets the carried-prefix block's own label, even if the source local is not rewritten.

In practice that means the lowerer now preserves the older void wrapper shape in this family instead of inserting a new typed carrier block that would shadow the still-live nested target depth.

New focused regression added in `src/ir/hot_lower_test.mbt`:

- `hot lower keeps wrapped local.set prefixes void when a doubly nested child exit still targets the carried-prefix block without rewriting the source local`

## Validation after the fix

Already-confirmed focused validations for this fix family:

- `moon test --target native --package jtenner/starshine/ir --file hot_lower_test.mbt`
- `moon build --target native --release --package jtenner/starshine/cmd`

Current 2026-04-23 revalidation of the relevant rooted-chain outputs:

- `wasm-tools validate .tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f2754-recheck-out.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f3867-after-fix-out.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot43-precompute-continued-2026-04-22b/starshine.raw.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot44-optimize-instructions-continued-2026-04-22b/starshine.raw.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot45-heap-store-optimization-continued-2026-04-22b/starshine.raw.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot47-vacuum-continued-2026-04-22b/starshine.raw.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot50-duplicate-function-elimination-continued-2026-04-22b/starshine.raw.wasm`
- `wasm-tools validate .tmp/o4z-post-5d2fd48/current-chain/slot53-remove-unused-module-elements-continued-2026-04-22b/starshine.raw.wasm`

Observed result:

- extracted `func 2754` remains green
- extracted `func 3867` is now green
- fixed slot-43 continued replay validates
- downstream continued implemented slots `44`, `45`, `47`, `50`, and `53` also validate green
- no new live validation blocker was exposed in the remaining implemented continuation chain

## Durable takeaways

- The remaining rooted slot-43 blocker was a real HOT-lower branch-depth corruption family, not evidence that the `precompute` pass itself still has an open structural rewrite bug.
- The earlier carrier-wrapper lesson from [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) and [0104](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md) generalizes further: any lowering that inserts a new typed carrier under a wrapped prefix must prove that deeper children no longer target either the removed enclosing label **or** the carried-prefix block's own label.
- For follow-up work, this chain should now be treated as a verification / closure thread rather than an active slot-43 corruption triage thread.

## Files changed in this slice

- `src/ir/hot_lower.mbt`
- `src/ir/hot_lower_test.mbt`

## Supporting evidence

- Rooted chain index: `.tmp/o4z-post-5d2fd48/current-chain/`
- Fixed slot-43 continued replay: `.tmp/o4z-post-5d2fd48/current-chain/slot43-precompute-continued-2026-04-22b/`
- Slot-43 continued run log: `.tmp/o4z-post-5d2fd48/current-chain/slot43-precompute-continued-2026-04-22b.run.log`
- Green downstream continued logs:
  - `.tmp/o4z-post-5d2fd48/current-chain/slot44-optimize-instructions-continued-2026-04-22b.validate.log`
  - `.tmp/o4z-post-5d2fd48/current-chain/slot45-heap-store-optimization-continued-2026-04-22b.validate.log`
  - `.tmp/o4z-post-5d2fd48/current-chain/slot47-vacuum-continued-2026-04-22b.validate.log`
  - `.tmp/o4z-post-5d2fd48/current-chain/slot50-duplicate-function-elimination-continued-2026-04-22b.validate.log`
  - `.tmp/o4z-post-5d2fd48/current-chain/slot53-remove-unused-module-elements-continued-2026-04-22b.validate.log`
- Fixed witness output: `.tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f3867-after-fix-out.wasm`
- Stable witness recheck output: `.tmp/o4z-post-5d2fd48/repros/o4z-slot43-precompute-f2754-recheck-out.wasm`
- Implemented guard site: `src/ir/hot_lower.mbt`
- Regression lock: `src/ir/hot_lower_test.mbt`
