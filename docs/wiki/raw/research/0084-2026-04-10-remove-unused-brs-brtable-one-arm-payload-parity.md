---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../agent-todo.md
---

# 0084 - `remove-unused-brs` `br_table` one-arm payload parity guard

## Scope

- Determine how Binaryen handles the remaining explicit-pass parity failure reduced from `Func 3771`.
- Fix that mismatch without reopening the earlier `br_table` continuation-wrapper slice.
- Recover the runtime lost by the first correct guard draft.

## Problem

- The failing artifact `.tmp/self-opt-rub-20260410-compare-next/binaryen.nop20.wasm` still reduced to an invalid Starshine output:
  - `final module validate: br_table target labels have different argument types`
  - traced to `(Func 3771)`
- The offending Starshine mutation was the direct one-arm payload branch cleanup in `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)`.
- The surrounding function also contained a separate `br_table`, so the rewritten control graph mixed label arities in a way Binaryen never emitted on that family.

## Binaryen Behavior

- The reduced fixture now locked in `src/passes/remove_unused_brs_test.mbt` shows the important rule:
  - if the function contains a `br_table`, Binaryen keeps the later direct one-arm payload branch `if`
  - it does not lower that family to `drop(br_if ...)`
- This is a negative parity boundary, not a missing continuation-wrapper rewrite.
- The earlier `br_table` continuation-wrapper fix from `0076` still stands; the new failure is a separate direct payload-branch family.

## Change

- `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)` now bails out when the function contains any `br_table`.
- The focused regression is `remove-unused-brs keeps one-arm payload branch ifs in br_table functions`.
- The first working draft found `func_has_br_table` with a second whole-function HOT walk.
- The landed version folds that boolean into `remove_unused_brs_compute_branch_payload_children(...)`, which now returns:
  - `branch_payload_children`
  - `has_br_table`
- That keeps the parity guard cheap enough to preserve more of the artifact runtime recovery.

## Rejected Boundary

- A temporary guard in `hot_lower` was not the right fix.
- The invalid output came from RUB mutating the function into a shape Binaryen does not emit, not from lowering a correct HOT graph incorrectly.
- The lowering experiment was removed instead of shipping two partial guards for the same root cause.

## Validation

- `moon test src/passes`
  - `434/434` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-brtable-onearm-guard-10000`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed23 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-brtable-onearm-guard-2000`
  - `834/834` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures
- `_build/native/release/build/cmd/cmd.exe --debug-serial-passes --remove-unused-brs --out /tmp/rub-f3771-piggyback-verify.wasm .tmp/self-opt-rub-20260410-compare-next/binaryen.nop20.wasm`
  - exits `0`

## Runtime Impact

- The first parity guard draft regressed the full self-opt compare because it added a second whole-function scan.
- The piggyback follow-up recovered most of that cost on `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-rub-20260410-brtable-onearm-guard-piggyback --remove-unused-brs`:
  - Starshine pass time `680.151 ms -> 610.426 ms`
- The compare is still not exact:
  - canonical wasm `no`
  - normalized WAT `no`
- The first checked remaining hunk in `func $384` is not a RUB mutation:
  - the traced explicit replay still reports `changed=false`

## Remaining Work

- Keep treating later explicit-pass diffs as suspicious until the trace proves RUB actually mutated the function.
- The next runtime reduction should target the unchanged pass-heavy self-opt families from the fresh trace:
  - `Func 96`
  - `Func 788`
  - `Func 145`
- The older `Func 1382` trace is still useful, but it remains mostly lift-bound rather than a clean pass-walk hotspot.
