# 1375 - remove-unused-brs medium br_table JumpThreader guard

Date: 2026-06-29

## Question

Continue `[O4Z-AUDIT-RUB-Q]` by revisiting the remaining `br_table` JumpThreader guard. Prior RUB-Q work retargeted no-payload HOT `br_table` targets/defaults only when the branch table had at most eight explicit targets; the dossier still listed larger mostly-default tables as blocked because a broad retargeting attempt regressed switch-lowering expectations.

## Source evidence

Local Binaryen oracle source is `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`version_130`). `JumpThreader::visitExpression(...)` records branch targets through `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`, but only when the sent type is `Type::none`. `JumpThreader::visitBlock(...)` then redirects those no-payload branch uses through one-child named block shells or child-block-to-following-simple-jump shells with `BranchUtils::replacePossibleTarget(...)`.

That source has no small-table cutoff. The local Starshine cutoff was a defensive implementation guard in `remove_unused_brs_branch_table_can_retarget_without_payload(...)`, not an upstream semantic rule.

## Red-first probe and regression boundary

Added focused coverage in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs retargets medium br_table targets through one-child named block shells`

The fixture has one selector child, no branch payloads, nine explicit table targets, and two `$inner` targets that should retarget to the enclosing `$outer` one-child shell.

Red-first result before implementation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `201/202`; the first table target still referenced the inner label (`1 != 0`).

A deliberately broad experiment raised the cutoff to `32`, but it regressed the existing switch-shape tests:

- `remove-unused-brs lowers nested stack-style large mostly-default br_table`
- `remove-unused-brs keeps below-threshold mostly-default br_table`

Those failures showed the prior warning was real: broad no-payload table retargeting changes the structure that early mostly-default switch lowering expects to see. The implemented subset therefore raises the guard only from `8` to `9`, admitting the next medium JumpThreader case without crossing the existing 11+/13+ mostly-default switch fixtures.

## Implementation

`src/passes/remove_unused_brs.mbt` now allows no-payload HOT `BrTable` retargeting when the explicit-target count is at most `9` instead of `8`, while preserving the existing safety gates:

- op must be `BrTable`;
- child count must be `0` or `1` (selector-only, no payloads);
- default and explicit targets must all have branch arity `0`;
- actual retargeting still uses `hot_branch_table_set(...)` and only rewrites labels equal to the threaded source label.

This is intentionally a narrow source-backed increment, not full large-table parity.

## Validation

Completed during the implementation loop:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` — initial red probe failed `201/202` before implementation.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after cutoff `32` experiment — failed existing large mostly-default switch tests, proving the broad cutoff was unsafe for current switch-lowering expectations.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after final cutoff `9` — passed `202/202` at that point in the thread.

Combined thread validation after the medium-table and legacy-try slices:

- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` — passed; focused RUB tests `203/203`, `moon test src/passes` `3609/3609`.
- `moon info` — passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with 27 pre-existing pass-manager unused-function warnings.
- `git diff --check` — passed with no output.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-medium-brtable-legacy-100-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — compared `100/100`: `13` normalized, `87` cleanup-normalized, `0` mismatches, `0` validation/generator/property/command failures. Cache: Binaryen `100` hits / `0` misses; selected profile `binaryen-oracle-portable=100`.

Pass-local timing was not available from this compare lane.

## Status update

Implemented:

- no-payload medium `br_table` JumpThreader retargeting through one-child named block shells for selector-only HOT tables with up to nine explicit targets.

Still open / blocked:

- large mostly-default `br_table` JumpThreader beyond the nine-target guard remains blocked by switch-lowering shape interactions. Reopen with a more precise retargeting predicate that can distinguish JumpThreader-only shell cases from early `optimizeSwitch(...)` mostly-default lowering candidates, plus red-first tests that preserve both existing large switch expectations.
- payload/sent-type table retargeting remains a Binaryen `version_130` non-goal for this JumpThreader source path because upstream only records `Type::none` sent-type uses.
