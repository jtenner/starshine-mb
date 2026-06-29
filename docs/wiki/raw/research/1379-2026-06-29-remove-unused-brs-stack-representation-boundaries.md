# Remove-unused-brs stack representation boundary audit

Date: 2026-06-29

## Scope

This note audits two remaining representation-sensitive RUB-Q surfaces where a tempting Binaryen-shaped rewrite would require Starshine to see a stack-only value shape that the current public HOT pipeline does not expose safely:

1. Child-less stack-payload `br_table` / switch forms around `FinalOptimizer::visitSwitch(...)` and early `optimizeSwitch(...)`.
2. Public stack-form unreachable-input `br_on_cast*` cleanup around `optimizeGC(...)`.

No new transform was added. This slice added focused boundary/representation coverage and records reopening criteria.

## Source and local evidence

Local oracle: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`wasm-opt version_130`).

### Switch / `br_table` value representation

Binaryen has two relevant switch cleanup sites:

- early `optimizeSwitch(...)`, which trims trailing defaults, offsets leading defaults, then immediately returns when `curr->value` exists before default-only / two-option / mostly-default switch-to-branch lowering;
- late `FinalOptimizer::visitSwitch(...)`, which collapses a unique-target switch to `drop(condition); br value` only when either there is no value or `EffectAnalyzer::canReorder(...)` proves the condition can move before the value.

Starshine already implements the public safe subset: value-carrying target-list cleanup, one-target value-switch collapse when selector/value order is locally safe, and no-payload default-only/two-option/mostly-default lowering.

The remaining "child-less stack-payload value switch" is a local representation boundary, not a public WAT implementation gap today:

- `src/ir/hot_lift.mbt` materializes public `Instruction::BrTable` by computing branch arity, popping the selector, and building BrTable children from the branch payload values plus the selector.
- `src/ir/hot_builders.mbt::hot_build_br_table(...)` likewise always appends the selector to the child list.
- `src/ir/hot_verify.mbt` expects a BrTable selector child when verifying a BrTable root.
- The new focused test proves a public value `br_table` lifts with two children for one payload plus selector and with default branch arity `1`.

So a child-less stack-payload BrTable would require new valid-HOT stack-payload representation and stack surgery around selector/value ordering before it can be implemented. Public stack-style WAT value switches remain covered because they lift to child-form payloads before the existing one-target value collapse sees them.

### Public stack-form unreachable-input BrOn

Binaryen `optimizeGC(...)` handles unreachable BrOn inputs through the same dropped-children / replacement machinery used for ordinary BrOn cleanup. Starshine's implemented safe subset handles child-form HOT `br_on_cast*` roots whose ref child is explicit `unreachable`, dropping payload children before replacing with `unreachable`.

The public stack-form case remains a narrower boundary: a valid public module can have an `unreachable` stack input before `br_on_cast`, and the pass currently preserves that stack-form `br_on_cast` rather than trying a raw stack rewrite. The new focused test locks that behavior so future widening must be deliberate.

Reopening requires one of:

- HOT lift exposes this public shape as a child-form BrOn root with explicit unreachable ref child, or
- a raw pre-lift rewrite proves stack effects, branch arity, dropped payload order, validation, and refinalization for the stack-form input.

Descriptor BrOn forms remain a separate representation blocker until local `Instruction`, binary, WAT, validator, and HOT support exist.

## Tests added

`src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs boundary represents public value br_table payloads as children`
- `remove-unused-brs boundary keeps public stack-form unreachable-input br_on_cast`

These are intentional boundary tests. They do not close the whole RUB audit; they narrow two remaining entries to exact representation/proof blockers.

## Commands

- Focused after the two boundary tests: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `210/210`.
- Slice validation: `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed; focused RUB tests `210/210`, `moon test src/passes` `3616/3616`.
- `moon info` passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` passed / no work to do.
- `git diff --check` passed with no output.
- Direct compare was not rerun in this slice because the pass implementation did not change; this slice only added boundary tests and documentation.

## Classification and reopening criteria

- Child-less stack-payload value switch: representation boundary. Reopen if HOT grows a verified stack-payload BrTable representation or another public/binary path can produce one safely; otherwise public WAT value switches are already child-form and covered by RUB-P.
- Public stack-form unreachable-input BrOn: candidate-lowering/raw-proof boundary. Reopen with a raw rewrite proof or a child-form HOT exposure path.
- Descriptor BrOn: still representation-blocked. Reopen only after adding local descriptor BrOn instruction, binary/WAT/validator, HOT lift/lower, and pass coverage.
