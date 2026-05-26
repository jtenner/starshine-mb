# DAE003-C earlier-read local carrier negative guard

Date: 2026-05-26

## Scope

Recovery slice for `[DAE003-C]` non-adjacent local-set constant carriers.

The previous DAE003-C slice accepted a narrow straight-line caller carrier:

```wat
i32.const 77
local.set 0
local.get 0
call $target
```

Research note `0640` added negative guards for `local.tee` prefixes and multiple writes to the same local. This note adds the remaining same-local earlier-read guard from the backlog wording.

## Test added

Added `dae-optimizing rejects non-adjacent local-set carrier with earlier read` in `src/passes/dae_optimizing_test.mbt`.

The fixture keeps the target parameter when the caller reads the carrier local before the call actual:

```wat
i32.const 77
local.set 0
local.get 0
drop
local.get 0
call $target
```

Expected behavior:

- target still has one parameter;
- target body still contains `local.get`;
- caller still contains the earlier `local.get` and `drop`.

## Result

The focused regression already passes on current code, so no optimizer behavior changed. This confirms the existing recognizer's `no earlier same-local read` guard covers the explicit earlier-read surface, not only `local.tee` and multiple-write negatives.

## Validation

- Attempted invalid focused command: `moon test src/passes -p starshine/passes` (Moon CLI rejects mixing path arguments with `--package`).
- `moon test src/passes` passed: `1396` tests.

## Remaining DAE003-C work

`[DAE003-C]` remains open for effecting/trapping carrier prefixes if policy requires rejecting them, self/escaped cycles, broader structured carriers, and closeout artifact/fuzz evidence. The multiple-get/earlier-read negative surface is now covered.
