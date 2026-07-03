# Optimize-instructions OI-M multi-result non-selected sibling localization

_Date:_ 2026-07-03

_Status:_ implementation slice for `OI-M-SB002` under the active OI-M parity matrix row

## Question

Can Starshine safely shrink the OI-M blocker for one-use `tuple.extract(tuple.make(...))` when a non-selected sibling produces multiple results, without claiming broader local-carried, control/EH, or generalized tuple-scratch reconstruction parity?

## Source and probe evidence

The source-backed behavior remains Binaryen `version_130` `OptimizeInstructions.cpp::visitTupleExtract`: it materializes/reloads the selected tuple value and delegates unused `tuple.make` children to `getDroppedChildrenAndAppend`. The relevant legality rule is that non-selected children with unremovable effects must still be evaluated in tuple child order while unused lanes are discarded.

Two local probes refreshed the direct shape:

- `.tmp/oi-m-multiresult-sibling-later-sb002-20260703.wat`
- `.tmp/oi-m-multiresult-sibling-earlier-sb002-20260703.wat`

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-multiresult-sibling-later-sb002-20260703.wat -o .tmp/oi-m-multiresult-sibling-later-sb002-20260703.binaryen.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-multiresult-sibling-earlier-sb002-20260703.wat -o .tmp/oi-m-multiresult-sibling-earlier-sb002-20260703.binaryen.wat
```

Binaryen preserved both later and earlier multi-result `$pair` calls through tuple scratch/drop traffic before returning the selected scalar. This proves the direct non-selected multi-result sibling is OI-M-owned, but it does not prove local-carried tuple values, multi-use tuple producers, control/EH siblings, or public tuple-optimization neighbor closure.

## Starshine implementation

Red-first focused coverage changed the former direct-HOT boundaries in `src/passes/optimize_instructions_test.mbt` into positive tests:

- `optimize-instructions localizes later multi-result non-selected tuple sibling`
- `optimize-instructions localizes earlier multi-result non-selected tuple sibling`

The red-first command failed before implementation:

```sh
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*multi-result non-selected tuple sibling*'
```

Result: `0/2` passed; both roots stayed `TupleExtract`.

`src/passes/optimize_instructions.mbt` now has `optimize_instructions_tuple_extract_append_discarded_child`, used by the direct one-use `TupleMake` localizer. It keeps the existing zero-result and single-result handling, and for multi-result non-selected siblings it appends fresh discard locals and `local.set`s lanes in stack-pop order. This preserves child evaluation order around the selected value while dropping unused sibling lanes.

## Validation and fuzz/runtime evidence

Focused and pass tests:

- Red-first focused multi-result sibling command: failed `0/2` before implementation.
- Post-fix focused multi-result sibling command: passed `2/2`.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'`: passed `21/21`.
- `moon fmt`: passed.
- `moon test src/passes`: passed `3848/3848`.
- `moon build --target native --release src/cmd`: passed with pre-existing unused-function warnings in `pass_manager.mbt`.
- `moon info`: passed with pre-existing warnings.
- `moon test`: passed `7246/7246`.

Grouped OI-M runtime sweep:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --count 108 --out-dir .tmp/oi-m-sb002-multiresult-sibling-runtime-count108-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- --runtime-execution node --max-failures 2000 --keep-going-after-command-failures
bun scripts/oi-parity-sweep.ts --family OI-M --out-dir .tmp/oi-m-sb002-multiresult-sibling-runtime-count108-20260703 --summarize-existing
```

Summary: compared `108/108`, normalized `0`, cleanup `0`, mismatches `108`, validation/generator/property/command failures `0`, command classes `<none>`, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, runtime matrix `all-equal` with total `9`, all 18 OI-M tuple labels sampled, failure dirs `108`, and the raw-mismatch caveat printed. The raw mismatches remain active parity evidence; runtime equality is supporting evidence only.

## Classification

`OI-M-SB002` is covered only under these preconditions:

- direct one-use `TupleMake` producer;
- selected child is already localizable by the existing OI-M direct localizer;
- non-selected multi-result siblings are straight-line/direct-localizable HOT nodes;
- control/branch/EH/nested-region lanes remain excluded;
- no multi-use or local-carried tuple producer rewrite is attempted.

This slice does not close OI-M. Remaining active/P0 surfaces after follow-up note `docs/wiki/raw/research/1420-2026-07-03-optimize-instructions-oi-m-local-carried-tuple-boundary.md` are:

- `OI-M-SB004` control/branch/EH siblings, still blocked/fail-closed;
- `OI-M-SB005` generalized tuple-scratch reconstruction/localization.

`OI-M-SB003` tuple-valued local-carried/local.tee/multi-use producers are now a source-backed no-rewrite boundary while the Binaryen probes hold; selected-lane raw-mismatch labels with local/scratch traffic are owned by `OI-M-SB005`, not speculative tuple-value producer scalarization.

Do not infer OI-G or OI-I/OI-J/OI-K closure from this OI-M evidence.

## Reopening criteria

Reopen `OI-M-SB002` if a direct one-use straight-line multi-result non-selected sibling fails to localize, validation/runtime evidence fails, a sibling call/effect/trap is dropped or reordered, selected-value reloading drifts, Binaryen source/probes contradict the discard-local order, or this helper is applied outside the documented preconditions.
