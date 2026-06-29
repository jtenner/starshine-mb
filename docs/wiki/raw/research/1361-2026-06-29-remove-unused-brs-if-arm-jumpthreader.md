# Remove-unused-brs if-arm JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice audited Binaryen `version_130` JumpThreader behavior for branch expressions inside `if` arms, after the prior direct-`br` and small child-form `br_table` slices. The source model remains the same: `JumpThreader::visitExpression(...)` records no-value scope uses through `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`, and `redirectBranches(...)` applies `BranchUtils::replacePossibleTarget(...)` when a parent block is a one-child named block shell or when a child block is followed by a simple jump.

## Source and oracle probes

Local `wasm-opt --all-features --remove-unused-brs -S ... -o -` probes under `.tmp/rub-if-*.wat` found:

- direct no-payload `br $inner` inside an `if` arm under a one-child `$outer` / `$inner` shell becomes a `br_if $outer` after Binaryen's RUB pipeline;
- no-payload child-form `br_table $inner $outer $keep $keep` inside an `if` arm retargets the former `$inner` target to `$outer`;
- value-carrying/result-typed `br_table` inside an `if` arm remains outside this Starshine slice's implementation scope, matching the existing payload/sent-type boundary.

An old-`try` catch-body probe (`.tmp/rub-catch-direct-br-keep.wat`) shows Binaryen retargets a catch-body `br $inner` to `$outer`. Starshine's public WAT path still lowers legacy old-`try` into synthetic block/loop/unreachable structure before HOT, so catch-region JumpThreader is kept as a representation-blocked boundary for now rather than widened through the existing collector.

## Implemented or confirmed families

Starshine now handles audited `if`-arm branch threading as follows:

- direct no-payload `br` in the probed `if`-arm shell shape is already covered by existing if/branch-exit normalization to a no-payload `br_if`, which the prior JumpThreader subset retargets; a focused positive test now locks this behavior;
- small child-form no-payload `br_table` target retargeting is now admitted through `if` then/else regions while keeping direct `br` collection disabled there;
- catch regions and catch lists remain closed to direct `br` / `br_table` collection pending a representation-backed audit;
- payload/sent-type `br_table` in an `if` arm remains an explicit boundary.

Focused tests added in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs retargets direct if-arm branches through one-child named block shells`
- `remove-unused-brs retargets if-arm br_table targets through one-child named block shells`
- `remove-unused-brs boundary keeps value-carrying if-arm br_table threading conservative`

Red-first result before implementation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed at `remove-unused-brs retargets if-arm br_table targets through one-child named block shells` with the old inner target still present (`Some(1) != Some(0)`). The direct if-arm positive was already green via existing branch-exit/`br_if` behavior, so this slice did not widen direct-`br` collection inside `if` arms.

A deliberately broad implementation that allowed direct `br` collection through then/else regions reproduced the known interaction risk: existing branch-exit/carrier tests regressed, including `remove-unused-brs rewrites two-armed branch exits into br_if plus branch`, `remove-unused-brs rewrites branch-exit ifs even when neither target is the immediate holder`, and `remove-unused-brs preserves dropped typed if carriers that still need their drop`. The final implementation uses separate gates for direct `br` and `br_table` collection so only small no-payload `br_table` retargeting is newly admitted through `if` arms.

## Still open in JumpThreader

This is still not a full `BranchUtils::replacePossibleTarget(...)` port. Remaining open work under `[O4Z-AUDIT-RUB-Q]`:

- catch-region and catch-list direct `br` / `br_table` retargeting once a public or binary path exposes stable HOT `Try` / catch-region structure that can be tested without legacy-old-try lowering artifacts;
- larger stack-style no-payload `br_table` ladders and their interaction with existing switch-lowering expectations;
- payload/sent-type-preserving `br`, `br_if`, and `br_table` retargeting;
- broader multi-target branch-expression parity beyond the small arity-zero child-form table subset.

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Source probes: local `wasm-opt --all-features --remove-unused-brs -S ... -o -` on `.tmp/rub-if-direct-br-keep.wat`, `.tmp/rub-if-brtable-keep.wat`, `.tmp/rub-if-value-brtable-keep.wat`, and `.tmp/rub-catch-direct-br-keep.wat` confirmed the Binaryen behavior and old-try catch boundary described above.
- Red-first before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed at the if-arm `br_table` positive with the table target still pointing at the old inner label.
- Broad direct-arm attempt: focused tests failed in existing branch-exit/carrier coverage; the implementation was narrowed to `br_table` admission through if arms.
- Focused after final implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `178/178`.
- Package pass tests: `moon test src/passes` passed `3584/3584`.
- Native CLI build: `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Normalized direct compare smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-if-arm-thread-1000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`: `142` normalized matches, `858` cleanup-normalized matches, `0` raw mismatches, `0` validation failures, `0` generator failures, `0` property failures, and `0` command failures. Cache: Binaryen `1000` hits / `0` misses; wasm-smith `0` hits / `0` misses.

The compare lane did not report pass-local timing. No command/tool failures occurred in the normalized compare smoke.

## Next recommended RUB-Q slice

Continue JumpThreader before moving to GC or final-optimizer breadth:

1. Audit catch-region feasibility from the binary/HOT side and decide whether old-`try` exposure can be tested locally or must stay a representation blocker with exact reopening criteria.
2. Audit larger stack-style no-payload `br_table` JumpThreader ladders against `optimizeSwitch(...)` tests and Binaryen output, then either implement a proven-safe subset or keep the size/child-form guard documented.
3. Keep payload/sent-type retargeting separate until child/value preservation and sent-type evidence are source-backed.
