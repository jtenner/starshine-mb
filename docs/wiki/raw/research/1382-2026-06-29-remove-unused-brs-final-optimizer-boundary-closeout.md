# remove-unused-brs final-optimizer boundary closeout

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Question

Do the remaining late `FinalOptimizer::visitBlock(...)` adjacent-branch and self-target `br_if` value entries still need implementation work, or are they already either implemented or narrow source-backed boundaries?

## Source evidence

Primary source: local Binaryen `version_130` `.tmp/binaryen-v130/RemoveUnusedBrs.cpp`, especially `FinalOptimizer::visitBlock(...)`.

The adjacent branch loop requires a first conditional `Break`, skips unreachable branches, asserts the first branch has no value, then requires the next `Break` to target the same label and asserts that the second branch has no value too. If the second branch is conditional, Binaryen merges only under shrink and only when the later condition has no side effects. If the second branch is unconditional, Binaryen replaces the first branch with `drop(condition)` and leaves the unconditional branch.

The redundant self-target value cleanup requires a block tail shaped like `drop(br_if $block value condition); value`, requires the target to be the enclosing block label, checks `ExpressionAnalyzer::equal(value, final)`, rejects values with unremovable side effects, and rejects conditions that invalidate the value effects.

## Local status

The adjacent branch family is closed for the representable no-payload subset:

- child-form `br_if target cond; br target` is implemented by `remove_unused_brs_try_merge_adjacent_br_ifs(...)`;
- lifted stack-form `cond; br_if target; br target` is implemented by the same helper; and
- shrink-mode adjacent `br_if`/`br_if` merging remains covered for side-effect-free later conditions.

The value-carrying adjacent branch family is a source-backed boundary, not an unimplemented Binaryen transform family, because Binaryen asserts both adjacent branches have no values in this path. Starshine keeps value-carrying adjacent branches conservative and has focused coverage for the different-payload case.

The redundant self-target value family is closed for the local equality subset from note `1377`:

- repeated `local.get` payload/fallthrough equality;
- constant payload/fallthrough equality; and
- the Binaryen-source invalidation hazard where `local.tee` in the condition writes the local read by the value.

This slice added focused coverage for the constant equality subcase: `remove-unused-brs drops redundant self-target br_if constant value` in `src/passes/remove_unused_brs_test.mbt`. No pass implementation change was needed; this is coverage for the already-implemented constant arm of `remove_unused_brs_nodes_are_known_equal_for_redundant_br_if_value(...)`.

Broader `ExpressionAnalyzer::equal(...)` parity remains intentionally narrow: reopening needs a focused source-backed pure-expression fixture plus a HOT structural equality and invalidation/effect proof. Until then, the local subset is documented rather than silently implying arbitrary structural equality.

## Validation

Validation is recorded in the enclosing three-slice handoff iteration and summarized in note `1384`. This slice itself changed test/docs coverage only and did not change `remove-unused-brs` transform behavior; a bounded direct compare was nevertheless refreshed in `.tmp/pass-fuzz-remove-unused-brs-rub-q-boundary-closeout-1000-normalized` and reported `1000/1000` compared, `142` normalized matches, `858` cleanup-normalized matches, `0` mismatches, and `0` validation/generator/property/command failures.

## Status

Final adjacent/self-target late-block cleanup wording should now be treated as closed except for explicit accepted boundaries:

- branch-hint metadata and `never-unconditionalize` remain the RUB-N representation/options boundary;
- adjacent same-target value-carrying branches stay conservative per Binaryen `version_130` no-value asserts;
- broader self-target `ExpressionAnalyzer::equal(...)` support stays reopenable only with a focused proof/fixture.
