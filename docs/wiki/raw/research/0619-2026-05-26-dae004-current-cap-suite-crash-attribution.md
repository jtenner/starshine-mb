# DAE004 current-cap suite crash attribution

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` selected result-removal broadening after research notes `0616` through `0618` left the ninth descending-candidate cap increase blocked by a native full-suite `SIGSEGV`.

## Probe

Before retrying the behavior-changing cap bump from `8` to `9`, I re-ran the current clean tree at the existing cap (`8`) to test whether the full-suite crash was unique to the ninth-candidate probe.

Commands and results:

- `moon test src/passes --target native --no-parallelize`
  - result: failed with `SIGSEGV` in the native passes blackbox executable.
- Serial per-file loop over `src/passes/*_test.mbt` and `src/passes/*_wbtest.mbt`
  - individual test files before `src/passes/perf_test.mbt` passed;
  - `moon test src/passes/perf_test.mbt --target native --no-parallelize` failed with the same native blackbox `SIGSEGV`.
- `moon test src/passes/dae_optimizing_test.mbt --target native --no-parallelize --test-failure-json`
  - result: `158` passed, `0` failed.
- `moon test src/passes/pass_manager_wbtest.mbt --target native --no-parallelize --test-failure-json`
  - result: `94` passed, `0` failed.

## Classification

This is a recovery attribution note, not a DAE behavior change. The current cap-`8` tree already reproduces the native package/full-suite crash when the per-file loop reaches `perf_test.mbt`; the focused DAE optimizer tests and DAE whitebox scheduler/helper tests pass independently. Therefore, the `0616` full-suite `SIGSEGV` is not sufficient evidence by itself that the ninth descending DAE candidate is unsafe.

Agent classification for `[DAE]004`: still blocked/unknown-risky for a cap increase. The behavior change remains unsigned because the required full-suite gate is unavailable, but the next investigation should first isolate or fix the current native `perf_test.mbt` package crash (or obtain an accepted non-native/filtered gate) before treating the crash as DAE-owned.

## Next step

Do not raise the large-module descending cap to `9` until validation is signable. First isolate the native `perf_test.mbt` crash on the current cap-`8` tree, then rerun the ninth-candidate probe with focused DAE tests, `moon test src/passes`, debug-artifact validation/timing, and direct compare evidence.
