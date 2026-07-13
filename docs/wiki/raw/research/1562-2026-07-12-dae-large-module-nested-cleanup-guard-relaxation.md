# DAE large-module nested cleanup guard relaxation

Date: 2026-07-12

## Question

Can `dae-optimizing` safely run its touched-only nested cleanup inside large modules when the touched set is still small and every touched function stays under the existing local/instruction guard?

## Change

`src/passes/pass_manager.mbt` no longer skips DAE nested cleanup solely because a module has more than `100` defined functions.

The remaining nested-cleanup guards are unchanged:

- skip when more than `8` functions are touched;
- skip when any touched function exceeds the existing local/instruction threshold.

So the slice is narrower than “full large-module enablement”: it removes only the coarse module-count gate.

## Red-first tests

`src/passes/dae_optimizing_test.mbt` now adds two large-module regressions:

- `dae-optimizing runs nested cleanup on small touched sets inside large modules`
- `dae-optimizing nested cleanup still removes touched debris in large modules`

Before implementation both failed because the trace still reported:

- `pass[dae-optimizing]:nested-cleanup-skip reason=large-module touched=2`

and the touched callee still kept `local.set` debris.

## Focused validation

### Green targeted regressions

```sh
moon test src/passes/dae_optimizing_test.mbt --filter '*large*'
moon test src/passes/dae_optimizing_test.mbt --filter '*nested cleanup*'
```

Result: green after removing the module-count guard.

### Direct compare smoke

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-large-module-guard-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result:

- compared `1000/1000`
- normalized matches `1000`
- cleanup-normalized matches `0`
- mismatches `0`
- validation failures `0`
- generator/property failures `0`
- command failures `0`

Agent classification: no new direct-pass semantic mismatch surfaced in this smoke lane.

## Remaining blocker exposed by the wider lane

Broader pass-suite validation is not yet signable.

```sh
moon test src/passes
```

Current result after the guard relaxation: `26` failures, all in `src/passes/dae_optimizing_test.mbt`.

Observed families:

- many high-defined-function selected-shape tests still lock pre-nested-cleanup output shapes and now need their expectations reclassified or updated for the broader large-module cleanup lane;
- one focused regression, `dae-optimizing removes selected Func3737 wrapper default from folded multivalue callsite`, now aborts under the broader lane and needs a narrow safety classification or guard.

Repo-wide `moon test` is also currently blocked by unrelated compile errors in `src/fuzz/optimize_instructions_closeout_manifest_wbtest.mbt`, so this slice cannot provide full-suite signoff today.

## Conclusion

This slice safely reduces one documented DAE behavior gap:

- the nested cleanup lane is no longer limited to small modules; it now runs in large modules when the touched set is still small and the touched functions are still under the existing size guards.

But it does **not** close the broader large-module nested-cleanup audit yet.

Next safe work:

1. classify/update the high-def large-module DAE tests that assumed nested cleanup stayed skipped;
2. isolate the `Func3737` folded-multivalue abort and decide whether it needs a narrow guard or a real cleanup fix;
3. rerun `moon test src/passes` before claiming the larger guard relaxation is fully signed off.
