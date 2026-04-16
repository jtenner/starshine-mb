---
kind: concept
status: working
last_reviewed: 2026-04-16
sources:
  - ../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md
  - ../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md
  - ../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_text.mbt
  - ../../../src/wast/spec_harness.mbt
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

- The current checked-in fuzz runner is now strong on valid-module coverage plus four distinct validator rejection lanes: AST-invalid, binary-invalid, text-invalid, and spec-seeded invalid/malformed/unlinkable replay.
- The active runnable suites are currently `validate-valid`, `validate-invalid-ast`, `validate-invalid-binary`, `validate-invalid-text`, `validate-invalid-spec-seed`, `binary-roundtrip`, `wast-roundtrip`, `wat-roundtrip`, and `cmd-harness`.
- The fuzz runner no longer carries reserved validator-rejection suite ids in the CLI; the next open work is persisted repro and replay ergonomics, not suite activation.
- The direct `validate-valid` generator loop is currently owned by `run_validate_valid_fuzz`, while `src/fuzz/main.mbt` layers the extra text companion checks on top.
- The widened `coverage-forced` `gen-valid` batch already exposed and now closed two concrete downstream `RUME` parity holes:
  - `remove-unused-module-elements` no longer preserves an unused imported function or its dead simple function type in the saved repro `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/`; see [`../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`](../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md).
  - `remove-unused-module-elements` now also matches Binaryen's no-op `start` pruning family for defined single-`nop` start targets, including the saved repros `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`; see [`../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`](../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md).
- The restored AST invalid lane now keeps one checked-in strategy registry and fails smoke runs when a required strategy never becomes applicable, never mutates, or never reaches the expected diagnostic family.
- The currently landed AST-invalid strategy set covers duplicate export names, invalid start signatures, missing datacount for `memory.init`, undeclared `ref.func`, and out-of-range function-name indices.
- The binary invalid lane now also keeps one checked-in byte-corruption registry and distinguishes two rejection stages per strategy: decode rejected vs decode succeeded but validator rejected.
- The currently landed binary-invalid strategy set covers trailing garbage, truncated modules, duplicate type sections, wrong section order, and out-of-range function-section type indices.
- The text invalid lane now keeps one checked-in inline text registry and distinguishes three stage outcomes per strategy: parse/lower rejected, validator rejected after lowering, and valid-before-link for unlinkable cases.
- The currently landed text-invalid strategy set covers a malformed quoted module, an invalid result-stack module, and a valid-but-unlinkable unknown import module.
- The spec-seed lane now samples selected `tests/spec` assertions from the `assert_malformed`, `assert_invalid`, and `assert_unlinkable` categories, extracts the raw target assertion S-expression, and then reuses the shared WAST static-assertion evaluator so corpus replay follows the same semantics as the spec harness.
- A rejected module only counts as meaningful coverage if the intended mutation ran and the diagnostic family matches the expected failure class.
- Heavy fuzz work stays in `src/fuzz`, not `moon test`.

## Main Gaps

- Shared generator config and feature-fact plumbing is now in-tree, but later widening and invalid-lane work still needs to keep reusing that one vocabulary instead of re-encoding policy at each callsite.
- Coverage accounting is too weak to fail on dead or barely exercised strategies.
- The widened valid generator now reaches imports, exports, and absence-sensitive topology, which means fuzz work must keep tracking and closing newly exposed downstream parity holes instead of assuming the old pass smoke remains representative. The first two exact `RUME` families surfaced by widened `gen-valid` coverage — unused imported functions/dead simple types and no-op `start`-section pruning for defined single-`nop` start targets — are now both closed, and the focused `gen-valid` `remove-unused-module-elements` smoke lane is back to `20/20` normalized matches.
- The AST, binary, text, and spec-seed invalid lanes are now all back in-tree, but only the first stage-aware deterministic cores are landed so far.
- The binary lane intentionally starts with a curated core instead of the full malformed-byte matrix; malformed LEBs, UTF-8 corruption, and richer immediate corruption families still remain open follow-up work.
- The text/spec-seed lanes intentionally stop at stage-aware deterministic coverage for this slice; persisted repro metadata, saved artifacts, and shrink/replay helpers still remain open follow-up work.
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
