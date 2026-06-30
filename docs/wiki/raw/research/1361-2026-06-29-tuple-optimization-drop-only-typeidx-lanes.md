# Tuple Optimization Drop-Only Type-Indexed Lane Scalarization

Date: 2026-06-29

## Context

The previous `tuple-optimization` slice scalarized simple type-indexed no-host spill and host-tee block carriers, but the dedicated `tuple-optimization-all` profile remained red. The post-tee count-30 smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-host-tee-simple-payload` still reported `30 / 30` normalized mismatches with zero validation/generator/command/property failures. The measured residuals were scalar spelling deltas: spill `+2` Starshine raw bytes with fewer locals/ops, tee `+1` raw byte with fewer locals/ops, and copy-chain `-4` raw bytes with fewer locals/ops.

## Change

This slice keeps the earlier carrier scalarization but avoids copying simple two-lane `i32, i64` type-indexed source groups back into original lane locals when those original lanes have no forwarded non-drop use. The rewrite still evaluates the cloned simple payload lanes into dedicated split locals before the original carrier point. For lanes whose only remaining observable use is a `drop`, writing the original local is unnecessary: `drop` does not observe the value, and the producer-side evaluation has already been preserved at the scalarized insertion point.

The behavior is intentionally narrow:

- only simple `i32, i64` type-indexed source groups use the drop-only original-lane omission;
- non-type-indexed tuple fixtures keep their older scalar copyback shape;
- any lane with a forwarded non-drop use still writes the original local;
- copy-chain handling remains otherwise unchanged.

## Red-first tests

Updated the existing type-indexed spill and tee white-box tests in `src/passes/tuple_optimization_wbtest.mbt` to require only the two split-local writes in the simple drop-only cases.

Before implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block*'
```

failed both updated tests because the printed HOT body still contained four `local.set` operations for spill/tee scalarization.

## Validation

After implementation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt
moon test src/passes
moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block*'
moon build --target native --release src/cmd
```

Results:

- focused type-indexed tuple tests: `2 / 2` passed after the implementation;
- full tuple white-box file: `47 / 47` passed;
- `moon test src/passes`: `3602 / 3602` passed;
- native type-indexed command tests: `2 / 2` passed with pre-existing warnings;
- native release `src/cmd` build completed with pre-existing warnings.

## Dedicated profile smoke

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-drop-only-split --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50
```

Result:

- requested/compared: `30 / 30`;
- normalized matches: `0`;
- mismatches: `30`;
- validation failures: `0`;
- generator failures: `0`;
- command failures: `0`;
- property failures: `0`;
- Binaryen cache: `30` hits, `0` misses;
- selected profiles: spill `12`, tee `4`, copy-chain `14`.

Measured raw/local/effective-op deltas on the new smoke:

| family | cases | Starshine raw bytes | Starshine locals | Starshine effective WAT ops |
|---|---:|---:|---:|---:|
| spill | 12 | `-3` each | `-2` each | `-5` each |
| tee | 4 | `-4` each | `-2` each | `-6` each |
| copy-chain | 14 | `-4` each | `-6` each | `-10` each |

This is forward progress but not closeout: the compare lane is still raw-red, and the measured size/local/op win is sampled only on the simple dedicated-profile family. A later audit slice must either normalize/classify this exact scalar spelling as an intentional narrow Starshine win with source-backed reopening criteria, or align the remaining spelling to Binaryen if broader evidence finds a regression.

## Next work

1. Inspect the residual copy-chain mismatches beyond case `000007` and decide whether the consistently smaller Starshine scalar ladder is an intentional narrow win or whether Binaryen's extra temp ladder should be matched for behavior-signoff simplicity.
2. Run a larger dedicated `tuple-optimization-all` lane once the residual classification is documented.
3. Continue toward the required final full closeout ladder and 100k lanes only after dedicated-profile residuals are either green or explicitly classified with evidence.
