---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ../monomorphize/index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
---

# `monomorphize-always`

## Role

`monomorphize-always` is Binaryen's public sibling of [`../monomorphize/index.md`](../monomorphize/index.md). It uses the same whole-module direct-call contextual-specialization engine, but it keeps legal nontrivial specializations without ordinary `monomorphize`'s final usefulness rejection.

Current Starshine status:

- tracked as `boundary-only` in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- rejected when explicitly requested by the optimizer registry expansion guard
- not part of the current canonical no-DWARF `-O` / `-Os` path
- no dedicated backlog slice in [`../../../../../agent-todo.md`](../../../../../agent-todo.md) on 2026-04-24
- documented here as a future shared `monomorphize` / `monomorphize-always` module-pass port target

## Beginner summary

A good beginner mental model is:

1. Binaryen sees a direct call that gives extra information about a defined callee.
2. It builds a specialized clone of that callee.
3. It still rejects unsafe, trivial, recursive, imported, or too-large cases.
4. Ordinary `monomorphize` keeps the clone only if it appears useful enough.
5. `monomorphize-always` keeps the legal nontrivial clone even when that usefulness gate would reject it.

So the pass is:

- **contextual specialization without the final usefulness rejection**
- not a separate clone-construction algorithm
- not ordinary inlining
- not “specialize every call regardless of safety”

## Purpose

The pass is useful for:

- exposing weak-benefit but real contextual specializations
- testing the shared monomorphization engine without hiding legal clones behind the benefit policy
- teaching refined-reference and dropped-result specialization shapes that ordinary `monomorphize` may discard
- preserving a distinct public pass identity that Binaryen users can request directly

## Inputs and outputs

Inputs:

- a module with defined functions and direct calls
- call operands that can be moved into a callee clone without reordering visible effects
- optional refined reference or constant context at a callsite
- a shared monomorphization engine that can clone functions, repair signatures, and retarget calls

Outputs:

- zero or more cloned specialized functions
- retargeted original callsites
- repaired function signatures and local indexes/names inside clones
- optional dropped-result clones with `none` result type

No output is produced in current Starshine because the pass is boundary-only.

## Correctness constraints and invariants

A faithful implementation must preserve these invariants:

- Do not specialize imported callees.
- Do not specialize recursive self-calls that would create unsound or unbounded clone behavior.
- Do not move callsite context across effect/order barriers.
- Do not keep trivial passthrough clones.
- Do not exceed the pass-local parameter limit for the specialized signature.
- Do not absorb dropped results when return-call-sensitive code would make that unsafe.
- Preserve function types, callsite arity, local indexes, and local names after cloning.
- Run the same nested optimization expected by the upstream pass family.
- Keep the public policy split: `monomorphize-always` removes usefulness rejection, not safety rejection.

## Notable edge cases

- **Threshold-zero confusion:** upstream `--monomorphize --pass-arg=monomorphize-min-benefit@0` is closely related, but `monomorphize-always` remains a distinct public pass name.
- **Lit-test precision:** [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md) corrects the older loose wording: `monomorphize-types.wast` directly runs `--monomorphize-always`; `monomorphize-benefit.wast` supports the threshold-policy story but does not directly execute the sibling.
- **Starshine option plumbing:** Starshine parses and carries `monomorphize_min_benefit`, but that does not implement either `monomorphize` or `monomorphize-always`.
- **No default-pipeline role:** this folder is a widened registry-pass dossier, not evidence that the pass is required in the open-world no-DWARF parity path.

## How to validate the pass

For today's Starshine docs/status:

- confirm `pass_registry_boundary_only_names()` still contains `monomorphize-always`
- confirm explicit execution still rejects boundary-only entries in `run_hot_pipeline_expand_passes(...)`
- confirm no stale page claims that the pass is implemented locally

For a future implementation:

1. Add separate registry/CLI tests for `monomorphize` and `monomorphize-always`.
2. Reuse parent `monomorphize` clone-construction tests.
3. Add weak-benefit fixtures where ordinary `monomorphize` rejects but the sibling keeps a clone.
4. Compare against Binaryen on `monomorphize-types.wast`, because it directly exercises `--monomorphize-always`.
5. Run pass-targeted fuzz compare after the shared engine is already correct.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Binaryen source strategy and policy split.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Upstream owner-file and lit-test map.
- [`./usefulness-gate-and-sibling-split.md`](./usefulness-gate-and-sibling-split.md) - Focused guide to what “always” removes and what it keeps.
- [`./wat-shapes.md`](./wat-shapes.md) - Concrete before/after shape catalog.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Current Starshine boundary-only status and future port map.

## Maintenance rule

Keep this folder as the canonical home for `monomorphize-always` research. Keep it cross-linked to the parent [`../monomorphize/index.md`](../monomorphize/index.md), but do not merge the two dossiers: upstream publishes two public pass names, and Starshine tracks both names separately.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
