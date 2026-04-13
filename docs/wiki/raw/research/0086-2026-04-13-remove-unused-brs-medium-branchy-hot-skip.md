---
kind: research
status: completed
last_reviewed: 2026-04-13
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/cmd/cmd_test.mbt
  - ../../../../agent-todo.md
---

# 0086 - `remove-unused-brs` medium branchy hot skip

## Scope

- Retire the next obvious unchanged HOT-walk family after the earlier large `br_table`, tagged result-prefix, and large void-return no-op skips.
- Keep the new detector calibrated on the checked-in debug artifact instead of only on reduced synthetic ladders.
- Preserve exact RUB parity by only retiring families that already replay canonically equal to Binaryen in extracted single-function compares.

## Problem

After the earlier `2026-04-13` Binaryen-shaped raw filtering slice, the local RUB lane was still leaving a medium branchy family fully lifted and fully walked even though the pass exited `changed=false`.

Representative unchanged functions on the canonical debug artifact were:

- `Func 144` / `parse__env__overlay`
- `Func 301` / `dfe__iteration.inner`
- `Func 353` / `dfe__rewrite__module__type__idxs.inner`
- `Func 1512` / `Elem.Encode.encode`
- `Func 1547` / `NameSec.Encode.encode`
- `Func 1859` / `validate__ref__func__declarations__in__module.inner`
- `Func 1867` / `validate__name__sec`

These functions were not the old raw families:

- no `br_table`
- no `br_if`
- only tiny or zero `select` traffic
- medium locals and medium lifted node counts rather than giant ladder shapes

But they were still expensive enough to matter in aggregate because they paid both lift and the full HOT visit/fixpoint setup before exiting unchanged.

## Lifted Shape Envelope

Tracing extracted canonical functions showed the retired family clusters inside this lifted summary envelope:

- locals: `200..500`
- nodes: `1300..2300`
- calls: `150..362`
- `local.set`: `95..210`
- `local.tee`: `123..266`
- void `if`: `54..140`
- value `if`: `0..12`
- `return`: `0..24`
- `select`: `0..4`
- `br_if`: `0`
- blocks: `104..227`
- loops: `0..15`
- plain `br`: `33..51`
- `br_table`: `0`
- `drop`: `24..71`
- non-block result prefixes: `0..4`

The extracted single-function replay stayed oracle-clean on the checked functions, including:

- `Func 1512`
- `Func 1547`
- `Func 1859`
- `Func 1867`

with `Normalized WAT equal: yes` and `Canonical function compare equal: yes`.

## Change

- Added `remove_unused_brs_can_skip_medium_branchy_block_ladder(...)` in `src/passes/remove_unused_brs.mbt`.
- Hooked it into the lifted front door in `remove_unused_brs_run(...)` with the trace reason:
  - `skip-hot reason=medium-branchy-block-ladder-noop`
- Added a native artifact-backed regression in `src/cmd/cmd_test.mbt`:
  - `run_cmd_with_adapter traces remove-unused-brs medium branchy hot skip on extracted debug artifact func 1547`

This keeps the detector anchored to the real canonical artifact instead of only to a reduced fixture.

## Validation

- `moon fmt`
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`
  - `91/91` passed
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter traces remove-unused-brs medium branchy hot skip on extracted debug artifact func 1547'`
- `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd_with_adapter validates remove-unused-brs on debug artifact'`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 200 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-200-after-medium-branchy-hot-skip`
  - `200/200` compared
  - `0` mismatches
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 120 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-mixed-120-after-medium-branchy-hot-skip`
  - `119/119` compared clean before the usual Binaryen-side parser failure
  - `0` mismatches

## Perf Impact

Fresh local self-opt compare reruns on the canonical debug artifact show a modest but repeatable improvement.

- command:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs`
- five-run averages:
  - baseline: `482.2412 ms`
  - current: `461.5536 ms`
  - delta: `-20.6876 ms` (`-4.29%`)

A representative current native debug-serial trace now retires these functions under the new hot skip:

- `Func 144`
- `Func 301`
- `Func 353`
- `Func 1512`
- `Func 1547`
- `Func 1859`
- `Func 1867`

## Remaining Work

The medium branchy slice does not close the remaining RUB runtime gap.

After this retirement, the still-visible unchanged leaders are now headed by:

- `Func 3021`
- `Func 408`
- `Func 497`
- `Func 739`
- `Func 1448`
- `Func 832`
- `Func 1168`
- `Func 1213`

The next useful follow-up should keep distinguishing:

- pass-heavy unchanged families that want another no-op classifier
- lift-heavy families that still mainly want cheaper lift or earlier raw retirement
