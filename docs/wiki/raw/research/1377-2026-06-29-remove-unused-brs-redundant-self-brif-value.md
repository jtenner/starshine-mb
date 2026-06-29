# remove-unused-brs redundant self-target `br_if` value

Date: 2026-06-29

## Question

Does Starshine cover Binaryen `RemoveUnusedBrs.cpp`'s late block-tail cleanup where a dropped self-targeting `br_if` sends the same value that the block would otherwise fall through with?

## Binaryen source evidence

Local oracle: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp`.

In `FinalOptimizer::visitBlock(...)`, after adjacent `br_if` cleanup, Binaryen handles this block-tail shape:

- the second-to-last expression is `drop(br_if $block value condition)`;
- the target is the current block;
- the final expression is structurally equal to the branch value;
- the value has no unremovable side effects; and
- the condition does not invalidate the value effects.

When those checks pass, Binaryen replaces the dropped branch with a drop of the condition and keeps the final value as the block result. The source comment gives the local invalidation hazard: if the condition writes the value's source, removing the branch would make the fallthrough value observe the write on taken paths.

## Starshine implementation

Added a narrow HOT subset in `src/passes/remove_unused_brs.mbt`:

- matching result-typed `Block` bodies ending in `br_if; drop; value` or the equivalent child/drop forms;
- requiring the branch target to be the enclosing block label;
- requiring one branch payload and one condition;
- proving the payload and final value are the same for the local `LocalGet`/`Const` subset; and
- reusing the existing local-read invalidation guard, so a `local.tee` condition that writes a payload-read local stays conservative.

The rewrite replaces the branch/drop tail with `drop(condition)` and leaves the final value root in place.

## Tests

Added to `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs drops redundant self-target br_if value` — red-first public WAT fixture with a prefix root so this does not get absorbed by the earlier `restructureIf` prefix family.
- `remove-unused-brs keeps self-target br_if value when condition invalidates payload` — boundary fixture where a `local.tee` condition writes the local read by the branch payload/fallthrough value, matching Binaryen's invalidation comment.

## Validation

Focused red run before implementation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `204/205`; the positive fixture still contained the `br_if`/drop/value tail.

Post-implementation validation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `205/205`.
- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed; focused RUB tests `205/205`, pass package tests `3611/3611`.
- `moon info` passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- `git diff --check` passed with no output.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-self-brif-value-100-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `100/100`: `13` normalized, `87` cleanup-normalized, `0` mismatches, `0` validation/generator/property/command failures; cache had Binaryen `100` hits / `0` misses and wasm-smith `0` hits / `0` misses.

Pass-local timing was not available from this compare lane.

## Remaining boundaries

This slice intentionally does not implement arbitrary `ExpressionAnalyzer::equal(...)` parity. The local subset covers repeated `local.get` and constants. Reopen when a focused Binaryen/source-backed fixture needs a broader pure expression equality proof and a matching invalidation/effect model in HOT.
