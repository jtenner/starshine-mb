---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `remove-unused-module-elements` Fuzzing Profile

Recommended direct-pass signoff lane: build a fresh native CLI, then run the ordinary GenValid comparison through the project wrapper:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass remove-unused-module-elements --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-remove-unused-module-elements --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

For explicit v131 closeout, pin `--wasm-opt-bin` to an official `version_131` `wasm-opt` (PATH may still be v130).

The direct script remains the underlying implementation, but copyable current guidance uses `bun fuzz compare-pass` so wrapper defaults stay centralized.

Dedicated GenValid profile: none documented for this pass yet. Do **not** use `pass-cleanup` as a RUME-specific closeout lane: against v131 it floods with large-body local/`tee` expression-shape mismatches unrelated to RUME keep/drop. Prefer regular GenValid, `random-all-profiles`, and `wasm-smith` until a RUME-owned profile exists.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage. Add a focused wrong-type `call_indirect` table fixture before making active-element cleanup more aggressive or introducing a `trapsNeverHappen` mode; the current source boundary is documented in [`./indirect-call-trap-preservation.md`](./indirect-call-trap-preservation.md).

Known classified wasm-smith mismatch vs Binaryen v131: huge memory64 + active data where Binaryen's `Index(initial << pageSizeLog2)` truncates and false-positives OOB (`case-004700` family). Starshine's full u64 byte-size check is the intentional win; see [`./parity.md`](./parity.md).
