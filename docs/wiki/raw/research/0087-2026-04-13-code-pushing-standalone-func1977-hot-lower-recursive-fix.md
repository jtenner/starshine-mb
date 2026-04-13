# 0087 - `code-pushing` standalone `Func 1977` hot-lower recursive split-wrapper fix

## Context

- Follow-up to [`0084`](./0084-2026-04-13-code-pushing-standalone-func1977-writeback-frontier.md), [`0085`](./0085-2026-04-13-code-pushing-standalone-func1977-suspicious-block.md), and [`0086`](./0086-2026-04-13-code-pushing-standalone-func1977-leaf-suspicious-pairs.md).
- Current-source whitebox replay had already shown that standalone `Func 1977` was no longer blocked by `code-pushing` admission itself; the remaining failure was later lower/writeback fallback with `suspicious-escape-carrier` plus writeback `stack underflow`.
- The mirrored reduced frontier had been localized to the earlier tag-`76` / tag-`77` decode ladders, not the final reopened `LocalSet(45)` / `LocalSet(50)` tail.

## Problem Restatement

The remaining standalone `Func 1977` lower/writeback failure was no longer at the final alias-tail move. The failing lowered function still contained mirrored inner decode-ladder wrappers where a mixed-depth carried branch payload was first rewritten into a split `local.set` wrapper pair and then only partially repaired.

The important concrete validator fact came from validating the rewritten lowered standalone module directly with `wasm-tools`:

- `wasm-tools validate .tmp/codex-tmp/func1977-lowered-after-cp.wasm`
- failure before the fix: `type mismatch: expected i32 but nothing on stack (at offset 0x711)`
- printed offset showed the bad instruction was a `br 3` in the first mirrored tag-`76` family after `local.set 10`, where the target label now expected an `i32` payload.

That meant the issue was not a generic suspicious-carrier false positive by itself. The rewritten branch depth was stale relative to the newly voidified split wrapper shape.

## What The Reduction Showed

Two steps mattered:

1. `hot_lower` already had enough logic to move the old mirrored leaf frontier outward:
   - non-void mixed-depth split payload wrapper tails
   - direct split payload wrapper tails
   - parent-exit payload wrapper tails
   - voidified split `local.set` wrapper pairs
2. But the voidified pair rewrite created a **new** wrapper shape that was not re-run through the later split-wrapper repair helpers.

The concrete missed follow-on was:

- original sibling pair became a single `Block(void, [Block(void, child_body), LocalGet, LocalSet])`
- `child_body` still ended in a mixed positive-depth terminal-branch `if`
- the existing depth-fix helper was only applied while recursively fixing the original children, not the newly synthesized wrapper from the pair rewrite
- so the synthesized wrapper kept the stale deeper `br 3` instead of being re-fixed down to `br 2`

## Landed Fix

### 1. Add a focused helper for the synthesized voidified wrapper

In [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt):

- added `hot_lower_impl_try_fix_voidified_split_local_set_wrapper(...)`
- it recognizes:
  - `Block(void, [Block(void, child_body), LocalGet, LocalSet])`
  - where `child_body` still has mixed positive terminal branch depths
- it rewrites that inner `child_body` with `hot_lower_impl_shift_positive_branch_depths(...)`

### 2. Re-run synthesized pair rewrites through the recursive wrapper fixer

Also in [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt):

- `hot_lower_impl_fix_split_payload_wrappers_in_body(...)` no longer pushes the result of `hot_lower_impl_try_voidify_split_local_set_wrapper_pair(...)` directly
- it now immediately reprocesses that synthesized instruction through
  `hot_lower_impl_fix_split_payload_wrappers_in_instr(...)`

That second step was the missing recursive repair that let the same mixed-depth fixups run on the newly created wrapper, not just on the original children.

### 3. Keep the smaller tail-unpack cleanup

The same worktree also kept two smaller helper refinements that helped narrow the shape before the recursive follow-on fixed the actual validator failure:

- a generalized `hot_lower_impl_try_unpack_parent_exit_payload_wrapper_with_tail(...)`
- rebasing that helper's spliced body with `hot_lower_impl_rebase_body(..., 0)` when removing the immediate typed wrapper

## New In-Tree Coverage

Added focused whitebox coverage in [`src/ir/hot_lower_wbtest.mbt`](../../../../../src/ir/hot_lower_wbtest.mbt):

- non-void split payload tail fix with mixed positive branch depths
- direct split payload wrapper tail fix
- parent-exit payload wrapper tail unpacking
- direct fix for the synthesized voidified split `local.set` wrapper
- recursive proof that `hot_lower_impl_fix_split_payload_wrappers_in_body(...)` now re-fixes a newly voidified split wrapper pair so the stale `br 3` becomes `br 2`

Also updated [`src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt) because one old fallback-only hot-lower case is now valid and no longer needs `skip-invalid-lower`.

## Validation

Focused validation after the landed fix:

- `moon test src/ir -F '*split payload*'`
- `moon test src/ir -F '*voidifying a split local.set wrapper pair*'`
- `moon test src/ir -F '*extracted real carrier with earlier zero-result branch root through parent err block*'`
- `moon test src/ir -F '*reordered real carrier with earlier zero-result branch root*'`
- `moon test src/ir -F '*extracted real carrier with a branch-free crossed gap*'`
- `moon test src/passes`
- `moon test src/cmd/cmd_test.mbt`

Standalone reduced-oracle confirmation:

- `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --code-pushing --out .tmp/codex-tmp/standalone-scan-20260413d/func1977-fixed-check8.wasm .tmp/codex-tmp/standalone-scan-20260413d/func1977.wat`
- before the fix, tracing ended with `pass[code-pushing]:skip-invalid-lower ... reason=suspicious-escape-carrier`
- after the fix, the traced standalone replay completes without `skip-invalid-lower`
- `wasm-tools validate .tmp/codex-tmp/func1977-lowered-after-cp.wasm` now exits `0`

## Durable Conclusion

The standalone `Func 1977` lower/writeback frontier was not a final alias-tail-specific `code-pushing` problem. It was a recursive `hot_lower` repair gap:

- first pass: synthesize a voidified split `local.set` wrapper pair
- missing second pass: re-run mixed-depth split-wrapper repair on that synthesized wrapper

Once that recursive follow-on was restored, the old mirrored tag-`76` / tag-`77` branch-payload underflow disappeared and the standalone `Func 1977` rewrite stopped falling back.

## Remaining Follow-Up

- Refresh the current-tree whole-artifact frontier now that standalone `Func 1977` no longer skips.
- Recheck the remaining standalone `Func 1948` / `Func 509` differences with the same traced and validator-backed approach to determine which ones are still real.
- Re-run the expensive direct artifact compare only when there is enough budget to make the result actionable.
