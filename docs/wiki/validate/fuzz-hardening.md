---
kind: concept
status: working
last_reviewed: 2026-04-16
sources:
  - ../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md
  - ../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md
  - ../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md
related:
  - ./trace-benchmark-baseline.md
  - ../tooling/fuzz-runner.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/validate/validate.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../agent-todo.md
---

# Validator Fuzz Hardening

## Durable Conclusions

- The current checked-in fuzz runner is strong on valid-module and roundtrip surfaces, but the explicit validator invalid/rejection lanes are not yet back in-tree.
- The active runnable suites are currently `validate-valid`, `binary-roundtrip`, `wast-roundtrip`, `wat-roundtrip`, and `cmd-harness`.
- The future validator invalid suite ids are now reserved in the CLI as `validate-invalid-ast`, `validate-invalid-binary`, `validate-invalid-text`, and `validate-invalid-spec-seed`, but they are intentionally reported as reserved until their implementation slices land.
- The direct `validate-valid` generator loop is currently owned by `run_validate_valid_fuzz`, while `src/fuzz/main.mbt` layers the extra text companion checks on top.
- The widened `coverage-forced` `gen-valid` batch already exposed one concrete downstream parity hole and now has a checked-in closure for it: `remove-unused-module-elements` no longer preserves an unused imported function or its dead simple function type in the saved repro `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/`; see [`../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`](../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md).
- The next downstream parity family from that same widened batch is now explicitly captured too: the remaining `RUME` smoke mismatches are a no-op `start`-section pruning family in `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`; see [`../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`](../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md).
- Some future invalid strategies can still be effectively dead if the valid-module generator stays shaped around narrow mutation prerequisites instead of broad valid coverage.
- A rejected module only counts as meaningful coverage if the intended mutation ran and the diagnostic family matches the expected failure class.
- Heavy fuzz work stays in `src/fuzz`, not `moon test`.

## Main Gaps

- Shared generator config and feature-fact plumbing is now in-tree, but later widening and invalid-lane work still needs to keep reusing that one vocabulary instead of re-encoding policy at each callsite.
- Coverage accounting is too weak to fail on dead or barely exercised strategies.
- The widened valid generator now reaches imports, exports, and absence-sensitive topology, but that broader surface also means fuzz work must track and close newly exposed downstream parity holes instead of assuming the old pass smoke remains representative. The imported-function `RUME` family is now fixed, and the latest focused smoke already shows the next distinct downstream family: Binaryen currently drops no-op `start` sections in two saved `gen-valid` cases while Starshine still preserves them; the exact saved repros and open rule questions are filed in [`0091`](../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md).
- The invalid lane is currently absent from the checked-in tree, so AST, binary, text, and spec-seed rejection work all still need explicit suites.
- Failures do not yet persist enough repro material.

## Hardening Order

1. Keep the suite surface truthful: separate active suites from reserved future invalid ids, keep help/list output honest, and avoid stale generator names.
2. Add shared config/stats plumbing: centralize mode, size, feature, and exercised-fact bookkeeping before widening behavior.
3. Widen valid coverage: split broad sampling from forced-coverage generation and add richer topology, bodies, and measurable breadth.
4. Widen invalid coverage: add AST, binary, text, and spec-seed invalid lanes with diagnostic-aware accounting.
5. Improve CI ergonomics: persist repro artifacts, expose machine-readable reporting, and keep heavier lanes behind explicit suites or profiles.

## Practical Rule

- Treat coverage as four separate facts: strategy available, strategy exercised, strategy rejected, and strategy rejected for the right reason.
- Keep the generator broad enough to represent real valid modules; add mutation-friendly forcing as a separate mode instead of hard-wiring it into every run.
- Add new heavy or differential validator fuzz lanes as `src/fuzz` suites so smoke and deterministic developer loops stay small.

## Sources

- Archived research doc: [`../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md`](../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md)
- Active backlog slices: [`../../../agent-todo.md`](../../../agent-todo.md)
