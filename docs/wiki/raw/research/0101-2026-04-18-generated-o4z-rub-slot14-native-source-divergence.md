# 0101 - Generated `-O4z` slot 14 `remove-unused-brs` native/source divergence

## Status

- Date: 2026-04-18
- Type: One-off blocker investigation
- Shared audit note: [0093 - Generated `cmd.wasm` ordered `-O4z` pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Primary corruption note: [0094 - slot 14 early `remove-unused-brs` invalid raw output](./0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md)
- Oracle reference: Binaryen `RemoveUnusedBrs.cpp` and the saved Binaryen slot-14 output under `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/binaryen.wasm`

## Scope

Narrow the still-open `[O4Z]001` corruption by separating three surfaces that had been conflated:

1. the saved direct native `cmd.exe` replay from `0094`
2. the in-process `run_cmd` / `run_cmd_with_adapter` source path used by `src/cmd/cmd_wbtest.mbt`
3. the actual function-level shape difference against Binaryen for the offending `func 1354`

## What was verified

### 1. The direct built native binaries still reproduce the original corruption

Rebuilt native binaries still emit invalid raw wasm on the saved predecessor input from `0094`.

- Release/native reproduce:
  - `moon build --target native --release --package jtenner/starshine/cmd`
  - `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot14.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
  - `wasm-tools validate .artifacts/tmp-direct-rub-slot14.raw.wasm`
- Current result:
  - `func 1354 failed to validate`
  - `type mismatch: expected i32 but nothing on stack (at offset 0xa7d5d)`

A debug/native rebuild reproduces the same failure shape too, so this is not only a release-only artifact.

### 2. The in-process source-path replay is green on the same saved predecessor fixture

New focused cmd wbtests replay the exact saved slot-13 predecessor through both in-process entrypoints:

- `run_cmd validates remove-unused-brs on generated O4z slot14 predecessor`
- `run_cmd_with_adapter validates remove-unused-brs on generated O4z slot14 predecessor`

Those tests pass and decode the emitted wasm successfully, which means the remaining live surface is narrower than “RUB is always wrong on this input”. The reproducing path is the built `cmd.exe` binary, while the in-process source path stays green on the same bytes.

## Function-level comparison against Binaryen

`wasm-tools print` on the invalid Starshine raw output and the saved Binaryen slot-14 output shows a durable shape difference inside `func 1354`.

### Binaryen slot-14 output

Binaryen keeps the critical region as a plain `block` and lowers the branchy arm without introducing a new value block around the carried roots. The printed shape in the saved valid output is:

- `block ;; label = @7`
- `...`
- `i64.eq`
- `br_if 2 (;@5;)`
- `...`
- `br 0 (;@7;)`
- `end`
- `local.get 17`
- `local.set 16`

### Starshine native output

The invalid Starshine raw output instead wraps the same branch-bearing region in a new `block (result i32)`:

- `block (result i32) ;; label = @7`
- inner `block ;; label = @8`
- inner `if ;; label = @9`
- true arm: `br 3 (;@6;)`
- else arm: `local.set 17` then `br 1 (;@8;)`
- `unreachable`
- `end`
- `local.get 17`
- `end`

That new result block changes the relative label depth seen by the inner `br 3`. In the emitted invalid wasm, the branch now targets a value block without carrying the required `i32` payload, which matches the validator’s “expected i32 but nothing on stack” failure.

### Inference boundary

The branch-depth explanation above is an inference from the printed invalid/native output plus the validator error. It is strongly supported by the label stack in the printed WAT, but the exact mutator/helper site in `src/passes/remove_unused_brs.mbt` is still unresolved.

## What was tried and why it was not kept

A conservative guard was prototyped around the obvious value-expression builders in `src/passes/remove_unused_brs.mbt`:

- `remove_unused_brs_build_region_value_expr(...)`
- the `remove_unused_brs_try_rewrite_result_block_one_arm_payload_if(...)` fallback that wraps `build_stack_exit_region_value_body(...)` in a new value block

The intent was to reject rewrites that reparent roots containing nested relative branches without retargeting them.

That prototype was **not** kept because a fresh rebuilt native `cmd.exe` still produced the same invalid slot-14 output afterward. So the exact mutation site is either:

- a different RUB helper than the first suspected value-wrapper path, or
- a later native-only lowering / writeback divergence that the current in-process wbtests do not exercise.

## Immediate blocker conclusion

`[O4Z]001` is now blocked by a narrower prerequisite:

- isolate why the built native `cmd.exe` path still emits the invalid `func 1354` shape while the in-process source-path wbtests stay green on the same saved predecessor bytes
- only then land a correctness fix that can be trusted and regression-locked

Without resolving that split first, it is too easy to land a source-path-only change that does not actually move the real failing artifact lane.

## Files touched in this investigation

- `src/cmd/cmd_wbtest.mbt`
- `src/passes/remove_unused_brs.mbt` (prototype guard attempted locally, then discarded)
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/binaryen.wasm`
- `.artifacts/tmp-direct-rub-slot14.raw.wasm`

## Suggested next step

Add a native-binary-level regression hook that exercises the built `cmd.exe` on the saved predecessor fixture from inside the repo test surface, or otherwise dump the exact post-pass / pre-lower HOT state for `func 1354` from the reproducing binary path. That will let the next pass fix target the real mutation site instead of only the first plausible wrapper helper.
