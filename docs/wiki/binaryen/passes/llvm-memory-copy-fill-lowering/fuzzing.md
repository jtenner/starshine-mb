---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `llvm-memory-copy-fill-lowering` Fuzzing Profile

## Current status: planned, not runnable

Do **not** treat the old 10,000-case command as a current smoke lane.

- Starshine has no registry entry or owner for `llvm-memory-copy-fill-lowering`; the spelling is an unknown-pass failure, as documented in [`starshine-strategy.md`](starshine-strategy.md).
- `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--llvm-memory-copy-fill-lowering`.
- Therefore the harness fails during admission, before it generates a case or runs Starshine/Binaryen. That is status evidence only, not parity evidence.

## What a future lane must exercise

A generic generated module is not enough. This transform needs eligible `memory.copy` / `memory.fill` use sites and observable module helper synthesis. Before publishing a command, prove all four compare-pass admission gates and retain direct fixtures for:

- memory32, single-memory `memory.copy` and `memory.fill` positives;
- generated `__memory_copy` / `__memory_fill` helper declaration and call shapes;
- effectful or trapping operand-order preservation;
- unchanged `memory.init` / `data.drop` and table-bulk instructions;
- documented memory64, multi-memory, and passive-segment fatal/unsupported boundaries; and
- bulk-memory feature cleanup.

The transform adds helpers and call effects, so normalized WAT equality alone is not enough: helper ABI, validation, and downstream effect-sensitive behavior need focused tests too. See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

## Future lane template

Only after active Starshine dispatch, harness admission, a Binaryen mapping, and a targeted bulk-memory profile exist:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass llvm-memory-copy-fill-lowering --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-llvm-memory-copy-fill-lowering --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-memory-copy-fill-profile> \
  --min-compared <meaningful-eligible-count>
```

Until then, use direct Binaryen fixtures and registry/harness inspection as the evidence sources; do not describe a parser rejection or empty lane as a pass signoff.
