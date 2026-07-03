# Optimize-instructions OI-M closeout: SB004/SB005 bounded

Date: 2026-07-03

## Scope

This note closes the remaining OI-M closeout target only. It does not infer OI-G, OI-I, OI-J, or OI-K closure.

Before this slice, the remaining P0 OI-M surfaces were:

- OI-M-SB004: structured control / branch / EH tuple siblings.
- OI-M-SB005: generalized tuple-scratch reconstruction/localization and broader producer/effect/trap wrappers.

The result is a bounded closeout rather than broad tuple-scratch scalarization: Starshine keeps fail-closed boundaries for unsupported control/EH reconstruction, and the remaining branch-free tuple-scratch raw mismatches are accepted only where direct/grouped validation, runtime, opcode, and raw/canonical size evidence supports a Starshine-win classification.

## SB004 Binaryen probes

Probe directory: `.tmp/oi-m-sb004-probes-20260703`.

Commands used for each WAT probe:

```sh
wasm-opt --all-features -S --optimize-instructions <probe>.wat -o <probe>.binaryen.wat
wasm-tools validate --features all <probe>.binaryen.wat
```

`wasm-tools validate` was run on every Binaryen `try_table`/non-legacy output used for classification. Binaryen legacy `try` text output is not accepted by local `wasm-tools`; the closeout therefore uses `try_table` as the wasm-tools-valid EH representative and treats legacy `try` as a textual Binaryen probe only.

| Probe | Binaryen behavior | Starshine classification |
| --- | --- | --- |
| `nonselected-branch-contained.wat` | Rewrites tuple extract, drops branch-contained unused sibling after localizing selected lane. | Not implemented beyond existing branch-free block subset; fail-closed boundary until HOT proves label containment and no escaping control. |
| `nonselected-branch-escaping.wat` | Preserves escaping `br $exit (i32.const 99)` while localizing selected lane. | Fail-closed boundary; dropping or reordering would change returned value. |
| `selected-branch-contained.wat` | Rewrites and preserves selected branch-bearing block through local scratch. | Fail-closed boundary until selected control-result reconstruction is source-backed in HOT. |
| `nonselected-brtable-contained.wat` | Rewrites tuple extract and drops contained `br_table` sibling. | Fail-closed boundary until multi-target containment is proven. |
| `nonselected-brtable-escaping.wat` | Preserves escaping `br_table $exit $exit (i64.const 99)` while localizing selected lane. | Fail-closed boundary; multi-target escape can change result. |
| `nonselected-loop.wat` | Rewrites tuple extract and drops pure unused loop sibling. | Fail-closed boundary for loops/backedges until loop-label containment and branch target behavior are proven. |
| `selected-loop.wat` | Rewrites and preserves selected loop lane through local scratch. | Fail-closed boundary for selected loop lane reconstruction. |
| `nonselected-if.wat` | Rewrites tuple extract and drops pure unused `if` sibling. | Fail-closed boundary for general `if`; branch-free `Block` is the only implemented structured child subset. |
| `selected-if.wat` | Rewrites and preserves selected `if` lane through local scratch. | Fail-closed boundary for selected `if` lane reconstruction. |
| `nonselected-try-table.wat` | Rewrites tuple extract and drops non-throwing unused `try_table` sibling. | Fail-closed EH boundary until catch target/exception exit reconstruction is source-backed. |
| `selected-try-table.wat` | Rewrites and preserves selected `try_table` lane through local scratch. | Fail-closed EH boundary. |
| `nonselected-try-table-throw-contained.wat` | Rewrites tuple extract but preserves the throwing/catching non-selected `try_table` as a dropped child. | Fail-closed EH boundary; exception edges are preserved by Binaryen and must not be dropped speculatively. |

Existing positive SB004 coverage remains the branch-free pure block lane slice from note 1421. This closeout added explicit fail-closed tests for loop sibling, selected `if` lane, and `try_table` sibling boundaries in `src/passes/optimize_instructions_test.mbt`, in addition to the existing branch-bearing block sibling boundary test.

Focused test evidence:

```sh
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'
```

Result: `24/24` passed after the new fail-closed tests. The first run failed because the selected-`if` fixture used a constant condition that a different OI fold simplified before the tuple boundary assertion; the test was corrected to use a parameter condition so it exercises the intended fail-closed boundary.

SB004 closeout classification: bounded, not implemented. Reopen when HOT has a source-backed structured-child localizer that can prove label containment, branch-table target containment, no `return`/outer-label escapes, no EH exits, stable result arity, and preserved effect/trap/exception behavior.

## SB005 closeout evidence

Fresh direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 132 --seed 0x5eed \
  --pass optimize-instructions --gen-valid-profile pass-oi-tuple \
  --out-dir .tmp/oi-m-closeout-direct-count132-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --jobs auto \
  --runtime-execution node --max-failures 2000 \
  --keep-going-after-command-failures
```

Fresh grouped lane:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --count 132 \
  --out-dir .tmp/oi-m-closeout-count132-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- \
  --runtime-execution node --max-failures 2000 \
  --keep-going-after-command-failures

bun scripts/oi-parity-sweep.ts --family OI-M \
  --out-dir .tmp/oi-m-closeout-count132-20260703 --summarize-existing
```

Both direct and grouped lanes reported:

- compared `132/132`;
- normalized `0`, cleanup-normalized `0`, raw mismatches `132`;
- validation/generator/property/command failures `0/0/0/0`;
- runtime checked/unsupported/failed `132/0/0`;
- runtime matrix `all-equal`, total `56`, equalResults `53`, equalTraps `3`, semanticMismatches `0`;
- all 22 `pass-oi-tuple` labels sampled.

Cache:

- direct: Binaryen cache hits/misses `132/0`;
- grouped: Binaryen cache hits/misses `132/0` in the execute summary and `132/0` in the summarize-existing result.

Profile case counts in both lanes:

- `oi-tuple:effectful-scratch-localized-selected-lane=10`
- `oi-tuple:selected-trapping-lane=5`
- `oi-tuple:runtime-effectful-selected-lane=9`
- `oi-tuple:scratch-localized-selected-lane=7`
- `oi-tuple:runtime-selected-lane=6`
- `oi-tuple:runtime-all-results=6`
- `oi-tuple:trapping-sibling-selected-lane=5`
- `oi-tuple:effectful-select-operand-selected-lane=6`
- `oi-tuple:runtime-multi-selected-effectful-lanes=5`
- `oi-tuple:runtime-effectful-scratch-localized-selected-lane=4`
- `oi-tuple:direct-selected-lane=10`
- `oi-tuple:selected-effectful-lane=4`
- `oi-tuple:localtee-produced-selected-lane=6`
- `oi-tuple:trapping-select-operand-selected-lane=9`
- `oi-tuple:select-produced-selected-lane=8`
- `oi-tuple:call-produced-selected-lane=8`
- `oi-tuple:randomized-existing-effect-trap-lanes=4`
- `oi-tuple:effectful-sibling-selected-lane=5`
- `oi-tuple:multi-selected-effectful-lanes=5`
- `oi-tuple:local-carried-selected-lane=5`
- `oi-tuple:selected-lane-all-results=2`
- `oi-tuple:runtime-mixed-effect-trap-scratch-localized-selected-lane=3`

### Remaining label classification not already closed by notes 1422-1428

For each remaining label below, one direct and one grouped representative was inspected. `wasm-tools validate --features all` accepted `binaryen.raw.wasm`, `starshine.raw.wasm`, `binaryen.wasm`, and `starshine.wasm` for every listed representative. Opcode counts for local traffic, calls/globals, drops, constants, traps, branches, and control/EH nodes were compared from WAT. In all rows, Starshine raw and canonical wasm are smaller; WAT is larger only because Starshine retains block-result expression spelling while Binaryen emits straighter scalar-local traffic.

| Label | Direct representative | Grouped representative | Grouped transform | Starshine raw/canonical/WAT delta direct | Starshine raw/canonical/WAT delta grouped | Classification |
| --- | --- | --- | --- | ---: | ---: | --- |
| `oi-tuple:direct-selected-lane` | `case-000014-gen-valid` | `case-000014-gen-valid-transform-oi-effectful-sibling` | `oi-effectful-sibling` | `-23/-5/+196` | `-23/-5/+196` | Starshine-win boundary. Local traffic, constants, drops, grouped `global.set`/select/if scaffolding preserved; only extra Starshine blocks. |
| `oi-tuple:local-carried-selected-lane` | `case-000052-gen-valid` | `case-000052-gen-valid-transform-oi-local-carried` | `oi-local-carried` | `-23/-5/+196` | `-21/-5/+195` | Starshine-win boundary for generated scalar block-result spelling; tuple-valued local producers remain SB003 no-rewrite boundary. |
| `oi-tuple:localtee-produced-selected-lane` | `case-000016-gen-valid` | `case-000016-gen-valid-transform-oi-local-carried` | `oi-local-carried` | `-23/-5/+202` | `-21/-5/+201` | Starshine-win boundary; `local.tee` counts match `2/2` direct and grouped. |
| `oi-tuple:call-produced-selected-lane` | `case-000029-gen-valid` | `case-000029-gen-valid-transform-oi-tuple-selected-lane` | `oi-tuple-selected-lane` | `-23/-5/+196` | `-192/-101/+1752` | Starshine-win boundary; helper call preserved `1/1`, local/drop/constant traffic preserved. |
| `oi-tuple:select-produced-selected-lane` | `case-000023-gen-valid` | `case-000023-gen-valid-transform-oi-trapping-sibling` | `oi-trapping-sibling` | `-21/-5/+208` | `-21/-5/+208` | Starshine-win boundary; select preserved `1/1`, grouped trap carriers preserved (`i32.div_u=1/1`, `i64.div_u=1/1`). |
| `oi-tuple:effectful-sibling-selected-lane` | `case-000036-gen-valid` | `case-000036-gen-valid-transform-oi-local-carried` | `oi-local-carried` | `-23/-5/+196` | `-21/-5/+195` | Starshine-win boundary; helper call/global.set preserved `1/1` in both. |
| `oi-tuple:trapping-sibling-selected-lane` | `case-000009-gen-valid` | `case-000009-gen-valid-transform-oi-tuple-selected-lane` | `oi-tuple-selected-lane` | `-23/-5/+196` | `-192/-101/+1752` | Starshine-win boundary; trapping helper call and `i64.div_u` preserved `1/1`. |
| `oi-tuple:selected-trapping-lane` | `case-000002-gen-valid` | `case-000002-gen-valid-transform-oi-effectful-sibling` | `oi-effectful-sibling` | `-23/-5/+205` | `-23/-7/+205` | Starshine-win boundary; selected trap carrier `i32.div_u=1/1`, grouped effects preserved. |
| `oi-tuple:selected-effectful-lane` | `case-000015-gen-valid` | `case-000015-gen-valid-transform-oi-trapping-sibling` | `oi-trapping-sibling` | `-23/-5/+196` | `-24/-5/+196` | Starshine-win boundary; selected helper call/global.set preserved, grouped trap carriers preserved. |
| `oi-tuple:effectful-select-operand-selected-lane` | `case-000010-gen-valid` | `case-000010-gen-valid-transform-oi-effectful-sibling` | `oi-effectful-sibling` | `-21/-5/+208` | `-21/-6/+208` | Starshine-win boundary; select and helper/global.set traffic preserved. |
| `oi-tuple:trapping-select-operand-selected-lane` | `case-000017-gen-valid` | `case-000017-gen-valid-transform-oi-tuple-selected-lane` | `oi-tuple-selected-lane` | `-21/-5/+208` | `-190/-101/+1764` | Starshine-win boundary; select and trap carrier preserved. |
| `oi-tuple:runtime-selected-lane` | `case-000006-gen-valid` | `case-000006-gen-valid-transform-oi-effectful-sibling` | `oi-effectful-sibling` | `-23/-5/+202` | `-23/-6/+202` | Runtime-observable Starshine-win boundary; direct/grouped runtime all-equal evidence covers returned selected lane. |
| `oi-tuple:runtime-effectful-selected-lane` | `case-000003-gen-valid` | `case-000003-gen-valid-transform-oi-trapping-sibling` | `oi-trapping-sibling` | `-19/-5/+196` | `-20/-5/+196` | Runtime-observable Starshine-win boundary; helper/global.set and grouped trap carriers preserved. |
| `oi-tuple:randomized-existing-effect-trap-lanes` | `case-000035-gen-valid` | `case-000035-gen-valid-transform-oi-trapping-sibling` | `oi-trapping-sibling` | `-23/-5/+232` | `-24/-5/+232` | Starshine-win boundary for the sampled randomized existing/effect/trap smoke; helper/global.set, local.tee, drop, and trap carrier traffic preserved. |

Labels already accepted by notes 1422-1428 remain bounded by their own reopening criteria:

- pure scratch-localized selected lane (`1422`);
- helper-effectful scratch-localized selected lane (`1423`);
- branch-free all-results (`1424`);
- generated branch-free multi-selected effectful (`1425`);
- runtime-exported all-results/effectful-scratch/multi-selected generator evidence (`1426`);
- grouped wrappers around runtime-exported labels (`1427`);
- runtime mixed effect+trap scratch-localized selected lane (`1428`).

## Final OI-M classification

OI-M is no longer an active/P0 closeout blocker after this note. The remaining raw mismatches are not ignored: they are classified as either implemented covered subsets, source-backed no-rewrite boundaries, fail-closed control/EH boundaries with probe evidence, or measured Starshine-win tuple-scratch representation boundaries.

Closeout buckets:

- SB001 direct one-use selected-child arbitrary arity: implemented under preconditions.
- SB002 direct one-use straight-line multi-result non-selected siblings: implemented under preconditions.
- SB003 tuple-valued local-carried/local.tee/multi-use tuple producers: source-backed no-rewrite boundary.
- SB004 branch/EH/control siblings: bounded fail-closed boundary; only branch-free pure block lane is implemented.
- SB005 generalized tuple-scratch reconstruction/localization: bounded by measured Starshine-win evidence for all currently sampled 22 labels; broader unsampled/control/EH/source-visible producer variants reopen work.
- SB006 summary tooling: covered.

## Reopening criteria

Reopen OI-M if any of the following occurs:

- a true runtime semantic mismatch, unequal trap, unsupported runtime regression, validation failure, generator failure, property failure, or command failure appears in OI-M lanes;
- Starshine raw or canonical wasm becomes larger than Binaryen for an accepted Starshine-win residual without a separately measured win;
- helper calls, `global.set`/`global.get`, local.set/local.get/local.tee lane traffic, drops, constants, selects, trap carriers, branch targets, labels, exception edges, or selected-lane result order drift;
- Binaryen source/lit/probe evidence shows a control/EH or tuple-scratch shape must be scalarized for semantics rather than output shape;
- HOT gains source-backed control/EH reconstruction sufficient to implement a currently fail-closed SB004 subset;
- new `pass-oi-tuple` labels or metamorphic wrappers expose unclassified OI-M residuals;
- any attempt is made to use OI-M evidence to close OI-G, OI-I, OI-J, or OI-K.
