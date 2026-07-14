---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `merge-locals` Fuzzing Profile

Recommended direct signoff lane: build a fresh native CLI, then run the ordinary GenValid compare-pass lane for this admitted pass:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass merge-locals \
  --out-dir .tmp/pass-fuzz-merge-locals --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

This lane proves only the active Starshine forward epoch-alias subset. It does not by itself establish Binaryen `LocalGraph` orientation/rollback parity or justify preset scheduling; use the focused boundaries in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) before broadening the claim.

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
