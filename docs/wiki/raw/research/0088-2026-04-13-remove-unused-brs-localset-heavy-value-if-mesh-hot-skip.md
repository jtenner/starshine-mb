---
kind: research
status: completed
last_reviewed: 2026-04-13
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/cmd/cmd_test.mbt
  - ../../../../agent-todo.md
---

# 0088 - `remove-unused-brs` localset-heavy value-if mesh hot skip

## Scope

- Retire the next post-`0087` unchanged HOT-walk family on the canonical debug artifact.
- Keep the detector calibrated on lifted summary counts from the checked-in artifact instead of raw WAT heuristics alone.
- Preserve exact RUB parity by only retiring extracted functions that still compare canonically equal to Binaryen.

## Problem

After the earlier `call-heavy-mixed-if-mesh-noop` slice, the canonical debug artifact still had a smaller but expensive lifted unchanged family with heavy `local.set` / `local.tee` traffic, low call counts, and value-`if`-heavy control.

Representative artifact functions in that family were:

- `Func 837` / `hot__lift__impl__build__direct__node`
- `Func 3021` / `encoding::utf8::decode.inner`
- `Func 3120` / `parse__number`
- `Func 3130` / `parse__decimal__from__view`
- `Func 3134` / `parse__int64.inner`

The family was distinct from both earlier lifted skips:

- much heavier `local.set` traffic than the call-heavy mixed-if mesh slice
- lower call counts than the earlier medium/call-heavy families
- value-`if` traffic that still stayed canonically unchanged after full traversal
- no `br_table` surface and only small loop depth

## Lifted Shape Envelope

Tracing the real artifact and collecting lifted summaries showed the retired family clustering inside this HOT envelope:

- locals: `228..686`
- roots: `5..50`
- nodes: `1079..3108`
- calls: `47..101`
- `local.set`: `137..623`
- `local.tee`: `79..312`
- void `if`: `4..24`
- value `if`: `14..100`
- `return`: `1..21`
- `select`: `0..13`
- `br_if`: `0..5`
- blocks: `73..231`
- loops: `0..2`
- plain `br`: `12..83`
- `br_table`: `0`
- `drop`: `0..25`

The key calibration lesson is the same as the last two slices: the landed detector follows lifted summary counts, not just the printed function text.

## Change

- Added `remove_unused_brs_can_skip_localset_heavy_value_if_mesh(...)` in `src/passes/remove_unused_brs.mbt`.
- Hooked it into `remove_unused_brs_run(...)` with the trace reason:
  - `skip-hot reason=localset-heavy-value-if-mesh-noop`
- Kept it after the earlier `call-heavy-mixed-if-mesh-noop` gate so the broader call-heavy slice retains its existing trace reason and coverage.
- Added a native artifact-backed regression in `src/cmd/cmd_test.mbt`:
  - `run_cmd_with_adapter traces remove-unused-brs localset-heavy value-if mesh hot skip on extracted debug artifact func 3021`

## Validation

- `moon fmt`
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`
  - `91/91` passed
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter traces remove-unused-brs call-heavy mixed-if mesh hot skip on extracted debug artifact func 408'`
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter traces remove-unused-brs localset-heavy value-if mesh hot skip on extracted debug artifact func 3021'`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 200 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-200-after-localset-heavy-value-if-mesh`
  - `200/200` compared
  - `0` mismatches
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 120 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-mixed-120-after-localset-heavy-value-if-mesh`
  - `119/119` compared clean before the usual Binaryen-side parser failure
  - `0` mismatches

Extracted single-function compare replays for the checked family also stayed oracle-clean with `Normalized WAT equal: yes` and `Canonical function compare equal: yes`, including:

- `Func 837`
- `Func 3021`
- `Func 3120`
- `Func 3130`
- `Func 3134`

## Perf Impact

A fresh native trace on the exact canonical artifact now retires these five functions under the new hot skip:

- `Func 837`
- `Func 3021`
- `Func 3120`
- `Func 3130`
- `Func 3134`

Interleaved three-pair self-opt compare reruns on `tests/node/dist/starshine-debug-wasi.wasm` show a clear improvement for this slice.

- command:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs`
- interleaved averages:
  - baseline: `431.7387 ms`
  - current: `402.0653 ms`
  - delta: `-29.6734 ms` (`-6.873%`)
- interleaved medians:
  - baseline: `426.127 ms`
  - current: `401.351 ms`
  - delta: `-24.776 ms` (`-5.8142%`)

## Remaining Work

This slice clears the next lifted unchanged family but still leaves visible pass-heavy work.

After the new skip, the still-visible unchanged leaders are now headed by:

- `Func 497`
- `Func 1168`
- `Func 229`
- `Func 990`
- `Func 883`
- `Func 1213`
- `Func 1061`
- `Func 105`
- `Func 1063`

The next likely follow-up should keep separating:

- smaller `br_table`-carrying unchanged families that may want another narrow lifted classifier
- low-local / enum-like compare families that still pay traversal despite staying canonically equal
