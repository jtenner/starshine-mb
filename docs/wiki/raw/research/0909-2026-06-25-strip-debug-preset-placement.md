---
kind: research
status: strong
created: 2026-06-25
sources:
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/strip_debug_test.mbt
  - ./0908-2026-06-25-strip-debug-custom-section-preservation.md
  - ../../../../agent-todo.md
---

# `strip-debug` preset placement

## Decision

Schedule `strip-debug` as the final public `optimize` and `shrink` preset pass, after `directize`.

Rationale:

- `0908` narrowed the direct pass to Binaryen-shaped name-section removal while preserving non-name custom sections.
- The pass is non-semantic and module-level, so late placement avoids interfering with any pass that may still use names for diagnostics, extraction, or user-directed policy.
- The existing public late tail was `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`; `strip-debug` now runs after that whole tail.

## Implementation

Updated `src/passes/optimize.mbt` in both preset-definition surfaces:

- registry `expanded_passes` for `optimize` and `shrink`;
- public `optimize_preset_passes(...)` and `shrink_preset_passes(...)` helpers.

Added/updated tests in `src/passes/optimize_test.mbt`:

- `optimize and shrink presets schedule strip-debug after all name-sensitive late passes` was red-first and failed with the previous final pair `reorder-globals`, `directize` and no `strip-debug` slot;
- late-tail tests now expect `... string-gathering -> reorder-globals -> directize -> strip-debug`;
- `optimize and shrink presets strip names while preserving non-name custom sections` proves the public presets remove `name_sec` and `raw_name_sec_payload`, preserve non-name custom sections, and validate the result.

Updated `src/passes/registry_test.mbt` so the active preset expansion fixture includes `strip-debug`.

## Validation

- Red-first focused preset-order test failed before implementation with the old final tail ending in `reorder-globals`, `directize`.
- `moon test --target native src/passes/optimize_test.mbt` passed `47/47`.
- `moon test --target native src/passes/registry_test.mbt -f 'preset expansion stays on implemented active pass names'` passed `1/1`.
- `moon test --target native src/passes/strip_debug_test.mbt` passed `3/3`.
- `moon fmt` passed.
- `moon info` passed with pre-existing `src/validate` warnings.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- `git diff --check` passed.

## Remaining work

`[JSON-AS]008` still needs json-as artifact custom-section size measurement after preset scheduling. The expected immediate win remains about `14.5KB` on medium-naive and `15.7KB` on large-swar before addressing deeper function/type cleanup.
