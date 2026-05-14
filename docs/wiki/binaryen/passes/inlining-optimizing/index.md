---
kind: entity
status: working
last_reviewed: 2026-05-14
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/index.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../precompute-propagate/index.md
---

# `inlining-optimizing`

## Role

`inlining-optimizing` is Binaryen's late whole-module inliner with immediate post-inline cleanup. It uses the same upstream `src/passes/Inlining.cpp` engine as plain [`../inlining/index.md`](../inlining/index.md), then enables the optimizing suffix: `precompute-propagate` plus the default function optimization pipeline on changed functions.

Current Starshine status: **partial active module pass**. It is not boundary-only anymore, and the current supported direct-call surfaces are accepted under former `[INL]001` and plain `[INL]007`, but the whole optimizing pass is not fully signed off. The shared owner is [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt); the active backlog now remains `[INL]002` plus deferred direct-inliner breadth slices `[INL]003`, `[INL]005`, and `[INL]006` in [`agent-todo.md`](../../../../../agent-todo.md).

## Why it matters

- This is the inlining variant on the canonical no-DWARF late optimize path, after `dae-optimizing` and before `duplicate-function-elimination`.
- The saved generated-artifact `-O4z` audit recorded it as top-level slot `49`.
- The saved Binaryen debug log shows nested cleanup under this single top-level pass: repeated `precompute-propagate`, `ssa-nomerge`, `code-folding`, `local-cse`, and `merge-blocks` before Binaryen moves to `duplicate-function-elimination`.
- Current Starshine has an accepted direct-call subset for the current supported surface, but future agents still need a clear distinction between that accepted subset, the remaining scheduler work, and deferred unsupported Binaryen obligations.

## Beginner summary

A safe mental model:

1. Run the whole-module inliner: summarize functions, classify callees, plan direct callsites, rewrite copied bodies, repair locals/control/types, delete dead private helpers.
2. Record exactly which functions changed.
3. Run the useful cleanup sequence on those touched functions only.
4. Continue into the late function-graph cleanup tail.

That is much closer to reality than “more aggressive inlining.”

## Current durable takeaways

- The core inliner is module-level boundary work, not HOT-local peepholing.
- Reviewed `version_129` chosen inline actions are direct `call` / `return_call` based; `ref.func` and ref/indirect calls remain relevant to survival and repair.
- The optimizing suffix is part of the public contract, not optional polish.
- Starshine's current cleanup suffix is an approximation: trace marker plus broad cleanup lane with untouched-function restoration and touched unused-local compaction, not exact Binaryen filtered `precompute-propagate` + default function pipeline.
- The current `[INL]003` heuristic sub-slices recognize repeated parameter-passthrough binary wrappers, `select` wrappers, and memory/table operation wrappers as shrinking trivial candidates; remaining heuristic/action-filtering breadth is still active.
- Latest accepted direct evidence is validation-clean and green for optimizing over the recorded compared lanes; the latest `[INL]003` `table.init` smoke also stays green for optimizing over `199/200` compared cases.

## Current Starshine evidence

Standard seed lane, `.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier`:

- seed `0x5eed`;
- `9975 / 10000` compared;
- `9975` normalized matches;
- `0` normalized mismatches;
- `0` validation failures;
- `0` generator failures;
- `25` ignored Binaryen/tool parse/canonicalization command failures:
  - `22` `binaryen-rec-group-zero`;
  - `1` `binaryen-bad-section-size`;
  - `1` `binaryen-table-index-out-of-range`;
  - `1` `binaryen-invalid-tag-index`.

Broadened closure lane, `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2`:

- seed `0x1eed`;
- `9978 / 10000` compared;
- `9978` normalized matches;
- `0` normalized mismatches;
- `0` validation failures;
- `0` generator failures;
- `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures;
- `0` Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

The old seed-`0x5eed` exact-`unreachable` helper frontier and the broadened seed-`0x1eed` four-function frontier are retired. `[INL]001` is accepted for the current supported optimizing direct surface, and `[INL]007` is accepted for the current supported plain direct surface. Keep `[INL]002` active for the exact nested scheduler and track deferred unsupported direct-inliner breadth under `[INL]003`, `[INL]005`, and `[INL]006`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream strategy with the optimizing suffix centered.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Binaryen owner/helper/test map and current Starshine code/test map.
- [`./planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md) - focused planner/root/partial/rerun explainer.
- [`./wat-shapes.md`](./wat-shapes.md) - WAT shape catalog including cleanup payoff and current gaps.
- [`./starshine-strategy.md`](./starshine-strategy.md) - active partial implementation status.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - evidence ledger, remaining slices, and acceptance criteria.

## Maintenance rule

Update this folder whenever the shared inliner changes, but do not claim `inlining-optimizing` parity until both halves are proven: Binaryen-equivalent inlining core and Binaryen-equivalent touched-function nested cleanup. Binaryen/tool parse/canonicalization failures must stay classified separately from Starshine semantic mismatches.
