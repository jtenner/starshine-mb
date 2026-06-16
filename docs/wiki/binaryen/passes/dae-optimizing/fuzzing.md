---
kind: workflow
status: supported
last_reviewed: 2026-06-16
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `dae-optimizing` Fuzzing Profile

Recommended smoke lane: run the ordinary mixed-generator compare-pass lane with the documented DAE cleanup normalizers:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: none documented specifically for `dae-optimizing` yet. The general `pass-dae` GenValid profile can be used for targeted direct-call and parameter-pruning generator work, but it is not the current pass-folder closeout profile.

If a future audit adds a dedicated `dae-optimizing` composite profile, update this page with the profile name, intended smoke/closeout count, required feature floors, normalizers, and manifest fields needed for replay triage.
