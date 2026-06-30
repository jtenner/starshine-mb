# Tuple Optimization GenValid Profile Slice

Date: 2026-06-29
Status: working evidence; not a final TO closeout

## Sources

- Binaryen current-main `src/passes/TupleOptimization.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TupleOptimization.cpp>
- Binaryen current-main lit test `test/lit/passes/tuple-optimization.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/tuple-optimization.wast>
- Starshine implementation: `src/passes/tuple_optimization.mbt`
- Starshine GenValid profile implementation: `src/validate/gen_valid.mbt`
- Starshine profile manifest plumbing: `src/fuzz/main.mbt`, `src/fuzz/imports.mbt`
- Focused tests: `src/validate/gen_valid_tests.mbt`, `src/fuzz/main_wbtest.mbt`
- Smoke artifacts: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30`

## Binaryen Surface Refreshed

Binaryen's current tuple pass is still a narrow local-tuple scalarizer. The source confirms that it only tries to optimize tuple locals whose writes are `tuple.make` or copies from other eligible tuple locals, and whose reads are tuple extracts or copies to other eligible tuple locals. Escaping tuple gets make the local bad, and badness propagates across copy edges. When a good tuple local is found, Binaryen allocates one scalar local per tuple lane and rewrites `local.set`, tuple-local copies, and `tuple.extract` to scalar local operations. The source also keeps block-produced tuple values out of scope, with a TODO noting that block handling is not clearly always profitable.

The lit surface directly covers the families that matter for this audit slice:

- direct spill from `tuple.make` into scalar locals;
- tuple extract reads from the new scalar locals;
- `local.tee` replacement, including the extra block/sequence shape needed to preserve the tee value;
- copy chains across tuple locals, including three-lane chains;
- corruption/badness propagation when any tuple in a copy chain escapes;
- non-tuple locals ignored;
- `tuple.make`/`tuple.extract` without an intervening local intentionally left to other passes;
- set-of-block tuple values intentionally not optimized;
- unreachable-code robustness.

## Implemented Starshine Fuzzing Slice

Added dedicated GenValid profiles for the tuple-optimization pass:

- `tuple-optimization-spill`
- `tuple-optimization-copy-chain`
- `tuple-optimization-tee`
- `tuple-optimization-all`

The aggregate profile weights spill/copy-chain/tee as 3/2/1. The generated modules deliberately include type-indexed multivalue block carriers (`BlockType::type_idx`) and spill those lanes through locals with `local.set`/`local.tee`, matching the pass's multivalue local-carrier surface rather than relying on generic random generation.

Added deterministic trigger-family labels:

- `tuple-optimization:spill`
- `tuple-optimization:copy-chain`
- `tuple-optimization:tee`

The fuzz manifest now records those labels through the same `profile_case_label` path used by the optimize-instructions trigger profiles, so replay triage can group TO profile mismatches by carrier family.

## Validation

Red-first setup:

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt --filter '*tuple-optimization*'`
  - failed before implementation with missing `GenValidProfile` constructors for `TupleOptimizationSpillProfile`, `TupleOptimizationCopyChainProfile`, `TupleOptimizationTeeProfile`, and `TupleOptimizationAllProfile`.

Green checks after implementation:

- `moon fmt`
  - completed.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt --filter '*tuple-optimization*'`
  - `2 passed, 0 failed`.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt --filter '*trigger profiles record selected*'`
  - `1 passed, 0 failed`; pre-existing warnings only.
- `moon build --target native --release src/cmd`
  - completed/no work to do for the current native cmd artifact.

Smoke compare before profile-label plumbing:

```sh
bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30 --max-failures 50
```

Result summary from `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30/result.json`:

- generated/validated: `30 / 30`
- validation/generator/command/property failures: `0`
- selected profile counts: spill `12`, copy-chain `14`, tee `4`
- normalized mismatches: `30`

Interpretation: the dedicated profiles are intentionally hot and expose the existing tuple-scalarization shape gap immediately. The first inspected mismatch is a validating type-indexed multivalue carrier that Binaryen scalarizes differently from Starshine; this is a parity gap to reduce, not a generator or validation problem, and not final TO signoff.

Post-label-plumbing count-6 compare:

```sh
bun scripts/pass-fuzz-compare.ts --count 6 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-post-label --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20
```

Result summary from `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-post-label/result.json`:

- generated/validated: `6 / 6`
- validation/generator/command/property failures: `0`
- normalized mismatches: `6`
- selected profile counts: spill `4`, tee `2`
- manifest profile case counts: `tuple-optimization:spill` `4`, `tuple-optimization:tee` `2`

This confirms that the profile labels now reach `cases.jsonl` and the result summary.

## Current Classification

This slice does not close `[O4Z-AUDIT-TO]`. It creates the TO-specific profile surface needed to make the audit actionable and demonstrates that the dedicated profile currently finds real Starshine-vs-Binaryen shape drift on every sampled carrier. Continue with reduced mismatch triage and implementation of locally representable Binaryen families before any 10k/100k closeout claim.

Follow-ups: [`1359-2026-06-29-tuple-optimization-typeidx-spill-scalarization.md`](1359-2026-06-29-tuple-optimization-typeidx-spill-scalarization.md) narrows the first simple type-indexed spill case by scalarizing raw tuple/block carrier debris, and [`1360-2026-06-29-tuple-optimization-typeidx-tee-scalarization.md`](1360-2026-06-29-tuple-optimization-typeidx-tee-scalarization.md) removes the simple host-tee structured carrier. The dedicated profile remains red on residual scalar local/tee/copy spelling drift.
