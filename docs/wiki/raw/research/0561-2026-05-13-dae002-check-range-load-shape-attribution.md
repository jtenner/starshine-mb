# DAE002 check_range load-shape attribution

Date: 2026-05-13

## Question

Why does the remaining `dae-optimizing` debug-artifact first diff at `defined=11 abs=28` (`moonbit.check_range`) survive the narrow exact-literal constant-actual slice, and is a safe next slice visible without reviving the reverted broad scheduling experiments?

## What I checked

1. Re-read the active DAE002 docs, backlog, and code surfaces.
2. Reconfirmed the pass tests were green before new work:
   - `moon info`
   - `moon test src/passes`
3. Re-inspected the saved artifact inputs and the live `moonbit.check_range` diff:
   - `.tmp/dae002-call-summary-artifact-final3/*`
   - `.tmp/dae002-const-actual-artifact/*`
   - `.tmp/dae002-orig.print.wat`
4. Counted direct `moonbit.check_range` call shapes from `.tmp/dae002-orig.print.wat` with a local parser script.
5. Added a reduced pass regression for the first concrete unsupported-family I could confirm: a constant-actual candidate whose *other* arguments use scalar memory loads.
6. Re-ran the debug-artifact compare after landing only that narrow stack-effect support.

## Findings

### 1. The direct callers really do keep the middle `lo` argument fixed at literal `0`

A local parser over `.tmp/dae002-orig.print.wat` found `370` direct folded call expressions to `moonbit.check_range`.
Every observed second argument was exactly:

- `(i32.const 0)`

So the remaining miss is not caused by mixed observed `lo` values in the debug artifact.

### 2. Many `check_range` callers use nontrivial sibling argument carriers

The same folded-call scan found these notable operator families inside the `moonbit.check_range` caller expressions:

- `127` calls include `i32.load`
- `49` calls include `tuple.extract`
- `24` calls include `local.set`
- `12` calls include `block`

The active exact-literal materialization logic does not just inspect the constant actual itself; it must recover argument slices for the whole direct callsite. Before this session, `dae_instr_stack_effect(...)` did not model scalar memory loads, so even a call where the *middle* argument was literal `0` could still be rejected if another argument used `i32.load`.

### 3. A narrow reduced repro exists and is now covered

New focused regression in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes shared constant actuals when sibling args use loads`

That fixture keeps the literal middle argument stable while making the index argument come from `i32.load`. It failed before the code change and now passes after teaching `dae_instr_stack_effect(...)` the scalar load family needed for argument-slice recovery.

### 4. The narrow load-shape fix is real, but it does **not** move the live artifact frontier

Validation after the load-shape fix:

- `moon info`
- `moon fmt`
- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-load-only-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`

Result from `.tmp/dae002-load-only-artifact/result.json`:

- first differing function still `defined=11 abs=28`
- Starshine pass time `9826.812ms`
- Binaryen pass time `923.272ms`

So scalar load support was one real missing call-shape family for the exact-literal slice, but it is **not sufficient** to unlock the actual debug-artifact `moonbit.check_range` rewrite.

## Interpretation

The strongest current explanation is now narrower and more evidence-backed than the earlier generic “later frontier pressure” story:

- the artifact caller family is still a constant-actual candidate in principle,
- but at least one additional call-shape blocker remains in the `moonbit.check_range` caller set,
- and the likely next blockers are the remaining nontrivial folded carriers seen in the caller census (`tuple.extract`, block/local carrier wrappers, or another stack-effect gap), not the already-fixed scalar-load family.

The reverted broader scheduling ideas are still unsafe to reland on current evidence. This session did **not** find evidence that raising the DAE loop cap or broadening round-robin scheduling is the smallest safe next step.

## Safe next slice

A good next DAE002 slice should stay narrow and diagnostic-first:

1. add one more reduced constant-actual regression that specifically captures a surviving `moonbit.check_range` caller carrier family beyond scalar loads;
2. extend argument-slice recovery only for that exact carrier family;
3. re-run the debug-artifact compare immediately before considering any broader scheduling change.

The most likely next target from the observed folded caller census is a `tuple.extract`-carried index or bound.
