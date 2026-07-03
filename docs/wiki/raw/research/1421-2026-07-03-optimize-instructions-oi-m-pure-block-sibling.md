# Optimize-instructions OI-M pure block tuple sibling slice

_Date:_ 2026-07-03  
_Status:_ bounded OI-M-SB004 implementation slice; OI-M remains active/P0

## Question

Can Starshine safely shrink the OI-M control-sibling blocker by handling a source-backed, branch-free block subset without claiming generalized control/branch/EH tuple reconstruction?

## Binaryen probes

Two local Binaryen v130 probes were added under `.tmp/`:

- `.tmp/oi-m-control-sibling-sb004-20260703.wat`
- `.tmp/oi-m-branch-sibling-sb004-20260703.wat`

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-control-sibling-sb004-20260703.wat -o .tmp/oi-m-control-sibling-sb004-20260703.binaryen.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-branch-sibling-sb004-20260703.wat -o .tmp/oi-m-branch-sibling-sb004-20260703.binaryen.wat
```

Findings:

- Binaryen localizes `tuple.extract(tuple.make(selected, pure block sibling))` and drops the unused pure block sibling.
- Binaryen also localizes a selected pure block lane by preserving the block as the selected value through local scratch traffic.
- Binaryen drops the branch-local sibling probe too, but that case needs label-containment/control-transfer reasoning in Starshine before it is safe to generalize. A branch whose target escapes the sibling block would not be equivalent to dropping the sibling.

## Starshine change

`src/passes/optimize_instructions.mbt` now treats branch-free `Block` lanes as directly localizable for the narrow tuple.extract direct localizer. The block case walks its body roots and rejects any root that is not recursively direct-localizable. The tuple sibling preservation predicate also handles branch-free blocks structurally: a block is droppable only when all body roots are direct-localizable and none must be preserved for effects or traps.

This converts the existing pure block sibling boundary into a positive test while adding a separate fail-closed branch-bearing block sibling test. The branch-bearing boundary is intentionally conservative even though Binaryen rewrites the local-branch probe, because Starshine does not yet prove that branch targets are contained inside the sibling block.

## Validation

- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*pure block tuple sibling*'` failed before implementation with `expected pure block sibling to be dropped, got TupleExtract`.
- Focused post-fix tuple sibling tests: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple sibling*'` passed `7/7`.
- Focused tuple.extract tests: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'` passed `21/21`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test src/passes` passed `3849/3849`.
- Full `moon test` passed `7247/7247`.
- Native build: `moon build --target native --release src/cmd` passed with pre-existing warnings.
- `git diff --check` passed.
- Grouped OI-M runtime sweep: `bun scripts/oi-parity-sweep.ts --family OI-M --count 108 --out-dir .tmp/oi-m-sb004-pure-block-count108-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --jobs auto --execute -- --runtime-execution node --max-failures 2000 --keep-going-after-command-failures` compared `108/108`, with `0` validation/generator/property/command/runtime failures, runtime checked/unsupported/failed `108/0/0`, runtime matrix `all-equal total=9`, all 18 OI-M tuple labels sampled, and `108` raw mismatches retained as active parity evidence.

## Closeout impact

OI-M-SB004 is narrowed but not closed:

- Covered now: branch-free pure/effect-preserving block lanes inside the direct one-use tuple.extract localizer, with unsupported body roots rejected recursively.
- Still blocked: branch target containment, loops, `if`, EH, nested control with escaping labels, and generalized structured reconstruction.

OI-M remains active/P0 because OI-M-SB005 generalized tuple-scratch reconstruction/localization is still open and SB004 still has branch/EH/control-transfer boundaries.

## Reopening criteria

Reopen this slice if a branch-free block lane is dropped despite effects/traps, if a branch/EH/control-transfer lane is localized without containment proof, if validation/runtime evidence fails, or if Binaryen source/lit evidence identifies a broader safe control subset that can be represented in Starshine HOT without label/exception-edge drift.
