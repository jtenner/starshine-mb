# 0105 - Generated `-O4z` slot 19 `precompute` replay is now retired

## Status

- Date: 2026-04-18
- Type: Follow-up retirement note
- Retires: `[O4Z]003`
- Prior capture: [0096 - Generated `-O4z` slot 19 early `precompute` invalid raw output](./0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md)
- Shared audit note: [0093 - Generated `cmd.wasm` ordered `-O4z` pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)

## Scope

- Binaryen slot: `19`
- Observed Binaryen pass: `precompute-propagate`
- Starshine pass: `--precompute`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm`

## Previous failure

Per [0096](./0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md), the saved direct replay originally exited `0` but emitted invalid raw wasm. `wasm-tools validate` failed in `func 108` with:

- `type mismatch: expected i32 but nothing on stack`

That failure shape mattered because the command claimed success while silently dropping the required result payload.

## Current revalidation

On the current tree, the same saved predecessor now replays cleanly:

- direct replay:
  - `_build/native/release/build/cmd/cmd.exe --precompute --out .artifacts/o4z003-check.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm`
- direct validation:
  - `wasm-tools validate .artifacts/o4z003-check.raw.wasm`
- compare replay:
  - `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z003-check-compare --precompute`

Observed result on 2026-04-18:

- direct Starshine replay exit: `0`
- `wasm-tools validate` exit: `0`
- compare exit: `0`
- normalized WAT equal: `yes`
- canonical function compare equal: `yes`

This is enough to retire `[O4Z]003` as an active corruption blocker.

## Oracle Binaryen behavior

Authoritative upstream sources still describe this pass family as a conservative precompute/propagate fold, not a structural rewrite that may invalidate block results:

- Binaryen README pass help lists `--precompute` as: `apply precompute optimizations, using a constant-propagating SSA pass`.
- The same help text lists `--precompute-propagate` as: `apply precompute and propagate optimizations`.
- Current upstream `src/passes/Precompute.cpp` only replaces a constant `if` with a chosen arm when it can safely account for child retention; if conditionally executed effectful children would need preserving, it bails instead of forcing an invalid rewrite.

That upstream contract matches the durable repo rule for this slot: a `precompute` fold may simplify exact values, but it must not erase the carried value that still satisfies a typed block / function result.

## In-tree retirement evidence

The exact slot-19 root-cause reduction is still archived only as the original failure note, but the current tree already contains the two precompute hardening surfaces most directly aimed at this class of bad output:

- `src/passes/pass_manager.mbt`
  - `run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(...)`
  - `run_hot_pipeline_precompute_writeback_validates(...)`
- `src/passes/precompute_test.mbt`
  - `precompute keeps the structured branch-exit body valid after folding dead exact prefixes`
  - `precompute validates rewritten functions against full module call targets`

Inference from the current source and replay outcome: these earlier precompute writeback guards and full-module validation checks are the most likely reason slot `19` no longer emits invalid raw wasm. This note records that as an inference, not as a newly reduced single-function proof.

## Durable conclusion

- `[O4Z]003` is no longer an active wrong-code / invalid-output blocker.
- The saved slot-19 predecessor should stay in-tree as a cmd-level regression because it was a real generated-artifact corruption witness, not a synthetic unit case.
- Remaining `precompute` work should move back to parity/runtime and any future reduced lower-shape follow-ups, not this retired `func 108` missing-result symptom.

## Sources

- Prior slot capture: [0096 - Generated `-O4z` slot 19 early `precompute` invalid raw output](./0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md)
- Shared audit summary: [0093 - Generated `cmd.wasm` ordered `-O4z` pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- In-tree pass manager: `src/passes/pass_manager.mbt`
- In-tree pass implementation: `src/passes/precompute.mbt`
- In-tree pass tests: `src/passes/precompute_test.mbt`
- New cmd regression: `src/cmd/cmd_wbtest.mbt`
- Binaryen README pass help: <https://github.com/WebAssembly/binaryen/blob/main/README.md>
- Binaryen source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
