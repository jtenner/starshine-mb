---
kind: comparison
status: working
last_reviewed: 2026-05-07
sources:
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lift_test.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `ssa-nomerge` Binaryen Parity

This page is the current local signoff tracker.
Use the strategy and shape pages in this folder for the upstream Binaryen algorithm itself; use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for owner-file and proof-surface navigation. This page is about the repo's current evidence and remaining gaps.

## Durable Conclusions

- The April `2026-04-10` dead-param-write parity family is now fixed in-tree for `ssa-nomerge`.
- Current source-mode `ssa-nomerge` replay on the checked-in debug CLI artifact now completes, validates, and matches Binaryen on normalized WAT and canonical per-function output.
- Random compare fuzz is still useful, but it is not sufficient as the only signoff lane for `ssa-nomerge`.
- The 2026-05-07 current-head local-declaration shaping drift family is fixed in-tree: `ssa_destroy` now matches Binaryen temp-local preservation/reuse for unreachable dead `local.tee` value-if carriers without generic lowerer trimming.
- Fresh post-merge reruns on seed `0x51a` stayed clean in both the mixed-generator and `gen-valid` lanes.
- The reduced unreachable compare-carrier slice behind the traced `Func 523` family is now covered in-tree in both lift and pass tests.
- The old traced `Func 523` `writeback-validate:type mismatch` skip is now retired by the focused extracted-function CLI replay test.
- Exact raw-byte parity is still not claimed because Starshine's raw lowering path can still fail closed on artifact-only writeback families, and this follow-up did not rerun a fresh full-artifact traced skip census.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt).
- The current raw-lowering fix lives in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt): dead param writes now spill through fresh locals, while live straight-line and typed-if param flows stay on the canonical param slot.
- That rule is an in-tree inference from Binaryen `src/passes/SSAify.cpp` `createNewIndexes()` plus direct `wasm-opt --ssa-nomerge` micro-replays on reduced param-write cases.
- The same pass-manager path still rejects per-function writebacks that fail module-aware validation, in addition to the existing `invalid-escape-carrier` and `suspicious-escape-carrier` families.
- The `cmd` package contains a native debug-artifact replay test in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt), and a focused `moon test src/cmd --target native --filter 'run_cmd_with_adapter validates ssa-nomerge on debug artifact'` run is currently green.
- The reduced `Func 523` follow-up now also lives in [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt), [`../../../../../src/ir/hot_lift_test.mbt`](../../../../../src/ir/hot_lift_test.mbt), [`../../../../../src/passes/ssa_nomerge_test.mbt`](../../../../../src/passes/ssa_nomerge_test.mbt), and the focused extracted-function CLI replay in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).

## Current Signoff State

- `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds.
- `moon test --package jtenner/starshine/ir --file ssa_destroy_test.mbt` is green with focused temp-local declaration and unreachable dead-tee regressions.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` is green with focused dead-param, live-param, unreachable-carrier, and value-if temp-local regressions.
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 500 --min-compared 500 --seed 0x5eed --keep-going-after-command-failures --pass ssa-nomerge --out-dir .tmp/recheck-ssa-nomerge-genvalid-500-if-order-fix` is green at `500 / 500` compared, `500` normalized matches, and `0` mismatches.
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --keep-going-after-command-failures --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-10000-if-order-fix-rerun` is green at `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, and `0` validation/generator/command failures.
- Historical `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff-gen-valid --pass ssa-nomerge` was green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff --pass ssa-nomerge` stays mismatch-free on comparable cases (`2380 / 10000` compared, `0` mismatches) and only stops on the Binaryen-only `binaryen-rec-group-zero` parser family.
- `bun scripts/pass-fuzz-compare.ts --count 2000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-mixed-seed51a --pass ssa-nomerge` stayed clean on all comparable cases (`1996 / 2000`, `0` mismatches, `4` Binaryen-only parser gaps).
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-genvalid-seed51a --pass ssa-nomerge` is also green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --ssa-nomerge` currently reports `Normalized WAT equal: yes` and `Canonical function compare equal: yes`, while `Canonical wasm equal: no`.
- `moon test --package jtenner/starshine/ir --file hot_lift_test.mbt -F '*wired to typed block results*'` is green for the reduced unreachable compare-carrier lift slice.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt -F '*func 523 shape*'` is green for the reduced pass-level `Func 523` follow-up.
- `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-func523-followup.wasm tests/node/dist/starshine-debug-wasi.wasm` still exits zero, and `wasm-tools validate /tmp/ssa-nomerge-func523-followup.wasm` still succeeds.

## Remaining Gap

- The direct `[SSA]001` temp-local declaration drift is closed by focused tests plus the current `10000 / 10000` `gen-valid` lane.
- The focused extracted-function CLI replay now proves that the old `Func 523` `writeback-validate:type mismatch` skip is retired.
- However, this follow-up did **not** rerun a fresh full-artifact traced skip census, so the older `2026-04-11` count of `228` `suspicious-escape-carrier` skips remains only historical context, not a fresh exact current count.
- The same input still succeeds under Binaryen with `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge`.
- So the current output-facing blocker for the reduced `Func 523` family is fixed, but broader raw-lowering coverage is still incomplete and direct artifact replay remains mandatory.

## Practical Rule

- Keep direct debug-artifact replay in the `ssa-nomerge` signoff loop.
- Treat the seeded `binaryen-rec-group-zero` wasm-smith failure as an oracle parser gap, not an SSA semantic mismatch.
- Treat current-source output parity as green for the fixed dead-param family and the reduced unreachable compare-carrier follow-up, but do not claim exact artifact parity until a fresh traced full-artifact replay shows that the remaining fail-closed raw-lowering skip families are gone or intentionally accepted.
- Keep the direct artifact replay and the `10000 / 10000` `gen-valid` compare lane together as the minimum signoff pair; the current `0x5eed` `gen-valid` lane is green in `.tmp/pass-fuzz-ssa-nomerge-genvalid-10000-if-order-fix-rerun`.

## Sources

- Implementation/test-map refresh: [`../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md)
- Research note for this refresh: [`../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md`](../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md)
- Archived research doc: [`../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md`](../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md)
- Pass implementation: [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- Pass manager guard: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- CLI artifact test surface: [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- Random compare harness: [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
