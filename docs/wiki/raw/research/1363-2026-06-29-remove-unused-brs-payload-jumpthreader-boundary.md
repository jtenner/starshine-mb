# Remove-unused-brs payload JumpThreader boundary slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice audited the remaining "payload/sent-type JumpThreader" item left open by the prior direct-`br`, `br_table`, `if`-arm, and stack-source table slices. The result is a narrow source-backed non-goal for Binaryen `version_130` JumpThreader, not a new transform: Binaryen's JumpThreader only records branch uses whose sent type is `Type::none`.

## Source evidence

The official `version_130` source model is precise:

- `RemoveUnusedBrs.cpp` `JumpThreader::visitExpression(...)` calls `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`, then inserts a target into `relevantTargets` only when `sent == Type::none`.
- `JumpThreader::redirectBranches(...)` later calls `BranchUtils::replacePossibleTarget(...)` for those recorded expressions.
- `branch-utils.h` computes sent types for `Break`, `Switch`, `BrOn`, `TryTable`, `Resume`, and `ResumeThrow`; for `Break` and `Switch`, a value child produces a non-none sent type.

Therefore payload-carrying `br`, `br_if`, and `br_table` uses are deliberately excluded before `replacePossibleTarget(...)` can rewrite their labels. Starshine's existing guard that requires `from_label` and `to_label` branch arity zero for the JumpThreader retarget helper is consistent with that source contract.

## Binaryen probes

Local probes were written under `.tmp/rub-payload-*.wat` and run with `wasm-opt --all-features --remove-unused-brs -S ... -o -`:

- `.tmp/rub-payload-direct-boundary.wat`: a direct `br $inner (i32.const 42)` inside an `$outer` / result-typed `$inner` one-child shell kept the `$inner` target.
- `.tmp/rub-payload-brif-boundary.wat`: a dropped payload `br_if $inner (i32.const 42) (local.get 0)` kept the `$inner` target.
- `.tmp/rub-payload-brtable-boundary.wat`: a payload `br_table $inner $outer $keep $keep (i32.const 42) (local.get 0)` kept the `$inner` target.

These probes avoid treating other RUB phases such as selectification or switch cleanup as JumpThreader evidence. They match the source-level `sent == Type::none` filter.

## Test changes

Added explicit boundary coverage in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs boundary keeps value-carrying direct br jump-threading conservative`
- `remove-unused-brs boundary keeps value-carrying br_if jump-threading conservative`

Updated existing value-carrying `br_table` boundary comments to cite Binaryen's no-sent-value JumpThreader filter instead of leaving the reason as unaudited local caution.

These are intentionally boundary/fail-closed tests, not red-first positives, because the audited Binaryen source does not contain a payload JumpThreader transform to implement. Reopen only if a newer Binaryen source changes `JumpThreader::visitExpression(...)` to record non-`Type::none` sent types or adds a separate payload-aware retargeting phase.

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Source/probe command: `wasm-opt --all-features --remove-unused-brs -S .tmp/rub-payload-direct-boundary.wat -o -`, `...brif-boundary.wat`, and `...brtable-boundary.wat`; all kept the original value-carrying `$inner` target.
- Focused tests after adding boundary coverage: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `183/183`.

No behavior implementation was made, so no native build or compare-pass lane was needed for this boundary-only slice. Pass-local timing was not available.

## Still open after this slice

This removes payload/sent-type JumpThreader retargeting from the open transform list as a source-backed non-goal for Binaryen `version_130`. Other payload/value families remain open where Binaryen actually has transform code, including broader `br_on_*` payload/prefix cleanup, result-typed `sinkBlocks`, payload/value adjacent-branch and final-optimizer cases, payload/value `tablify`/`visitSwitch` cases, and broader select/restructure/set-if value legality.

The next RUB-Q slice should move to catch-region/catch-list JumpThreader representation or one of the remaining source-backed non-JumpThreader families rather than trying to implement payload branch retargeting without upstream source support.
