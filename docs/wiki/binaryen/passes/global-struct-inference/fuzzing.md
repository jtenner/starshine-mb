---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `global-struct-inference` Fuzzing Profile

Recommended smoke lane: first build the native CLI, then run the ordinary GenValid compare-pass lane for this pass:

```sh
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The documented wrapper reaches the same harness implementation as the direct script. Do not substitute a merely present `target/native/...` artifact for the freshly built `_build/native/...` executable unless a timestamp or hash confirms it is current; see [`../../../AGENTS.md`](../../../AGENTS.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
