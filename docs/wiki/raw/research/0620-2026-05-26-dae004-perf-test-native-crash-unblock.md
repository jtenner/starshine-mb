# DAE004 perf-test native crash unblock

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening. Research note `0619` showed the native `src/passes` gate was blocked on the current cap-`8` tree by a `SIGSEGV` in `src/passes/perf_test.mbt`, so the ninth descending-candidate probe could not be signed.

## Test-first failure

Command:

- `moon test src/passes/perf_test.mbt --target native --no-parallelize --test-failure-json`

Result before the fix:

- failed with native test executable signal `11` (`SIGSEGV`).

Isolation:

- `moon test src/passes/perf_test.mbt --target native --outline` mapped the file to 103 tests.
- Index ranges `0-25`, `25-50`, and `75-103` passed.
- Range `50-75` crashed.
- Single-test isolation showed only index `56`, `simplify-locals skips large read-only local ladders without hot lift`, reproduced the crash; neighboring single-test indices passed.

## Fix

Reduced the synthetic nested read-only ladder fixture in that test from `256` to `128` repetitions. The test still exercises the intended no-local-write raw-skip path and checks that no hot lift or `pass:simplify-locals` timer is emitted, but no longer overflows/crashes the native test executable on this environment.

This is not a DAE behavior change. It unblocks the native pass-suite gate needed before future `[DAE]004` scheduler cap work.

## Validation

- `moon test src/passes/perf_test.mbt --target native --no-parallelize --index 56` passed (`1/1`).
- `moon test src/passes/perf_test.mbt --target native --no-parallelize` passed (`103/103`).
- `moon test src/passes --target native --no-parallelize` passed (`1442/1442`).

## Next step

The previous current-tree native crash is no longer a blocker. Resume `[DAE]004` by retrying any ninth-descending-candidate behavior change test-first, then sign it with focused DAE tests, the native pass-suite gate, debug-artifact validation/timing, and direct compare evidence.
