---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/binaryen/2026-07-11-instrument-memory-current-main-recheck.md
---

# `instrument-memory` Fuzzing Status

## Current status: planned-only

Do **not** run a Starshine-vs-Binaryen `compare-pass` lane for `instrument-memory` today.

- Starshine has no `instrument-memory` registry entry in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), so the CLI has no local transform to execute.
- The comparison harness's `SUPPORTED_PASS_FLAGS` allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--instrument-memory`; `--pass instrument-memory` therefore fails before any generated module is compared.
- This is a **status-validation boundary**, not zero-mismatch parity evidence. The upstream behavior remains documented in [`./index.md`](./index.md) and the current source recheck, but no local implementation exists to sign off.

Use this harmless discovery command only to inspect the harness roster:

```sh
bun fuzz compare-pass --list-passes
```

`instrument-memory` should be absent until Starshine deliberately implements and admits the pass.

## Future runnable template

After all of the following are true—(1) a real local module pass is registered, (2) its spelling is added to the harness allowlist, and (3) focused transformed-shape tests cover the intended slice—start with an explicit native lane:

```sh
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass instrument-memory --out-dir .tmp/pass-fuzz-instrument-memory --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Do not copy that command as current guidance. Before making it runnable, add fixture-backed coverage for the selected implementation scope: scalar loads/stores, `memory.grow`, helper-import ABI, effect addition, filters, memory64, GC scalar hooks, and explicit preservation of unsupported bulk-memory, atomic, SIMD-payload, and reference-payload families as applicable.

## Maintenance rule

When the pass becomes runnable, replace this page's planned-only status with:

- the canonical accepted local and Binaryen spellings;
- the exact supported feature/profile matrix and required normalizers;
- smoke and signoff counts;
- output/semantic classification rules for helper-import ABI differences; and
- links to the owner, focused tests, parity report, and any documented intentional divergence.
