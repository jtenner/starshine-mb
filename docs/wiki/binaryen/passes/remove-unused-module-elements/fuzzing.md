---
kind: workflow
status: supported
last_reviewed: 2026-07-11
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

The direct script remains the underlying implementation, but copyable current guidance uses `bun fuzz compare-pass` so wrapper defaults stay centralized.

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage. Add a focused wrong-type `call_indirect` table fixture before making active-element cleanup more aggressive or introducing a `trapsNeverHappen` mode; the current source boundary is documented in [`./indirect-call-trap-preservation.md`](./indirect-call-trap-preservation.md).
