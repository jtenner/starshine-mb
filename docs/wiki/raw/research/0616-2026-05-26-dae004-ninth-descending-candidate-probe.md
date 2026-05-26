# DAE004 ninth descending candidate probe

Date: 2026-05-26

## Scope

Recovery run for `[DAE]004` selected result-removal broadening after research note `0615` raised the guarded large-module descending fact-driven dropped-result scheduler to eight productive candidates.

## Probe

Tried the next obvious scheduler step: extend the focused large-module regression from eight to nine high dropped-result callees behind forty low dropped-result candidates, then raise the `4096 < defined <= 8192` descending fact-driven candidate cap from `8` to `9`.

TDD evidence:

- `moon test src/passes --target native` with the nine-candidate regression and the old cap failed by crashing the native passes blackbox executable with `SIGSEGV`; log: `.tmp/dae004-nine-test-fail.log`.
- After temporarily raising the cap to `9`, the focused filter passed for the nine-candidate regression:
  - `moon test src/passes/dae_optimizing_test.mbt --target native --filter '*nine high*' --test-failure-json`
  - result: `Total tests: 1, passed: 1, failed: 0.`
- The full passes suite still crashed with `SIGSEGV`, including `--no-parallelize`; logs: `.tmp/dae004-nine-test-pass.log`, `.tmp/dae004-nine-test-pass2.log`, `.tmp/dae004-passes-no-parallel.log`, and `.tmp/dae004-passes-after-4086.log`.

## Decision

Do **not** land the naive cap bump to `9` yet. The focused fixture shows the ninth descending attempt can remove the next synthetic high candidate, but full-suite native stability is not proven. The code and focused test probe were reverted before this note was committed.

Agent classification: blocked/unknown-risky, not semantic-safe. A scheduler cap increase that passes a focused synthetic fixture but crashes the full native passes test executable is not signable.

## Next step

Before another cap increase, add narrower diagnostic coverage that identifies which existing full-suite case becomes unstable when the large-module descending cap is `9`, or add an internal scheduler unit that exercises candidate ordering without running the full DAE optimizer over a 4k+ function module. Only then retry the cap bump with full `moon test`, artifact validation/timing, and direct compare evidence.
