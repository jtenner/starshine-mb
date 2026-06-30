# Tuple Optimization Type-Indexed Spill Scalarization Slice

Date: 2026-06-29
Status: working evidence; not a final TO closeout

## Sources

- Starshine implementation: `src/passes/tuple_optimization.mbt`
- Focused pass coverage: `src/passes/tuple_optimization_wbtest.mbt`
- Focused native command coverage: `src/cmd/cmd_native_wbtest.mbt`
- Registry/package pass coverage: `src/passes/registry_test.mbt`
- Dedicated TO profile evidence: `docs/wiki/raw/research/1358-2026-06-29-tuple-optimization-genvalid-profile.md`
- Follow-up tee scalarization evidence: `docs/wiki/raw/research/1360-2026-06-29-tuple-optimization-typeidx-tee-scalarization.md`
- Smoke artifacts: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-simple-payload`, `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-simple-payload`

## Question

The new `tuple-optimization-all` GenValid profile exposed immediate mismatches on type-indexed multivalue block spill carriers. The first reduced shape was:

```wat
(module
  (type (;0;) (func))
  (type (;1;) (func (result i32 i64)))
  (func (;0;) (type 0)
    (local i32 i64)
    block (type 1)
      i32.const 7
      i64.const 9
    end
    local.set 1
    local.set 0
    local.get 0
    drop
    local.get 1
    drop))
```

Binaryen's normalized `--tuple-optimization` output scalarizes the carrier into scalar locals. Pre-slice Starshine kept a scalar result wrapper around the host lane after the oracle normalization path, leaving a parity gap for the dedicated profile.

## Change

Starshine now gives no-host source groups from root type-indexed control carriers dedicated split locals. For simple block payloads whose entire body is pass-through constants or local gets, the rewrite clones those lane payloads directly into scalar `local.set`s instead of preserving a multivalue block producer as the split-local source.

This is intentionally narrower than the reverted broad root-control split experiment: it targets no-host source groups and simple block payload lanes only. Host-copy and passthrough-chain families remain guarded by the existing host-lane logic.

## Focused Validation

Red-first evidence:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block spill carrier*'`
  - failed before the implementation because the raw output still contained a scalar `block (result i32)` wrapper around the type-indexed block spill.

Green checks after implementation:

- `moon fmt`
  - completed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - `46 passed, 0 failed`.
- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block spill carrier*'`
  - `1 passed, 0 failed`; pre-existing warnings only.
- `moon test --package jtenner/starshine/passes --file registry_test.mbt --filter '*tuple-optimization*'`
  - `1 passed, 0 failed` after updating the active-pass smoke expectation for the new dedicated split locals.
- `moon test src/passes`
  - `3601 passed, 0 failed`.
- `moon build --target native --release src/cmd`
  - completed with pre-existing warnings.

Known baseline caveat:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'` still fails at the pre-existing `tail-live0` exact-order assertion noted by the previous handoff. The pass implementation diff is not enough to use that broad filter as a green baseline yet.

## Dedicated Profile Smoke After The Change

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-simple-payload --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50
```

Result:

- compared: `30 / 30`
- validation/generator/command/property failures: `0`
- normalized mismatches: `30`

A smaller count-6 replay at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-simple-payload` also compared `6 / 6` with zero failures and `6` mismatches. The first case now lowers Starshine's carrier to direct scalar `local.set` traffic with no tuple extract and no preserved one-result block, but still differs from Binaryen's extra scalar temp/tee/copy ladder. Current agent classification: behavior gap narrowed, residual output-shape mismatch remains unclosed. The residual may be a Starshine size/local-count win on this simple family, but that has not been measured across the profile, so it is not yet accepted as a final documented Starshine-win divergence.

## Current Classification

This slice reduces the first dedicated-profile spill mismatch family by removing tuple/block carrier debris from simple root no-host spills. It does not close `[O4Z-AUDIT-TO]` because the dedicated profile still reports `30 / 30` normalized mismatches and tee/copy-chain families still need reduced triage.

Next useful work after the follow-up tee slice: classify the residual simple spill/tee one-byte-larger scalar spelling and copy-chain Starshine-shorter spelling separately, then either document narrow measured wins with reopening criteria or continue aligning the scalar temp/tee ladder.
