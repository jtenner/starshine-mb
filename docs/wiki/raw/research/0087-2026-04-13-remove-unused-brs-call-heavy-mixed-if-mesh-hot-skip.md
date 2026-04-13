---
kind: research
status: completed
last_reviewed: 2026-04-13
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/cmd/cmd_test.mbt
  - ../../../../agent-todo.md
---

# 0087 - `remove-unused-brs` call-heavy mixed-if mesh hot skip

## Scope

- Retire the next post-`0086` unchanged HOT-walk family on the canonical debug artifact.
- Keep the detector calibrated on lifted summary counts from the checked-in artifact instead of raw WAT intuition alone.
- Preserve exact RUB parity by only retiring extracted functions that still compare canonically equal to Binaryen.

## Problem

After the earlier `medium-branchy-block-ladder-noop` slice, the canonical debug artifact still had a second lifted unchanged family that paid lift plus a full HOT walk before exiting `changed=false`.

Representative artifact functions in that family were:

- `Func 408` / `run__hot__pipeline__func`
- `Func 413` / `run__hot__pipeline__raw__rewrite__instrs`
- `Func 739` / `hot__lower__impl__emit__instruction`
- `Func 832` / `hot__lift__impl__build__exact__node`
- `Func 902` / `cfg__builder__process__block`
- `Func 1022` / `spec__check__command`
- `Func 1448` / `SubType.Decode.decode`
- `Func 1815` / `validate__typecheck__if`

This family was different from the earlier medium-branchy skip:

- more mixed void/value `if` traffic
- lower plain `br` density
- more lifted block shells than the printed WAT first suggested
- no `br_table` surface and almost no `select` / `br_if` traffic

The traced aggregate cost was large enough to matter even though every checked function still ended `changed=false`.

## Lifted Shape Envelope

Tracing the real artifact and collecting lifted summaries showed the retired family clustering inside this HOT envelope:

- locals: `194..612`
- roots: `2..52`
- nodes: `1167..3120`
- calls: `102..622`
- `local.set`: `92..319`
- `local.tee`: `77..288`
- void `if`: `9..84`
- value `if`: `5..68`
- total `if`: `53..130`
- `return`: `3..17`
- `select`: `0..1`
- `br_if`: `0..1`
- blocks: `95..221`
- loops: `0..5`
- plain `br`: `13..46`
- `br_table`: `0`
- `drop`: `0..81`

The important lesson from this slice is that the lifted block counts were much higher than the original printed-WAT guess. The detector was only stable after calibrating on the lifted summary, not on raw function text alone.

## Change

- Added `remove_unused_brs_can_skip_call_heavy_mixed_if_mesh(...)` in `src/passes/remove_unused_brs.mbt`.
- Hooked it into `remove_unused_brs_run(...)` with the trace reason:
  - `skip-hot reason=call-heavy-mixed-if-mesh-noop`
- Kept the new detector after the earlier `medium-branchy-block-ladder-noop` gate so the old slice keeps its existing reason and coverage.
- Added a native artifact-backed regression in `src/cmd/cmd_test.mbt`:
  - `run_cmd_with_adapter traces remove-unused-brs call-heavy mixed-if mesh hot skip on extracted debug artifact func 408`

## Validation

- `moon fmt`
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`
  - `91/91` passed
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter traces remove-unused-brs medium branchy hot skip on extracted debug artifact func 1547'`
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter traces remove-unused-brs call-heavy mixed-if mesh hot skip on extracted debug artifact func 408'`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 200 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-200-after-call-heavy-mixed-if-mesh`
  - `200/200` compared
  - `0` mismatches
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 120 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-mixed-120-after-call-heavy-mixed-if-mesh`
  - `119/119` compared clean before the usual Binaryen-side parser failure
  - `0` mismatches

Extracted single-function compare replays for the checked family also stayed oracle-clean with `Normalized WAT equal: yes` and `Canonical function compare equal: yes`, including:

- `Func 408`
- `Func 413`
- `Func 739`
- `Func 832`
- `Func 902`
- `Func 1022`
- `Func 1448`
- `Func 1815`

## Perf Impact

A fresh native trace on the exact canonical artifact now retires these eight functions under the new hot skip:

- `Func 408`
- `Func 413`
- `Func 739`
- `Func 832`
- `Func 902`
- `Func 1022`
- `Func 1448`
- `Func 1815`

Interleaved five-pair self-opt compare reruns on `tests/node/dist/starshine-debug-wasi.wasm` show a modest but repeatable improvement for this slice.

- command:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs`
- interleaved averages:
  - baseline: `458.1108 ms`
  - current: `445.551 ms`
  - delta: `-12.5598 ms` (`-2.7417%`)
- interleaved medians:
  - baseline: `458.721 ms`
  - current: `436.74 ms`
  - delta: `-21.981 ms` (`-4.7918%`)

## Remaining Work

This slice clears the next unchanged HOT-walk family but does not close the full RUB gap.

After the new skip, the still-visible unchanged leaders are now headed by:

- `Func 3021`
- `Func 497`
- `Func 1168`
- `Func 1213`
- `Func 990`
- `Func 3130`
- `Func 1063`
- `Func 105`
- `Func 3134`

The next likely follow-up should keep separating:

- no-op pass-heavy families that want another narrow lifted classifier
- lift-heavy or raw-shape families that would be better retired before HOT walk
