# 0077 - RemoveUnusedBrs Large Result `br_table` No-Op Skip

## Scope

- Reduce `remove-unused-brs` runtime on the checked-in MoonBit debug artifact after the earlier carried-wrapper parity slice.
- Confirm that the remaining huge nested result-block `br_table` ladders are real no-op families, not hidden RUB parity work.
- Keep the wiki and backlog aligned with the new runtime evidence.

## Starting Point

After the `br_table` continuation-wrapper rewrite landed, mixed-generator parity was still clean, but explicit-pass replay stayed expensive.

Fresh trace on `tests/node/dist/starshine-debug-wasi.wasm` showed two large unchanged functions dominating the remaining cost:

- `Func 1219`
- `Func 1220`

Both reported:

- `changed=false`
- no useful HOT rewrites
- large lift cost plus large HOT walk cost

The printed WAT shape was:

- one top-level result block
- a very deep leading chain of zero-result blocks
- one leaf `br_table`
- per-case payload code that exits the outer result block, except the final case which falls through as the result value

This was not the earlier carried-wrapper parity family.

- Binaryen-compatible wrapper retargeting was already fixed in `0076`.
- These ladders were instead large no-op dispatch carriers that RUB kept rediscovering after lift.

## Reduced Shape

The new perf fixture in `src/passes/perf_test.mbt` models the artifact family directly:

- `perf_test_make_large_result_br_table_dispatch_ladder_module(...)`
- perf test `remove-unused-brs skips large result br_table dispatch ladders without hot lift`

The important shape constraints are:

- function body is a single result block
- the result block starts with a deep chain of zero-result blocks
- the leaf body contains exactly one `br_table`
- the family has no `if`, `br_if`, `return`, or loop-driven HOT-only rewrite surface
- the case bodies are plain payload code plus outer exit traffic, with the final case falling through

## Implemented Skip

The raw pass-manager layer now recognizes this family with:

- `run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(...)`
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_result_br_table_dispatch_ladder(...)`

The design is intentionally two-stage:

1. A cheap leading-block-chain depth probe rejects ordinary result blocks before any full recursive shape scan.
2. The full shape scan only runs after the cheap probe confirms a very deep block prefix.

The final raw skip reason is:

- `large-result-br-table-dispatch-ladder-noop`

This keeps the skip narrow enough to avoid reopening the earlier wrapper rewrite family while still retiring the giant artifact ladders.

## Validation

- Focused and full pass tests:
  - `moon test src/passes`
  - result: `425/425` passing locally after the slice
- Hard parity lane:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-large-brtable-skip-10000`
  - result: `10000/10000` compared, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- Mixed-generator spot-check:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 10000 --seed 0x5eed7 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-20260410-large-brtable-skip-cheapguard-10000`
  - result: `1398/1398` compared matches, `0` mismatches, `0` validation failures, `5` Binaryen-side command failures
- Idle explicit artifact replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-rub-20260410-large-brtable-skip-cheapguard-idle --remove-unused-brs`
  - result:
    - Starshine pass runtime `651.284 ms`
    - Binaryen pass runtime `91.882 ms`
    - canonical wasm equal: `false`
    - normalized WAT equal: `false`
- Idle native pass trace:
  - `.tmp/rub-trace-large-brtable-skip-cheapguard-idle.stderr`
  - `Func 1219` and `Func 1220` now both skip raw with `reason=large-result-br-table-dispatch-ladder-noop`
  - total traced RUB pass time dropped from `720481 us` to `671669 us`
  - total traced lift time dropped from `980252 us` to `931152 us`

## Current Outcome

- The large result-block `br_table` dispatch family is now explicitly documented as a no-op raw-skip class.
- The two measured artifact hotspots `Func 1219` and `Func 1220` no longer pay lift or HOT traversal.
- Hard `gen-valid` parity remains fully green after the skip.
- Mixed-generator evidence stays mismatch-free on all compared cases.
- Idle explicit-pass artifact runtime improved materially, but it is still far from Binaryen.

## Remaining Gap

The runtime hotspot map moved rather than disappeared.

After this skip, the biggest unchanged traced functions are now centered on:

- `Func 1058`
- `Func 1150`

Those remaining families still report `changed=false`, but they are not the same large pure `br_table` ladder shape and should not be force-fit into this new raw skip.

The next useful work is:

1. separate the remaining explicit-pass type-order noise from real RUB body differences
2. reduce the current unchanged `Func 1058` / `Func 1150` cost without widening the new raw skip into unrelated carried-guard or condition families
3. keep rerunning self-opt compare and the compare-pass harness after each reduction
