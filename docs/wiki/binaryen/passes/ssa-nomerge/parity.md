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

- A discoverable artifact-backed parity blocker still exists for `ssa-nomerge`.
- On `2026-04-10`, Starshine `--ssa-nomerge` failed final-module validation on the checked-in debug CLI artifact, while Binaryen `wasm-opt --ssa-nomerge` succeeded on the same valid input.
- Random compare fuzz is still useful, but it is not sufficient as the only signoff lane for `ssa-nomerge`.
- The seeded random coverage that was rerun for this pass stayed semantically clean and only hit a Binaryen parser-family gap, not a Starshine output mismatch.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt).
- The current invalid-writeback guard for this pass lives in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) and only filters the known `invalid-escape-carrier` and `suspicious-escape-carrier` families before final module assembly.
- The `cmd` package still contains a named debug-artifact replay test in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt), but a targeted `moon test` invocation for that case currently reports `Total tests: 0` and `no test entry found`, so it is not a reliable executable guard today.

## Active Gap

- `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds.
- `_build/native/release/build/cmd/cmd.exe --ssa-nomerge --out ... tests/node/dist/starshine-debug-wasi.wasm` fails with `error: final module validate: type mismatch`.
- The failing writeback is dumped as `Offending function idx=(Func 523)`.
- The same input succeeds under Binaryen with `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge`.
- The failing Starshine trace also reports earlier `skip-invalid-lower reason=suspicious-escape-carrier` bailouts on `Func 225`, `230`, `231`, and `235`, which means the current guard is active but does not cover the family that eventually corrupts `Func 523`.

## Practical Rule

- Keep direct debug-artifact replay in the `ssa-nomerge` signoff loop.
- Treat the seeded `binaryen-rec-group-zero` wasm-smith failure as an oracle parser gap, not an SSA semantic mismatch.
- Do not claim artifact parity for `ssa-nomerge` until direct Starshine replay on `tests/node/dist/starshine-debug-wasi.wasm` exits zero and the emitted output validates.

## Sources

- Archived research doc: [`../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md`](../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md)
- Pass implementation: [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- Pass manager guard: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- CLI artifact test surface: [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)
- Random compare harness: [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
