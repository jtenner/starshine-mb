# remove-unused-brs adjacent br_if + unconditional br cleanup

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Source audit

Primary source: Binaryen `version_130` `src/passes/RemoveUnusedBrs.cpp` late block/final optimizer loop.

The adjacent-branch pass scans a block list for a first `Break` with a condition, skips unreachable branch results, requires the next `Break` to have the same target, and asserts that both branches have no values. If the second branch is another `br_if`, Binaryen only merges under shrink and only when the later condition has no side effects, combining conditions with `OrInt32` and branch-hint `applyOrTo`. If the second branch is unconditional, Binaryen replaces the first `br_if` with `drop(condition)` because control reaches the same target regardless; this unconditional cleanup is not shrink-gated.

Local implication:

- The no-payload `br_if target cond; br target` child-form is a source-backed implementation gap.
- The stack-source WAT form `cond; br_if target; br target` lowers to HOT as a childless `BrIf` preceded by the condition root, so it needs the same cleanup.
- Value-carrying branches must stay conservative: Binaryen's source asserts no branch values in this adjacent cleanup, and value-carrying same-target branches can carry different payloads.
- Branch-hint `clear` behavior remains part of the broader unsupported branch-hint metadata boundary; Starshine has no local expression branch-hint representation.

## Red-first tests

Added focused positives:

- `remove-unused-brs drops adjacent br_if condition before same-target unconditional branch`
- `remove-unused-brs drops stack-form adjacent br_if condition before same-target branch`

Initial focused run failed `188/190` (the two new tests failed). Both outputs still contained `(call $side); br_if; br` in the optimized block, proving the cleanup was missing.

## Implementation

Updated `remove_unused_brs_try_merge_adjacent_br_ifs(...)` so it now handles Binaryen's unconditional same-target case before the shrink-only `br_if`/`br_if` merge:

- child-form no-payload `BrIf` followed by childless same-target `Br` becomes `drop(condition); Br`
- stack-form no-payload `condition; childless BrIf; childless same-target Br` becomes `drop(condition); Br`
- neither path speculates or removes the condition; side effects/traps in the condition are preserved by the new drop
- value-carrying forms are deliberately excluded by the child-count guards

Two existing branch-exit tests now collapse one step further after their prior `if { br } else { br }` rewrite exposes a same-target `br_if; br` pair. Their expectations were updated to require no `if`, no `br_if`, a preserved `br`, and the preserved condition evaluation.

## Boundary coverage

Added explicit fail-closed boundary:

- `remove-unused-brs boundary keeps value-carrying adjacent br_if before same-target branch conservative`

The fixture uses a result block where the conditional branch and unconditional branch carry different payloads. It must keep `br_if` and both payload constants.

## Validation

Completed so far in this slice:

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `188/190`; both new positives still contained `br_if`.
- Focused post-implementation run before boundary: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `190/190`.
- Focused run after boundary: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `191/191`.

Additional validation in the third work slice:

- `moon fmt` passed.
- `moon info` passed with 6 pre-existing warnings.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed (`191/191`, then `3597/3597`).
- `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- Refreshed direct compare smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-adjacent-brif-br-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. Result: requested `1000`, compared `1000`, `normalizedMatchCount=142`, `cleanupNormalizedMatchCount=858` (CLI label: compare-normalized matches), `mismatchCount=0`, `validationFailureCount=0`, `propertyFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`, command failure classes `{}`, cache `binaryenHits=1000`, `binaryenMisses=0`, wasm-smith hits/misses `0/0`, Binaryen failure cache hits/misses `0/0`.

Pass-local timing was not available from this compare slice.

## Status

The no-payload adjacent `br_if` + unconditional same-target `br` cleanup is implemented. The exact backlog phrase should no longer list that no-payload subset as open.

Remaining adjacent-branch boundaries:

- value-carrying adjacent branch cleanup / merge, source-backed by Binaryen's no-value asserts and protected locally by boundary coverage
- branch-hint metadata movement (`clear` / `applyOrTo`), already part of the RUB-N representation boundary
- broader final-optimizer value legality outside this adjacent cleanup
