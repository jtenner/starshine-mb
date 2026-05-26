# DAE011 recovery timing blocker

Date: 2026-05-26

## Scope

This recovery run selected `[DAE]011 - Performance Stabilization` because active DAE follow-up tasks remain in `agent-todo.md` and no DAE implementation files had unstaged or staged in-progress changes. The run intentionally avoided modifying DAE pass code because the workspace already had a large unrelated staged SGO/WAST change set.

## Evidence gathered

Command attempted:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --canonicalize-binaryen-output \
  --dae-optimizing \
  --out-dir .tmp/dae011-recovery-timing-20260526-rerun
```

Result: timed out after 360 seconds after writing both canonical wasm outputs and both normalized WAT files, but before writing `result.json` or printing the usual first-diff/timing summary. A prior identical attempt with out dir `.tmp/dae011-recovery-timing-20260526` timed out after 120 seconds in the same post-artifact state.

Generated artifact validation from the first attempt:

```sh
wasm-opt --all-features .tmp/dae011-recovery-timing-20260526/starshine.wasm -o /tmp/dae011-starshine-validate.wasm
wasm-opt --all-features .tmp/dae011-recovery-timing-20260526/binaryen.wasm -o /tmp/dae011-binaryen-validate.wasm
```

Both canonical outputs validated, with the existing large-local-count VM warning.

Generated output sizes from the first attempt:

- `.tmp/dae011-recovery-timing-20260526/starshine.wasm`: 3,541,026 bytes
- `.tmp/dae011-recovery-timing-20260526/binaryen.wasm`: 3,293,022 bytes
- `.tmp/dae011-recovery-timing-20260526/starshine.raw.wasm`: 3,533,761 bytes
- `.tmp/dae011-recovery-timing-20260526/binaryen.raw.wasm`: 3,278,872 bytes

The rerun produced very large normalized WAT files before timing out:

- `.tmp/dae011-recovery-timing-20260526-rerun/starshine.print.wat`: 392,747,392 bytes
- `.tmp/dae011-recovery-timing-20260526-rerun/binaryen.print.wat`: 372,441,344 bytes

## Classification

No new DAE semantic mismatch or validation failure was reproduced in this run. The blocker observed here is a compare-helper completion/performance blocker: the helper can produce and validate artifacts but does not finish its normalized-WAT comparison/reporting step within 360 seconds for the current both-canonical DAE debug artifact.

This does not close `[DAE]011`: the pass-local timing target still needs a successful timing report, and the latest documented completed DAE timing remains over the 2x target in `agent-todo.md` / `starshine-strategy.md`.

## Required subtasks before `[DAE]011` can close

1. Add or expose a lightweight timing/report mode for `scripts/self-optimize-compare.ts` that records Starshine and Binaryen pass-local timings and validation status without requiring full normalized-WAT comparison for huge DAE artifacts.
2. Re-run `--canonicalize-binaryen-output --dae-optimizing` on `tests/node/dist/starshine-debug-wasi.wasm` with that timing mode and record pass-local timings.
3. If Starshine remains over `2x` Binaryen pass-local time, profile the DAE-owned portion separately from compare-helper WAT printing/comparison.
4. Only after a concrete DAE-owned hotspot is identified, make a focused code change with tests first; otherwise keep the runtime owner as compare-helper/WALL-style infrastructure rather than DAE pass logic.
5. Update `agent-todo.md`, `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`, and `docs/wiki/log.md` when the successful timing/profiling evidence changes `[DAE]011` status.
