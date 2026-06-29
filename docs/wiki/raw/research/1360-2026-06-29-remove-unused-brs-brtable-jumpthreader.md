# Remove-unused-brs `br_table` JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice continues the Binaryen `version_130` `JumpThreader` audit after the direct-`br` subset in [`1359`](1359-2026-06-29-remove-unused-brs-direct-br-jumpthreader.md). Binaryen source evidence remains the same: `JumpThreader::visitExpression(...)` records no-value scope uses through `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`, and `redirectBranches(...)` applies `BranchUtils::replacePossibleTarget(...)` when redirecting one-child named block shells and child-block-to-following-simple-jump shapes. For multi-target branch expressions, `replacePossibleTarget(...)` rewrites matching scope-name uses in both explicit table targets and the default target when the sent-type constraints allow it.

Local Binaryen probes with `wasm-opt --all-features --remove-unused-brs -S` confirmed the intended no-payload table behavior:

- one-child shell probe: a `br_table $inner $outer $keep $keep` inside `$inner` becomes a table whose former `$inner` target is `$outer`
- child-to-following-simple-jump probe: a `br_table $child $outer $keep $keep` inside `$child` followed by `br $outer` becomes a table whose former `$child` target is `$outer`
- value-carrying probe: a result-typed `br_table $inner $outer $keep $keep (i32.const 42) (local.get 0)` is not retargeted by this Starshine slice and is protected as a boundary until payload/sent-type preservation is audited locally

## Implemented family

Starshine now retargets a narrow no-payload `br_table` subset through the existing JumpThreader helper:

- source branch must be `HotOp::BrTable`
- branch table must be child-form with exactly one child, the selector
- all table/default labels must have branch arity zero
- table target count must be small (`<= 4`) to avoid reopening the existing large mostly-default stack-style switch-lowering expectations before that interaction is audited
- retargeting is allowed through normal child/body-region traversal, matching the same region boundary as the direct-`br` slice
- direct collection stays disabled under `if` then/else and catch regions pending a separate local branch-exit/carrier audit
- retargeting rewrites every matching explicit target plus the default target with `hot_branch_table_set(...)`

Focused tests added in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs retargets br_table targets through one-child named block shells`
- `remove-unused-brs retargets br_table default target through one-child named block shells`
- `remove-unused-brs retargets br_table child block targets to a following simple jump`
- `remove-unused-brs boundary keeps value-carrying br_table jump-threading conservative`

Red-first result before implementation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed at the two positive `br_table` tests with `1 != 0`, proving Starshine still preserved the old inner/child label as the first table target.

An initial implementation that admitted larger table shapes regressed the existing switch-lowering fixtures `remove-unused-brs lowers nested stack-style large mostly-default br_table` and `remove-unused-brs keeps below-threshold mostly-default br_table`. The final implementation keeps the small child-form subset and leaves larger stack-style table retargeting open instead of silently changing that local switch-cleanup family.

## Still open in JumpThreader

This is not a full `BranchUtils::replacePossibleTarget(...)` port. The following remain open under `[O4Z-AUDIT-RUB-Q]`:

- direct `br` and `br_table` retargeting inside `if` arms / catch regions after auditing interactions with Starshine branch-exit, carrier, and final-optimizer rewrites
- larger stack-style no-payload `br_table` ladders and their interaction with existing `optimizeSwitch(...)` expectations
- payload/sent-type-preserving `br`, `br_if`, and `br_table` retargeting
- broader multi-target branch-expression parity beyond the small arity-zero table subset

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Source probes: three local `wasm-opt --all-features --remove-unused-brs -S` WAT probes under `.tmp/rub-brtable-*.wat` confirmed Binaryen retargets the two no-payload child-form tables and preserves the value-carrying table shape for this slice's boundary.
- Red test before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed at the two new positive `br_table` JumpThreader tests with `1 != 0`.
- Focused after final implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `175/175`.
- Package pass tests: `moon test src/passes` passed `3581/3581`.
- Native CLI build: `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Normalized direct compare smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-brtable-thread-1000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`: `142` normalized matches, `858` cleanup-normalized matches, `0` raw mismatches, `0` validation failures, `0` generator failures, `0` property failures, and `0` command failures. Cache: Binaryen `1000` hits / `0` misses; wasm-smith `0` hits / `0` misses.

The compare lane did not report pass-local timing. No command/tool failures occurred in the normalized compare smoke.

## Next recommended RUB-Q slice

Continue JumpThreader before moving to GC or final-optimizer breadth:

1. Audit direct `br` / `br_table` retargeting under `if` then/else and catch regions against the existing branch-exit, payload-carrier, and final-optimizer rewrite tests that regressed during the earlier broad direct-`br` attempt.
2. Add red-first positives only for source-backed safe arm/catch shapes, plus explicit boundary tests for shapes that Binaryen retargets but Starshine cannot yet preserve safely.
3. Implement only the audited subset, validate focused RUB tests, `moon test src/passes`, native build, and a normalized direct compare smoke; update this dossier/backlog/log again.
