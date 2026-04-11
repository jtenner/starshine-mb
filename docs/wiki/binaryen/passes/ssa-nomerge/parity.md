---
kind: comparison
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md
related:
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `ssa-nomerge` Binaryen Parity

## Durable Conclusions

- The April `2026-04-10` dead-param-write parity family is now fixed in-tree for `ssa-nomerge`.
- Current source-mode `ssa-nomerge` replay on the checked-in debug CLI artifact now completes, validates, and matches Binaryen on normalized WAT and canonical per-function output.
- Random compare fuzz is still useful, but it is not sufficient as the only signoff lane for `ssa-nomerge`.
- Current mixed-generator compare coverage is mismatch-free on comparable cases and only hits the standing Binaryen `binaryen-rec-group-zero` parser-family gap.
- Fresh post-merge reruns on seed `0x51a` stayed clean in both the mixed-generator and `gen-valid` lanes.
- Exact raw-byte parity is still not claimed because current trace replay still shows fail-closed `writeback-validate:*` skips inside Starshine's raw lowering path.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt).
- The current raw-lowering fix lives in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt): dead param writes now spill through fresh locals, while live straight-line and typed-if param flows stay on the canonical param slot.
- That rule is an in-tree inference from Binaryen `src/passes/SSAify.cpp` `createNewIndexes()` plus direct `wasm-opt --ssa-nomerge` micro-replays on reduced param-write cases.
- The same pass-manager path still rejects per-function writebacks that fail module-aware validation, in addition to the existing `invalid-escape-carrier` and `suspicious-escape-carrier` families.
- The `cmd` package contains a native debug-artifact replay test in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt), and a focused `moon test src/cmd --target native --filter 'run_cmd_with_adapter validates ssa-nomerge on debug artifact'` run is currently green.

## Current Signoff State

- `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` is green with focused dead-param and live-param regressions.
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff-gen-valid --pass ssa-nomerge` is green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff --pass ssa-nomerge` stays mismatch-free on comparable cases (`2380 / 10000` compared, `0` mismatches) and only stops on the Binaryen-only `binaryen-rec-group-zero` parser family.
- `bun scripts/pass-fuzz-compare.ts --count 2000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-mixed-seed51a --pass ssa-nomerge` stayed clean on all comparable cases (`1996 / 2000`, `0` mismatches, `4` Binaryen-only parser gaps).
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-genvalid-seed51a --pass ssa-nomerge` is also green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --ssa-nomerge` currently reports `Normalized WAT equal: yes` and `Canonical function compare equal: yes`, while `Canonical wasm equal: no`.

## Remaining Gap

- `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-postcommit.wasm tests/node/dist/starshine-debug-wasi.wasm` exits zero and final validation completes.
- That traced current-source replay now records one remaining validation-backed skip: `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch`.
- The same traced replay also records `228` `suspicious-escape-carrier` skips.
- The same input succeeds under Binaryen with `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge`.
- So the current output-facing blocker is fixed, but raw-lowering coverage is still incomplete and direct artifact replay remains mandatory.

## Practical Rule

- Keep direct debug-artifact replay in the `ssa-nomerge` signoff loop.
- Treat the seeded `binaryen-rec-group-zero` wasm-smith failure as an oracle parser gap, not an SSA semantic mismatch.
- Treat current-source output parity as green for the fixed dead-param family, but do not claim exact artifact parity until direct Starshine replay on `tests/node/dist/starshine-debug-wasi.wasm` stops relying on `writeback-validate:*` fail-closed skips for Binaryen-successful functions.
- Keep the direct artifact replay and the `10000 / 10000` `gen-valid` compare lane together as the minimum signoff pair.

## Sources

- Archived research doc: [`../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md`](../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md)
- Pass implementation: [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- Pass manager guard: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- CLI artifact test surface: [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)
- Random compare harness: [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
