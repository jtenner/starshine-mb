# DAE002 check_range now rewrites; remaining artifact diff is nested-cleanup skip

Date: 2026-05-14

## Question

After characterizing the bounded `8`-iteration frontier, why did the original debug artifact still leave `moonbit.check_range` unchanged in full `dae_run_core(...)`, and what is the next remaining blocker once that specific core miss is fixed?

## What I checked

1. Added a reduced public regression where a private exact-literal callee is called through a typed loop body that carries an ambient stack value through `local.tee` prefixes.
2. Added a second reduced public regression where each caller invokes the same private exact-literal callee **twice**.
3. Added whitebox artifact characterizations for the original `moonbit.check_range` callee (`defined=11 abs=28`) to inspect:
   - the early DAE core frontier,
   - exact-literal candidate discovery,
   - whether caller rewrites fail outright or merely undercount rewritten calls.
4. Re-ran the full debug-artifact compare after the implementation change.

## Reduced repro findings

### 1. Ambient typed-loop callsite prefixes were a real blocker

A focused repro with a typed loop body that keeps one argument on the ambient loop-entry stack and only materializes the constant middle argument locally showed:

- Binaryen rewrites the callee from **3 params** to **2**.
- Starshine previously left it at **3**.

The fix was to let DAE callsite slicing account for body-entry stack values in typed control bodies, including slices that begin after an unrelated zero-output barrier but still depend on ambient entry values.

### 2. Same-caller multi-call rewrite undercount was a second real blocker

A focused repro where each caller invokes the same exact-literal callee twice showed:

- Binaryen rewrites the callee from **3 params** to **2**.
- Starshine previously left it at **3** because call rewriting undercounted rewritten callsites and aborted the candidate.

The fix was to rewrite direct calls sequentially in-place and resume after the rewritten call’s new index, instead of using the earlier split-and-tail helper that skipped additional same-caller callsites.

## Original artifact findings after the fix

On `tests/node/dist/starshine-debug-wasi.wasm`:

- `dae_collect_uniform_const_actuals(...)` for `moonbit.check_range` now returns:
  - `Some([None, Some(i32.const 0), None])`
- `dae_try_rewrite_candidate(...)` now returns:
  - `changed = true`
- all direct caller rewrites are now accounted for:
  - `total rewritten calls = 370`
  - `direct calls = 370`
- the early bounded DAE core frontier now starts with the target callee itself:
  - `primary_def` sequence begins `11, 227, 233, 236, 237, 246, 256, 267, ...`

So the live debug-artifact `moonbit.check_range` miss is **no longer a DAE core reach/rewrite blocker**.

## Full artifact compare after the fix

Full compare output at:

- `.tmp/dae002-loop-carried-and-multicall-artifact`

Observed results:

- first differing function is still `defined=11 abs=28`
- but Starshine now emits `moonbit.check_range` with:
  - params `[I32, I32]`
- matching Binaryen’s arity reduction

The remaining function-28 diff is now a **post-rewrite cleanup/form difference**, not the earlier missed core rewrite:

- Starshine body still reflects the direct rewrite shape
- Binaryen body is further simplified

A traced direct artifact run now shows:

- `pass[dae-optimizing]:core iter=0 primary_def=11`
- later productive defs continue through the bounded frontier
- nested cleanup is still skipped for the full artifact with:
  - `pass[dae-optimizing]:nested-cleanup-skip reason=large-touched-set touched=190`

## Interpretation

This changes the DAE002 attribution materially.

Previous leading artifact blocker:

- `moonbit.check_range` not being reached / rewritten in the DAE core

Current leading artifact blocker:

- the callee is rewritten correctly,
- but the large-artifact nested cleanup lane is still skipped,
- so Starshine keeps the direct rewrite form instead of the later Binaryen-simplified body form.

## Validation

Commands run:

- `moon fmt`
- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-loop-carried-and-multicall-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`
- traced direct CLI replay with `STARSHINE_TRACING=pass`

## Safe next step

The next narrow DAE002 slice should stop treating `moonbit.check_range` as a missed core-rewrite case.

Instead:

1. treat the remaining `defined=11 abs=28` diff as a **large-artifact nested-cleanup parity** issue;
2. isolate the smallest touched-function cleanup needed to simplify the rewritten `check_range` body toward Binaryen’s form;
3. avoid broad whole-module cleanup relands while keeping the touched-only guardrails explicit.
