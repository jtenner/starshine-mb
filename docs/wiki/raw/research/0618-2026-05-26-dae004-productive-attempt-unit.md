# DAE004 productive attempt unit

Date: 2026-05-26

## Scope

Recovery continuation for `[DAE]004` after research note `0617` extracted the descending selected-def ordering helper. This slice narrows the remaining ninth-cap investigation surface without changing runtime behavior.

## Change

Added `dae_collect_descending_selected_def_attempts`, a bounded variant of the descending selected-def collector. The existing unbounded `dae_collect_descending_selected_def_candidates` now delegates to it with an unlimited sentinel, so the active large-module dropped-result scheduler keeps the same candidate traversal and productive cap (`8`) as before.

Added the whitebox unit `dae descending dropped-result scheduler caps productive attempts after ordering`, which proves a ninth-attempt view would choose the ordered high candidates `4509..4501` before any low candidates. This isolates ordering-plus-cap selection from expensive 4k+ function optimizer fixtures and sets up the next investigation to focus on the actual productive rewrite loop or the full-suite instability observed in note `0616`.

## TDD evidence

- Initial focused test failed to compile because `dae_collect_descending_selected_def_attempts` was unbound.
- After extracting the bounded helper and delegating the unbounded helper through it, the focused test passed:
  - `moon test src/passes/pass_manager_wbtest.mbt --target native --filter '*scheduler caps productive attempts*'`
  - result: `Total tests: 1, passed: 1, failed: 0.`

## Classification

Diagnostic/recovery scaffold. This does not raise the large-module productive cap, remove the selected-def fallback, or prove the ninth dropped-result rewrite is safe. `[DAE]004` remains open with the note `0616` ninth-cap full-suite `SIGSEGV` still classified as blocked/unknown-risky.

## Next step

Use the bounded helper to isolate the productive rewrite loop or identify the full-suite case that crashes when the cap is raised to `9`. Only retry a behavior-changing cap increase with full `moon test`, debug-artifact validation/timing, and direct compare evidence.
