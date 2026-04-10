---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md
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

- The current validator fuzz lanes are useful, but they are not yet fully trustworthy as coverage evidence.
- The invalid lane still has at least one real correctness bug: `HeapTypeSwap` is miswired.
- Some reported strategies can be effectively dead because the valid-module generator is shaped around current mutation needs instead of broad module coverage.
- A rejected module only counts as meaningful coverage if the intended mutation ran and the diagnostic family matches the expected failure class.
- The valid lane should check stability across direct validation, encode/decode, and text roundtrips when practical.
- Heavy fuzz work stays in `src/fuzz`, not `moon test`.

## Main Gaps

- Strategy metadata is duplicated and can drift.
- Coverage accounting is too weak to fail on dead or barely exercised strategies.
- The generator over-biases toward always-on sections and misses imports, exports, absence-sensitive modules, and richer type shapes.
- The invalid lane is still AST-only and does not yet cover binary, text, or spec-seed invalidation families.
- Failures do not yet persist enough repro material.

## Hardening Order

1. Make current results trustworthy: fix `HeapTypeSwap`, centralize strategy metadata, require minimum exercised counts, and check expected diagnostic families.
2. Widen valid coverage: split broad sampling from forced-coverage generation and add encode/decode plus text stability checks.
3. Widen invalid coverage: add richer strategy families, binary/text invalid lanes, and spec-corpus seeding.
4. Improve CI ergonomics: persist repro artifacts, expose JSONL through the Bun wrapper, and keep heavier lanes behind explicit suites or profiles.

## Practical Rule

- Treat coverage as four separate facts: strategy available, strategy exercised, strategy rejected, and strategy rejected for the right reason.
- Keep the generator broad enough to represent real valid modules; add mutation-friendly forcing as a separate mode instead of hard-wiring it into every run.
- Add new heavy or differential validator fuzz lanes as `src/fuzz` suites so smoke and deterministic developer loops stay small.

## Sources

- Archived research doc: [`../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md`](../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md)
- Active backlog slices: [`../../../agent-todo.md`](../../../agent-todo.md)
