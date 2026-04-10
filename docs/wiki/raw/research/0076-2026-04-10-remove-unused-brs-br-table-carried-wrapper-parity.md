# 0076 - RemoveUnusedBrs `br_table` Carried Wrapper Parity

## Scope

- Reduce the remaining early `remove-unused-brs` artifact mismatch around carried `br_table` wrapper chains.
- Confirm whether the new parity slice introduces a real hot-path regression on the MoonBit debug artifact.
- Record the remaining compare and performance state after the fix.

## Starting Point

Before this slice, the explicit-pass artifact compare still first diverged on an early carried-wrapper family:

- Binaryen retargeted `br_table` arms directly to an outer continuation label.
- Starshine left the same wrapper chain in place and kept plain tail `br` nodes to the outer exit.
- Mixed-generator differential fuzzing was already green on compared cases, so the remaining work looked like a narrow artifact-backed parity family, not a broad oracle failure.

The useful local reproducer shape was:

- an outer result carrier
- a nested chain of zero-result wrapper blocks
- a leaf `br_table` targeting the wrapper labels
- wrapper tails that only forward to the same outer continuation

## Reduced Oracle Shape

The focused fixture now locked in `src/passes/remove_unused_brs_test.mbt` and `src/passes/perf_test.mbt` shows the exact family:

- `br_table` targets wrapper labels `$b0`, `$b1`, `$b2`, ...
- each wrapper has body `[child_block, br outer_target]`
- the outer carrier later continues with the real payload path

Binaryen's behavior on that family is:

- rewrite matching `br_table` arms and default directly to the outer target
- leave the now-dead wrapper tails as `unreachable`

The rewrite is only safe when:

- the wrapper chain is strictly nested
- the wrapper tails are plain zero-arity `br`
- the forwarded labels are only referenced by that `br_table`

## Implemented Fix

The landed helper is `remove_unused_brs_try_rewrite_br_table_continuation_wrappers(...)`.

It:

- matches the nested wrapper chain under a void block root
- confirms the leaf body is a one-root `br_table`
- rewrites every forwarded arm/default to the shared outer target
- verifies the wrapper labels are used exactly by that `br_table`
- replaces each dead forwarding tail with `unreachable`

The focused correctness regression is:

- `remove-unused-brs retargets br_table continuation wrappers to the outer exit`

The perf regression for mutation churn is:

- `remove-unused-brs rewrites br_table continuation wrappers in one mutation`

## Performance Investigation

The parity fix itself was not the main hot-path cost.

Artifact pass tracing showed:

- the new `rub-br-table-forward rewrite` helper only fired twice on the debug artifact
- the larger wall-time regression came from no-op scans in two older matcher families:
  - `remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(...)`
  - `remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(...)`

Those helpers were paying label-ref and tail-analysis cost before discovering that the candidate's first inner root was just another `Block`, not the required `br_if`.

The landed follow-up change moves the cheap structural `BrIf` checks ahead of the more expensive label-ref / self-tail / payload-holder work.

The focused perf regressions are:

- `remove-unused-brs skips prefix-root scans for nested block dispatch ladders`
- `remove-unused-brs skips result-prefix scans for nested block dispatch ladders`

## Validation

- Focused pass and perf tests:
  - `moon test src/passes`
  - result: `424/424` passing locally after the slice
- Mixed-generator fuzz spot-check:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 500 --seed 0x5eed3 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-20260410-final-500`
  - result: `499/499` compared matches, `0` mismatches, `0` validation failures, `1` Binaryen-side command failure
  - the command failure class was still `binaryen-rec-group-zero` (`Recursion groups of size zero not supported`)
- Explicit artifact replay:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-rub-20260410-fastguards --remove-unused-brs`
  - result:
    - Starshine pass runtime `706.823 ms`
    - Binaryen pass runtime `104.074 ms`
    - canonical wasm equal: `false`
    - normalized WAT equal: `false`

## Current Outcome

- The old early carried-wrapper parity slice is fixed in-source.
- The mixed-generator oracle lane stays clean on compared cases after the fix.
- The fast structural guards recover the artifact pass time back to roughly the pre-slice baseline instead of the earlier ~`800ms`+ regression band.

## Remaining Gap

The explicit artifact compare is still not a clean RUB-only signal.

The latest normalized diff now starts with:

- module type-order churn near the header
- later function-body diffs after that

So the next reduction should not assume the remaining first diff is an actual `remove-unused-brs` semantic bug.

The next useful work is:

1. isolate a later mutation-backed function-body gap instead of reopening the fixed carried-wrapper family
2. keep the loop/block-order family separate from type-order or lift/lower noise
3. preserve the fast structural guards unless a replacement proves equivalent cost
