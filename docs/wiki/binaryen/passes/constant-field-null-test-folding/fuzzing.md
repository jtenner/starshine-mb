---
kind: workflow
status: working
last_reviewed: 2026-06-16
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `constant-field-null-test-folding` Fuzzing Profile

Recommended smoke lane: run the ordinary mixed-generator compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass constant-field-null-test-folding --out-dir .tmp/pass-fuzz-constant-field-null-test-folding --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
