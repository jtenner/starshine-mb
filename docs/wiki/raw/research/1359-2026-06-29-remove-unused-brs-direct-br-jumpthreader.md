# Remove-unused-brs direct `br` JumpThreader slice

Date: 2026-06-29

## Scope

Recursive RUB complete-family slice under `[O4Z-AUDIT-RUB-Q]`.

This slice revisited the Binaryen `version_130` `JumpThreader` family beyond the previous no-payload `br_if` safe subset. Binaryen source evidence in `RemoveUnusedBrs.cpp` says `JumpThreader::visitExpression(...)` records no-value scope uses via `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`, and `redirectBranches(...)` applies `BranchUtils::replacePossibleTarget(...)` when a named block is a one-child named block shell or when a child block is followed by a simple `br`. `branch-utils.h` implements `replacePossibleTarget(...)` by replacing matching scope-name uses inside the branch expression.

## Implemented family

Starshine now retargets a narrow no-payload direct-`br` subset through the existing JumpThreader helper:

- source branch must be `HotOp::Br`
- branch must carry no payload children
- source and destination labels must both have branch arity zero
- retargeting is allowed through normal child/body-region traversal
- direct `br` in `if` arms and catch regions remains conservative for now, because an initial broad direct-`br` implementation changed existing Starshine branch-exit and dropped typed-carrier tests before the local interaction was audited

Focused red-first test added:

- `remove-unused-brs retargets direct branches through one-child named block shells`

The reduced source shape mirrors Binaryen behavior:

```wat
(module
  (func
    (block $outer
      (block $inner
        (block
          (br $inner)
          (drop (i32.const 9)))
        (drop (i32.const 1))))))
```

Local Binaryen `wasm-opt --all-features --remove-unused-brs -S` retargets the direct branch to `$outer`; the pre-change Starshine focused test failed with `Some(inner) != Some(outer)`. After the implementation, the focused pass test is green.

## Still open in JumpThreader

This is not a full `replacePossibleTarget(...)` port. The following remain open under `[O4Z-AUDIT-RUB-Q]` and should not be treated as completed by this slice:

- direct unconditional `br` retargeting inside `if` arms / catch regions after auditing interactions with Starshine branch-exit, carrier, and final-optimizer rewrites
- `br_table` retargeting
- payload/sent-type-preserving branch retargeting
- broader `replacePossibleTarget(...)` semantics for multi-target branch expressions

## Validation

Commands run from `/data/workspaces/229/starshine-sidework`:

- Red test before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed as expected at `remove-unused-brs retargets direct branches through one-child named block shells` with `Some(1) != Some(0)`.
- Focused after implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `171/171`.
- Package pass tests: `moon test src/passes` passed `3577/3577`.
- Native CLI build: `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare attempt without cleanup normalizers: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --out-dir .tmp/pass-fuzz-remove-unused-brs-direct-br-thread-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` timed out after 300s before `result.json`; it produced raw mismatch directories beginning with `.tmp/pass-fuzz-remove-unused-brs-direct-br-thread-1000/failures/case-000001-gen-valid/`. Sample classification: known cleanup-debris/output-shape family, not a command/tool failure and not directly attributable to the direct-`br` change.
- Direct compare refreshed with known RUB cleanup normalizers: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-direct-br-thread-1000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`: `142` normalized matches, `858` compare-normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` property failures, `0` command failures; Binaryen cache `200` hits / `800` misses.

## Next recommended RUB-Q slice

Continue JumpThreader before moving to GC:

1. Add red-first coverage for no-payload `br_table` retargeting through a one-child named block shell or child-block-to-following-simple-jump shape.
2. Implement retargeting by updating all matching table targets and default target through `hot_branch_table_set(...)`, preserving child-count / no-payload guards.
3. Add explicit negatives for value-carrying `br_table` / sent-type branches, and re-run focused RUB tests plus a normalized direct compare smoke.
