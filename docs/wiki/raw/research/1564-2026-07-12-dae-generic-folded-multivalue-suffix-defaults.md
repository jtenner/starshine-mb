# DAE generic folded-multivalue suffix-default recovery

## Question

Can `dae-optimizing` recover the folded-multivalue `Func3737 -> Func3765` forwarded-default family with a generic exact-literal recognizer instead of the old function-pair-specific helper, without reopening the earlier Func323 selected default-suffix boundary?

## Findings

Yes, with one narrow guard.

`dae_collect_callsite_shapes(...)` requires a full backward reconstruction of every call argument. That was too strict for folded-multivalue callers where an earlier argument is still represented by a `local.tee` / stack-carrier chain, even though the trailing suffix arguments are already isolated and safe to reason about. The reduced low-definition repro added in `src/passes/dae_optimizing_test.mbt` failed red because the generic exact-literal path left both rewritten signatures at four parameters.

A new suffix-only collector now recovers the contiguous trailing argument slice when full reconstruction fails. Two places use it:

1. `dae_rewrite_callsite_at(...)` can now preserve an unresolved prefix while still rewriting a resolved trailing suffix, but only when the suffix begins immediately after a value-producing instruction.
2. `dae_collect_uniform_const_actuals_instrs(...)` can now observe uniform exact literals in that same suffix-only situation.

That value-producing-prefix guard matters. Without it, the broader suffix recovery let the generic exact-literal path peel the final `i32.const 35864` from the selected `Func323` family before the dedicated two-default selected rewrite ran, leaving the harder preceding result-`if` default behind. Requiring the first resolved suffix argument to start immediately after an instruction with positive stack output keeps the folded-multivalue `local.tee` carrier case admitted while rejecting the older inter-argument effect/debris boundary that still belongs to the selected Func323 rewrite.

With the guarded suffix recognizer in place, the old bespoke `dae_try_specialize_single_i32_suffix_default_arg_once(...)`, `dae_try_specialize_selected_single_i32_suffix_default_arg_once(...)`, `dae_rewrite_immediate_i32_suffix_calls_instrs(...)`, and `dae_try_remove_func3737_wrapper_suffix_param_once(...)` helpers are no longer needed. The high-definition `3737` / `3765` artifact lanes now reuse `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(...)`.

## Code changes

- `src/passes/dae_optimizing_test.mbt`
  - added `dae-optimizing removes generic forwarded default argument from folded multivalue callsite`
- `src/passes/dead_argument_elimination.mbt`
  - added `dae_collect_callsite_suffix_shapes(...)`
  - taught `dae_rewrite_callsite_at(...)` to rewrite a guarded resolved suffix without reconstructing the whole callsite
  - taught `dae_collect_uniform_const_actuals_instrs(...)` to recover guarded suffix-only exact literals
  - removed the dedicated `3737` / `3765` forwarded-default helper stack and reused the generic selected exact-literal path

## Validation

Red first:

- `moon test src/passes/dae_optimizing_test.mbt --filter '*generic forwarded default argument from folded multivalue callsite*'`
  - failed before the fix with `4 != 3`

Green after the implementation:

- `moon test src/passes/dae_optimizing_test.mbt --filter '*generic forwarded default argument from folded multivalue callsite*'`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*Func323 default suffix params*'`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*Func3737*'`
- `moon test src/passes/dae_optimizing_test.mbt`
- `moon test src/passes`
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-smoke-20260712-generic-suffix --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`
  - `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` command failures

## Remaining gap after this slice

This removes one function-pair-specific forwarded-default family and proves the folded-multivalue suffix shape has a reusable recognizer. It does **not** close the broader DAE audit. The remaining direct-pass gaps still include the real public `precompute-propagate` / fuller default-function replay surface, broader operand localization beyond the guarded suffix case, GC parameter refinement, result refinement, and the rest of the selected/artifact genericization backlog.
