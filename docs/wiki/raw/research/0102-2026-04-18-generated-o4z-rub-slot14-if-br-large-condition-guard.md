# 0102 - Generated `-O4z` slot 14 `remove-unused-brs` fixed by guarding large non-reorder-safe `if br` rewrites

## Status

- Date: 2026-04-18
- Type: Fix note
- Resolves: `[O4Z]001`
- Prior notes:
  - [0094 - slot 14 early `remove-unused-brs` invalid raw output](./0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md)
  - [0101 - slot 14 native/source divergence](./0101-2026-04-18-generated-o4z-rub-slot14-native-source-divergence.md)

## Scope

Narrow and fix the early ordered generated-artifact `remove-unused-brs` corruption on the saved slot-13 predecessor:

- predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- failing extracted function: `Func 1354`
- Starshine pass surface: `src/passes/remove_unused_brs.mbt`
- regression surface: `src/cmd/cmd_wbtest.mbt`

## What was reproduced

The direct native replay still reproduced the original invalid raw output before the fix:

- `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot14.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- `wasm-tools validate .artifacts/tmp-direct-rub-slot14.raw.wasm`

The failure remained:

- `func 1354 failed to validate`
- `type mismatch: expected i32 but nothing on stack`

A focused extracted replay also failed the same way:

- `--extract-functions=1354 --remove-unused-brs`
- `wasm-tools validate` on the emitted module failed at extracted `func 0`

## Oracle Binaryen behavior

A reduced extracted replay against oracle Binaryen showed the intended behavior clearly.

1. Extract the same function from the saved predecessor.
2. Run Binaryen `wasm-opt --remove-unused-brs --all-features` on that extracted module.
3. Compare `wasm-tools print` output.

Binaryen kept the critical carrier as a plain `block` and rewrote the one-armed branch guard to a direct `br_if` plus fallthrough payload work:

- `block ;; label = @7`
- `... i64.eq`
- `br_if 2 (;@5;)`
- `local.get 72`
- `i32.wrap_i64`
- `local.set 17`
- `br 0 (;@7;)`

Starshine's invalid output instead came from wrapping that carried region under a new value block shape, which changed the effective relative-depth context seen by the nested branch and produced the missing-`i32` validator failure.

## Exact mutator narrowed

The reproducing mutation came from `remove_unused_brs_try_rewrite_if_br(...)`.

Temporary localization showed:

- disabling that helper alone made the extracted replay validate again
- the offending candidate was a plain-`br` one-armed `if`
- the condition for that `if` was **not reorder-safe** on the extracted slot-14 function
- the extracted function had `397` HOT nodes, so this was a large carried-condition case rather than a tiny canonical nested-`if` cleanup

## Landed fix

Starshine now refuses the plain-`br` `if -> br_if` rewrite in `remove_unused_brs_try_rewrite_if_br(...)` when both of these are true:

- the lifted function is large (`hot_node_count >= 256`)
- the outer `if` condition is not reorder-safe

This keeps the small canonical nested-condition cleanups active, but preserves the original large carried-condition shape that Binaryen already handles safely on the slot-14 extracted function.

## Why this fix is acceptable

This is a conservative correctness guard, not a claim that the underlying large-condition rewrite can never be implemented.

It is acceptable for this slice because:

- Binaryen already produces a valid output on the same extracted oracle input without needing Starshine's aggressive rewrite here
- the previous Starshine rewrite emitted invalid wasm on the real generated-artifact replay lane
- the existing focused small-condition `if br -> br_if` tests still pass, so the guard is narrowly scoped to the large complex family that caused the corruption

## Regression coverage

Added a native cmd wbtest that locks the previously-missed external validity surface:

- `run_cmd_with_adapter keeps extracted generated O4z slot14 remove-unused-brs output wasm-tools-valid`

That test replays the saved predecessor fixture through:

- `--extract-functions=1354`
- `--remove-unused-brs`

and then validates the emitted bytes with `wasm-tools validate` instead of only decoding them through the in-tree parser.

## Validation run

- `moon test --target native src/passes/remove_unused_brs_test.mbt --filter '*nested*if*branch*'`
- `moon test --target native --package jtenner/starshine/cmd --filter '*slot14*wasm-tools-valid*'`
- `moon build --target native --release --package jtenner/starshine/cmd`
- `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot14.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- `wasm-tools validate .artifacts/tmp-direct-rub-slot14.raw.wasm`

All of the above were green after the fix.

## Files touched

- `src/passes/remove_unused_brs.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `docs/wiki/raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/branch-exit-and-payload-rewrites.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`
- `agent-todo.md`
- `CHANGELOG.md`

## Remaining follow-up

`[O4Z]001` is fixed, but the later ordered `remove-unused-brs` corruption at slot `40` remains open and still needs its own reduction and oracle comparison.
