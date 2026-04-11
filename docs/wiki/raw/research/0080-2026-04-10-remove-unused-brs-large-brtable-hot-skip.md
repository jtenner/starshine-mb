---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../agent-todo.md
---

# 0080 - `remove-unused-brs` large `br_table` hot skip

## Scope

- Retire the next unchanged `remove-unused-brs` artifact hotspot family after the raw large-dispatch skip and the mid-band unique tee-floor correction.
- Keep the wiki aligned with the actual traced debug artifact rather than the earlier mistaken `Func 1171` versus `Func 1150` attribution.

## Problem

- After the tee-floor slice, the native artifact trace at `.tmp/rub-trace-mid-unique-tee16-idle.stderr` still showed two expensive unchanged functions:
  - `Func 1058` / `parse__opcode__instruction` at `pass=15540 / lift=8114`
  - `Func 1150` / `wt__lower__module` at `pass=15707 / lift=15431`
- Both functions paid full lift plus full HOT traversal, then reported `changed=false`.
- The trace also showed that this was not the old raw prefix-guard problem:
  - `Func 1150` still failed inside the lifted result-prefix matcher as `rub-result-prefix reject=inner-op block=2923 op=LocalSet`
  - the raw WAT for both large functions contained no explicit `br_if`

## Reduced Perf Lock

- Added `perf_test_make_large_br_table_return_ladder_hot_skip_module(...)` in `src/passes/perf_test.mbt`.
- Added perf lock `remove-unused-brs skips large br_table return ladders after lift`.
- The reduced lifted shape used to calibrate the hot classifier was:
  - `locals=162`
  - `roots=74`
  - `nodes=760`
  - `calls=144`
  - `local_set=73`
  - `local_tee=36`
  - `void_if=72`
  - `value_if=0`
  - `return=36`
  - `select=0`
  - `br_if=0`
  - `block=115`
  - `loop=0`
  - `br=5`
  - `br_table=1`
  - `drop=36`

## Change

- Extended the lifted no-op shape scan in `src/passes/remove_unused_brs.mbt` to count:
  - `br_table`
  - `drop`
- Added `remove_unused_brs_can_skip_large_br_table_return_ladder(...)`.
- The new hot skip recognizes large lifted families with:
  - no `br_if`
  - at least one `br_table`
  - dense `if` / `return` traffic
  - enough calls and local traffic to make the walk expensive
- The reason emitted by the pass is `skip-hot reason=large-br-table-return-ladder-noop`.
- The final working envelope needed a wider lifted `block_count` ceiling (`<= 800`) than the first attempt, because lifted block counts were materially higher than the raw printed WAT suggested.

## Validation

- `moon fmt`
- `moon test src/passes`
  - `428/428` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-large-brtable-hotskip-10000-serial`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed15 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-large-brtable-hotskip-2000`
  - `848/848` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures

## Artifact Impact

- Native replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-large-brtable-hotskip-v2-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
- Total traced cost improved from `.tmp/rub-trace-mid-unique-tee16-idle.stderr` to `.tmp/rub-trace-large-brtable-hotskip-v2-idle.stderr`:
  - pass total `682234 us -> 654407 us`
  - lift total `963261 us -> 917148 us`
- The real unchanged hotspot pair is now retired:
  - `Func 1058` now reports `skip-hot reason=large-br-table-return-ladder-noop` with `pass=450 / lift=6387`
  - `Func 1150` now reports the same reason with `pass=1054 / lift=16635`
- The family also catches `Func 71`.

## Remaining Work

- The next runtime work is no longer obviously a RUB result-prefix family.
- The updated trace shifts the visible top pass hotspots to:
  - `Func 828`
  - `Func 356`
- The lift-dominant side is now led by:
  - `Func 1382`
  - `Func 1482`
- The next reduction should keep pass-walk cost and pure lift cost separate before widening more RUB-specific no-op classifiers.
