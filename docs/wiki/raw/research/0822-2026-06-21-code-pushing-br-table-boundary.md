---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing `br_table` Boundary

## Question

Should the current Starshine `code-pushing` audit slice mutate SFA `local.set` windows before simple `br_table` / switch push points?

## Binaryen probes

Local oracle: `wasm-opt version 130 (version_130)`.

Boundary probes:

- `.tmp/cp-br-table-single-boundary-probe.wat` placed one pure SFA `local.set` before a no-branch-value `br_table $exit $exit` to the enclosing void block label, with a later suffix read after the `br_table`. Binaryen did **not** move the set.
- `.tmp/cp-br-table-multi-boundary-probe.wat` placed two adjacent pure SFA `local.set` roots before the same `br_table` shape, with suffix reads in source order. Binaryen did **not** move either set.

The observable boundary is important because `br_table` is an unconditional switch-like branch. The existing Starshine diagnostic may still classify `BrTable` as a switch push-point for inventory, but this slice does not turn that recognition into mutation.

## Implementation decision

No mutating code was widened in this slice.

`src/passes/code_pushing.mbt` already recognizes `HotOp::BrTable` as `"switch"` in `code_pushing_push_point_kind(...)` for analyzer/diagnostic inventory, while current mutating segment consumers accept only ordinary void `if`, dropped value-`if`, and the narrow no-branch-value `br_if` block-/loop-target family. The new tests make that boundary executable so future switch work must be source-backed and deliberate.

## Tests

Focused pass tests added in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps pure SFA set before br_table switch push point`;
- `code-pushing boundary keeps adjacent multi-set window before br_table switch push point`.

These are intentionally fail-closed boundary tests, not green no-op tests for a required transform. They protect the current Binaryen-backed observation that these simple `br_table` windows remain stationary.

## Validation

Commands run for this slice:

- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --code-pushing -S .tmp/cp-br-table-single-boundary-probe.wat -o .tmp/cp-br-table-single-boundary-probe.opt.wat`: kept the single SFA set before the `br_table`.
- `wasm-opt --all-features --code-pushing -S .tmp/cp-br-table-multi-boundary-probe.wat -o .tmp/cp-br-table-multi-boundary-probe.opt.wat`: kept both adjacent SFA sets before the `br_table`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*br_table*'`: passed `2/2`.

A full pass closeout matrix was not run because this was a bounded boundary-documentation/test slice, not final `[O4Z-AUDIT-CP]` closeout and not a new positive movement family. No `code-pushing-all` GenValid leaf was added because no mutation family landed.

## Boundaries

Still out of scope:

- switch/`br_table` mutation beyond these simple boundary probes;
- branch-value `br_table` payloads and multi-value labels;
- `br_on_*`, branch-value conditional branches, and broader conditional-branch mutation;
- arbitrary non-adjacent windows beyond the already documented separator families;
- local-copy dependency chains;
- atomics/GC/EH/trap-option widening;
- full `orderedBefore(...)` parity and final four-lane pass signoff.

## Reopening criteria

Reopen this boundary if a future Binaryen source/lit refresh or oracle probe demonstrates a `br_table` movement family Starshine can model safely, if direct compare exposes a non-cleanup-normalized semantic mismatch attributable to missing switch mutation, or if Starshine starts moving either protected boundary shape without a new source-backed transform and tests.
