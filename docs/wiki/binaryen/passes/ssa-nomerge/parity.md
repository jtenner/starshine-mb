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
- On `2026-04-10`, the stale checked-in native release binary still failed final-module validation on the checked-in debug CLI artifact, while Binaryen `wasm-opt --ssa-nomerge` succeeded on the same valid input.
- On the same day, the current source build stopped emitting the invalid final module by rejecting bad per-function rewrites before writeback.
- Random compare fuzz is still useful, but it is not sufficient as the only signoff lane for `ssa-nomerge`.
- The seeded random coverage that was rerun for this pass stayed semantically clean and only hit a Binaryen parser-family gap, not a Starshine output mismatch.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt).
- The current invalid-writeback guard for this pass lives in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) and now also rejects per-function writebacks that fail module-aware validation, in addition to the existing `invalid-escape-carrier` and `suspicious-escape-carrier` families.
- The `cmd` package contains a native debug-artifact replay test in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt), and a focused `moon test src/cmd --target native --filter 'run_cmd_with_adapter validates ssa-nomerge on debug artifact'` run is currently green.

## Active Gap

- `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds.
- `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-current.wasm tests/node/dist/starshine-debug-wasi.wasm` exits zero and final validation completes.
- That current source replay now records `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch`, which restores artifact safety but also proves exact pass parity is still open.
- The same traced source replay also records at least one other validation-backed skip (`Func 3773`, `writeback-validate:stack underflow`), so `Func 523` was not the only artifact-only bad writeback family.
- The same input succeeds under Binaryen with `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge`.
- The stale checked-in release binary still fails on `Func 523`, so direct artifact investigations must distinguish stale binaries from the current source build.

## Practical Rule

- Keep direct debug-artifact replay in the `ssa-nomerge` signoff loop.
- Treat the seeded `binaryen-rec-group-zero` wasm-smith failure as an oracle parser gap, not an SSA semantic mismatch.
- Do not claim artifact parity for `ssa-nomerge` until direct Starshine replay on `tests/node/dist/starshine-debug-wasi.wasm` both:
  - exits zero with a current source build, and
  - stops relying on `writeback-validate:*` fail-closed skips for the remaining Binaryen-successful functions.

## Sources

- Archived research doc: [`../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md`](../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md)
- Pass implementation: [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- Pass manager guard: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- CLI artifact test surface: [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)
- Random compare harness: [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
