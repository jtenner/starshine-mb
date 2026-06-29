# Remove-unused-brs stack-source `br_table` JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice audited the remaining no-payload `br_table` JumpThreader gap that was left open after the child-form table slice in [`1360`](1360-2026-06-29-remove-unused-brs-brtable-jumpthreader.md) and the if-arm slice in [`1361`](1361-2026-06-29-remove-unused-brs-if-arm-jumpthreader.md). The local Binaryen oracle is still `wasm-opt version 130 (version_130)`, and the relevant source model is still `JumpThreader::redirectBranches(...)` plus `BranchUtils::replacePossibleTarget(...)`: no-value scope-name uses may be retargeted through one-child named block shells or child blocks followed by a simple jump when sent-type constraints allow the replacement.

## Source and probe evidence

Local probes with `wasm-opt --all-features --remove-unused-brs -S` under `.tmp/rub-stack-brtable-*.wat` showed:

- `rub-stack-brtable-one-child.wat`: a stack-source `br_table $inner $keep $other $outer $keep $other` inside an `$outer` / `$inner` one-child shell retargets the former `$inner` target to `$outer`; nested `$keep` also retargets to `$other` because it is itself a one-child shell.
- `rub-stack-brtable-child-jump.wat`: a stack-source `br_table $child ...` inside `$child` followed by `br $outer` retargets the former `$child` target to `$outer`; the redundant following jump is removed by later cleanup.
- `rub-stack-brtable-large-mostly-default-retarget.wat`: Binaryen also retargets a larger mostly-default table target through the shell, but this shape directly overlaps Starshine's existing early `optimizeSwitch(...)` fixtures.
- `rub-stack-value-brtable-boundary.wat`: a value-carrying/result-typed stack-source table is not retargeted by Binaryen in the probed shape, and Starshine keeps the corresponding HOT payload-carrying form conservative.

A broad Starshine experiment that removed the table-size guard reproduced the known switch interaction: focused RUB tests regressed `remove-unused-brs lowers nested stack-style large mostly-default br_table` and `remove-unused-brs keeps below-threshold mostly-default br_table`. The final implementation therefore widens the table JumpThreader subset only to small/medium no-payload tables with at most eight explicit targets. This is enough to cover the audited >4 stack-source target-list forms without reopening the existing mostly-default switch-lowering contract.

## Implemented family

Starshine now retargets no-payload `br_table` targets/defaults through JumpThreader when:

- the HOT node is `HotOp::BrTable`;
- the table has either no HOT children or one selector child;
- every explicit target and the default label has branch arity zero;
- the explicit target count is `<= 8`;
- ordinary JumpThreader shell rules prove either a one-child named block shell or child-block-to-following-simple-jump shape; and
- the containing traversal gate allows table retargeting.

Focused tests added in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs retargets stack-source br_table targets through one-child named block shells`
- `remove-unused-brs retargets stack-source br_table child block targets to a following simple jump`
- `remove-unused-brs boundary keeps value-carrying stack-source br_table threading conservative`

The first two positives were red before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed with the former inner/child label still present as the first table target (`1 != 0`). The value-carrying boundary stays green and records that the stack-source WAT lowers to a payload-carrying HOT table with two children, which is still outside the sent-type retargeting slice.

## Still open in JumpThreader

This is still not a full `BranchUtils::replacePossibleTarget(...)` port. Remaining boundaries under `[O4Z-AUDIT-RUB-Q]` are now narrower:

- catch-region/catch-list direct `br` / `br_table` retargeting until a HOT old-`try` / catch representation is locally testable;
- large mostly-default table retargeting beyond the `<= 8` guard because it interacts with the local `optimizeSwitch(...)` lowering expectations and needs a dedicated ordering/profitability proof before widening;
- payload/sent-type-preserving `br`, `br_if`, and `br_table` retargeting;
- broader multi-target branch-expression parity beyond the arity-zero small/medium table subset.

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Binaryen probes: `wasm-opt --all-features --remove-unused-brs -S .tmp/rub-stack-brtable-one-child.wat -o -`, `...child-jump.wat`, `...large-mostly-default-retarget.wat`, and `...stack-value-brtable-boundary.wat`; the no-payload probes retargeted in Binaryen, the larger mostly-default probe exposed the switch-interaction risk, and the value-carrying probe stayed boundary.
- Red-first before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed at the two new stack-source table positives with `1 != 0` while the corrected value-carrying boundary passed.
- Broad implementation experiment: removing the size guard made the new positives retarget but regressed the existing switch tests `remove-unused-brs lowers nested stack-style large mostly-default br_table` and `remove-unused-brs keeps below-threshold mostly-default br_table`; the landed implementation restored a `<= 8` explicit-target guard.
- Focused after final implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `181/181`.
- Package pass tests: `moon test src/passes` passed `3587/3587`.
- Native CLI build: `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Normalized direct compare smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-stack-table-thread-1000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`: `142` normalized matches, `858` cleanup-normalized matches, `0` raw mismatches, `0` validation failures, `0` generator failures, `0` property failures, and `0` command failures. Cache: Binaryen `1000` hits / `0` misses; wasm-smith `0` hits / `0` misses.

The compare lane did not report pass-local timing. No command/tool failures occurred in the normalized compare smoke.

## Next recommended RUB-Q slice

Continue JumpThreader/payload work before moving to broader GC/final-optimizer breadth:

1. Audit payload/sent-type retargeting for direct `br`, `br_if`, and `br_table` against Binaryen `operateOnScopeNameUsesAndSentTypes(...)` / `replacePossibleTarget(...)`, using result-typed shells and existing carrier tests as interaction coverage.
2. Add red-first positives only for payload forms that can preserve HOT child order and branch arity exactly; add explicit boundaries for stack-payload or mixed-arity forms that remain unaudited.
3. Implement only the audited safe subset, or document a narrow blocker with source/probe evidence; rerun focused RUB tests, `moon test src/passes`, native build if behavior changes, a normalized direct compare smoke, and update the RUB docs/backlog/log again.
