# DAE002 touched control simplifier closes Func 28 and moves the artifact frontier to Func 42

Date: 2026-05-14

## Question

After proving that `moonbit.check_range` now rewrites correctly in the artifact core, can a narrow touched-only post-rewrite control simplifier close the remaining Func 28 body-form mismatch without relanding broad large-artifact nested cleanup?

## What I changed

I added a narrow touched-only control simplifier inside the DAE exact-literal rewrite path.

It rewrites already-touched callee bodies after local/const remapping and handles two small post-rewrite control shapes recursively:

1. negated compare peephole
   - `compare ; i32.eqz` -> `negated-compare`
2. empty-then / unreachable-else guard form
   - `compare ; if (void) else unreachable` -> `negated-compare ; if (void) unreachable`

This stays inside the DAE-touched rewrite lane instead of broadening whole-artifact nested cleanup.

## Focused regressions

Added/strengthened in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing rewrites every direct call when a caller hits the same callee twice`
  - now also asserts the rewritten callee body contains `i32.lt_s`
  - and does not contain `i32.eqz` or `i32.ge_s`

The earlier new regressions for:

- typed-loop ambient entry-value callsite slicing
- same-caller multi-call rewrite accounting

remain green.

## Validation

Commands run:

- `moon fmt`
- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-post-control-simplify-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`

## Artifact result

Compare output moved from:

- first diff `defined=11 abs=28`

to:

- first diff `defined=25 abs=42`

So the narrow touched-only control simplifier closed the old `moonbit.check_range` / Func 28 mismatch.

Observed current compare path:

- output dir: `.tmp/dae002-post-control-simplify-artifact`
- Starshine Func 28 now matches Binaryen closely enough that it is no longer the first differing function
- Starshine remains much slower than Binaryen on the full artifact

## New first differing function

Current new frontier:

- `defined=25 abs=42`

Current shape summary from the compare artifacts:

- Binaryen rewrites Func 42 to params `[I32, I32]`
- Starshine still keeps Func 42 at params `[I32, I32, I32]`

So the next DAE002 blocker is no longer Func 28 body cleanup.
It is now a different later candidate at Func 42.

## Interpretation

This is a real forward move, not just a reshuffle in wording:

- the old Func 28 core miss was fixed,
- the old Func 28 post-rewrite control-form mismatch is now also closed,
- and the live artifact frontier has advanced to a new function.

The touched-only local cleanup lane was sufficient for this specific post-rewrite control form without broadening large-artifact nested cleanup policy.

## Safe next step

Start a fresh narrow characterization for Func 42:

1. identify whether it is another exact-literal/private-direct candidate, a dead-param-only candidate, or a different DAE family;
2. add a whitebox artifact characterization like the Func 28 work;
3. only then decide whether the next fix belongs in callsite-shape recovery, rewrite accounting, local-use classification, or another tiny touched-only cleanup step.
