# DAE004 descending order unit

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` after research note `0616` rejected the naive ninth large-module descending dropped-result cap increase because the full native passes suite crashed with `SIGSEGV`.

## Change

Added a narrow whitebox scheduler-order unit that does not construct or optimize a 4k+ function WAT module. The new helper `dae_collect_descending_selected_def_candidates` extracts the descending selected-def traversal used by the large-module fact-driven dropped-result lane, and the test `dae descending dropped-result scheduler orders high candidates without huge module` proves that high candidates `4508..4500` are visited before the forty low candidates.

This is intentionally diagnostic/scaffolding progress, not a cap increase. Runtime behavior remains unchanged: the large-module descending productive cap is still `8`, and the handpicked selected-def fallback remains active.

## TDD evidence

- Initial focused test failed to compile because `dae_collect_descending_selected_def_candidates` was unbound.
- After extracting the helper and routing `dae_try_remove_descending_dropped_results_with_facts_once` through it, the focused test passed:
  - `moon test src/passes/pass_manager_wbtest.mbt --target native --filter '*descending dropped-result scheduler orders high*'`
  - result: `Total tests: 1, passed: 1, failed: 0.`

## Classification

Diagnostic/recovery scaffold. This reduces the next retry surface for `[DAE]004` by separating candidate ordering from huge-module optimizer execution. It does not prove the ninth productive rewrite is safe and does not change the earlier blocked/unknown-risky classification from note `0616`.

## Next step

Use the helper to add a narrow unit for the bounded productive-attempt loop or otherwise isolate which full-suite case crashes when the cap is raised to `9`. Only then retry a cap increase with full `moon test`, artifact validation/timing, and direct compare evidence.
