# DAE002 later-candidate starvation after eight earlier rewrites

Date: 2026-05-14

## Question

After the narrow scalar-load and typed single-result block-carrier fixes, is the remaining `moonbit.check_range` miss more likely another caller-carrier gap, or is the current DAE core simply failing to reach a later exact-literal candidate within its existing bounded iteration budget?

## What I checked

1. Re-read the current DAE core loop and confirmed its shape:
   - `dae_run_core_once(...)` returns immediately after the first productive rewrite.
   - `dae_run_core(...)` reruns that once-per-change scan up to a fixed `8` iterations.
2. Built a reduced module that intentionally queues:
   - `9` earlier productive private dead-param candidates (`g0`..`g8`), each with one removable direct-call parameter;
   - one later `moonbit.check_range`-shaped exact-literal candidate (`$check`) whose middle `lo` parameter is always `i32.const 0` across all direct callers.
3. Replayed that reduced module through both Starshine and Binaryen.
4. Promoted the reduced case into `src/passes/dae_optimizing_test.mbt` as a characterization regression.
5. Added a small `pass[dae-optimizing]:core iter=... primary_def=...` trace line so the reduced repro can lock the exact bounded frontier that the current core actually walks.

## Reduced repro

The new focused regression is:

- `dae-optimizing current eight-iteration core can leave a later constant-actual candidate unreached`

It now also asserts the traced core frontier directly:

- `iter=0..7` rewrite `primary_def=0..7`
- no traced core iteration reaches defs `8` or `9`

Shape summary:

- defs `0..8`: each is a trivial private `(param i32 i32)` callee where the second param is dead and directly removable;
- def `9`: a `moonbit.check_range`-like `(param i32 i32 i32)` callee where the middle param is a valid exact-literal constant-actual candidate;
- exported callers invoke all `g*` functions first, then invoke `$check` with stable middle literal `0`.

## Findings

On that reduced module:

- Binaryen rewrites the later `$check` candidate to **2 params**.
- Starshine rewrites only the earlier frontier within the current bounded loop:
  - the traced productive iterations are exactly `primary_def=0,1,2,3,4,5,6,7`,
  - `g0` through `g7` end up fully rewritten first,
  - `g8` remains at **2 params**,
  - `$check` remains at **3 params**.

The new regression locks exactly that current local truth.

## Interpretation

This is stronger evidence than another guessed caller-carrier family.

It shows that a later exact-literal candidate can remain unreached even in a reduced module where:

- the candidate itself is structurally simple,
- no scalar-load sibling gap is involved,
- no typed single-result block-wrapper gap is involved,
- and the only pressure comes from enough earlier productive rewrites to exhaust the current fixed `8`-iteration budget.

So the remaining `moonbit.check_range` artifact miss is now plausibly explained by **DAE-core reach / bounded iteration starvation**, not just by another unsupported caller-carrier expression shape.

## Validation

Commands run:

- `moon test src/passes`
- external reduction replay via `wasm-tools parse`, `wasm-opt --dae-optimizing`, and `target/native/release/build/cmd/cmd.exe --dead-argument-elimination-optimizing --out ...`

Observed reduced repro result:

- Binaryen: `$check` reduced to 2 params
- Starshine: `$check` remained at 3 params while earlier defs consumed the current frontier

## Safe next step

The next narrow DAE002 slice should start from this bounded-frontier evidence:

1. diagnose whether the debug-artifact `moonbit.check_range` miss is the same reach problem as the reduced 9-earlier-def repro;
2. if yes, design the smallest safe reach fix that does **not** simply reland the previously reverted broad scheduler experiments unchanged;
3. rerun the debug artifact compare immediately after any such targeted reach change.
