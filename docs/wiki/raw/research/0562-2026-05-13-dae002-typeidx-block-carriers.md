# DAE002 typeidx block carrier follow-up

Date: 2026-05-13

## Question

After the scalar-load sibling fix left the live `dae-optimizing` debug-artifact first diff at `defined=11 abs=28`, can a narrower typed-block / multivalue-adjacent carrier slice move the remaining `moonbit.check_range` miss without broadening scheduler behavior?

## What I checked

1. Re-read the active DAE002 docs, backlog, and current uncommitted load-sibling slice.
2. Reconfirmed the worktree and baseline validation:
   - `git status --short`
   - `moon info`
   - `moon fmt`
   - `moon test src/passes`
3. Added a new focused DAE regression for exact-literal constant-actual materialization when sibling arguments are wrapped in explicit typed single-result blocks:
   - `dae-optimizing materializes shared constant actuals through typed block carriers`
4. Confirmed that regression failed before the implementation change (`3 != 2` params kept in the callee).
5. Taught `dae_instr_stack_effect(...)` to resolve `TypeIdxBlockType` block signatures through the module type section so block / loop / `try_table` carriers now report both input and output arity, and typed `if` carriers add the condition input on top of the resolved block signature.
6. Re-ran focused validation plus a new debug-artifact compare.

## Change

`src/passes/dead_argument_elimination.mbt` now has a typed-block stack-effect helper that resolves `TypeIdxBlockType` through `dae_type_sec_func_type(...)` and reports `(param_count, result_count)` instead of bailing out on all typed block carriers.

That change is intentionally narrow:

- it only improves callsite slice recovery for carriers that are still single stack values after the typed block wrapper;
- it does **not** attempt to decompose one multivalue producer into multiple call operands;
- it does **not** broaden DAE iteration scheduling or nested cleanup scope.

## Validation

Commands run:

- `moon info`
- `moon fmt`
- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-typeidx-block-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`

Results:

- `moon test src/passes`: pass (`960/960`)
- new focused regression: passes after the code change
- `.tmp/dae002-typeidx-block-artifact`
  - first diff still `defined=11 abs=28`
  - Starshine pass time `10139.424ms`
  - Binaryen pass time `928.830ms`

## Interpretation

This slice proves one more real caller-carrier gap in the exact-literal path:

- typed single-result `TypeIdxBlockType` wrappers can block Starshine's constant-actual recovery,
- the narrow fix is real and regression-covered,
- but it is **not sufficient** to unlock the live `moonbit.check_range` artifact rewrite.

That narrows the remaining blocker again:

- the issue is not just scalar loads;
- it is not just typed single-result block wrappers;
- the surviving `moonbit.check_range` family likely still needs a more specific multivalue-adjacent carrier slice, such as a direct lane-extraction / tuple-like projection pattern or a callsite shape that effectively depends on splitting one multivalue producer into distinct operands.

## Safe next step

Stay on the same narrow path:

1. preserve the new typed-block regression and support;
2. reduce one surviving direct-lane / multivalue carrier beyond this wrapper-only slice into a focused repro;
3. only then extend callsite recovery again.

Do **not** treat this unchanged artifact result as evidence for relanding the reverted broader scheduler experiments.
