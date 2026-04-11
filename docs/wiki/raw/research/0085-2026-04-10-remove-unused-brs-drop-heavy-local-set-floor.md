---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../agent-todo.md
---

# 0085 - `remove-unused-brs` drop-heavy raw skip local-set floor

## Scope

- Retire the next unchanged pass-heavy `remove-unused-brs` artifact function after the `Func 3771` parity guard and the earlier typed `br_table` encoder slice.
- Keep the raw skip calibrated to the real artifact body instead of freezing the first reduced-only threshold that happened to satisfy the perf lock.

## Problem

- After the earlier raw drop-heavy ladder draft landed, the focused perf lock was green but the real artifact still showed:
  - `Func 145` lifting
  - `pass[remove-unused-brs]:done changed=false`
- The first raw classifier draft never reported `skip-raw reason=large-drop-heavy-branch-ladder-noop` on the artifact trace.
- That made the slice suspicious:
  - parity looked clean on the reduced lock
  - the real artifact did not prove the classifier was retiring anything useful

## Artifact Readback

- A narrow trace-only probe on the original raw body for `Func 145` measured:
  - `locals=471`
  - `instrs=2583`
  - `calls=329`
  - `local_set=201`
  - `local_tee=270`
  - `if=150`
  - `return=2`
  - `select=0`
  - `br_if=0`
  - `block=102`
  - `loop=2`
  - `br=104`
  - `br_table=0`
  - `drop=98`
- The HOT-only raw guards were both false on the same function:
  - `has_condition_child=false`
  - `has_prefix_guard=false`
- The miss was therefore not a false-positive guard.
- The miss was the strict `local_set_count >= 210` floor from the first draft.

## Change

- Lowered the drop-heavy raw classifier floor from `local_set_count >= 210` to `local_set_count >= 200`.
- Kept the rest of the envelope unchanged:
  - large local footprint
  - no `select`
  - no `br_if`
  - no `br_table`
  - high call / `local.tee` / `if` / `br` / `drop` traffic in the measured artifact band
- The reduced perf lock stays:
  - `remove-unused-brs skips large drop-heavy branch ladders without hot lift`

## Validation

- `moon test src/passes`
  - `435/435` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-drop-heavy-f145-10000`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed1b --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-drop-heavy-f145-2000`
  - `842/842` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures

## Artifact Impact

- Native replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-drop-heavy-final-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
- The traced target is now retired:
  - `Func 145` now reports `skip-raw reason=large-drop-heavy-branch-ladder-noop`
- The traced pass-heavy order after that retirement is now led by:
  - `Func 1382` at `pass=6406 / lift=76692`
  - `Func 96` at `pass=6251 / lift=4230`
  - `Func 788` at `pass=5998 / lift=5027`
  - `Func 1068` at `pass=5996 / lift=4479`

## Full Replay

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-rub-20260410-drop-heavy-f145 --remove-unused-brs`
  - Starshine runtime `2381.544 ms`
  - Binaryen runtime `323.830 ms`
  - Starshine pass runtime `573.182 ms`
  - Binaryen pass runtime `91.702 ms`
  - Starshine pass skipped raw `yes`
  - canonical wasm `no`
  - normalized WAT `no`
- That is still not final parity signoff, but it is a real pass-runtime improvement over the previous saved full replay at `610.426 ms`.

## Remaining Work

- Keep treating the remaining explicit-pass compare noise as suspicious until the trace proves RUB actually mutated the function.
- The next pass-heavy runtime reductions should focus on:
  - `Func 96`
  - `Func 788`
  - `Func 1068`
- Keep the older `Func 1382` path separate because it is still primarily lift-bound even though it remains the largest total hotspot.
