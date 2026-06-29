---
kind: workflow
status: working
last_reviewed: 2026-06-16
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `vacuum` Fuzzing Profile

Recommended smoke lane: run the ordinary mixed-generator compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Latest direct GenValid evidence:

- 2026-06-29: `.tmp/pass-fuzz-vacuum-audit-after-const-if-10000-current` used `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd` because the stale `target/native/...` copy was not refreshed in this worktree. Command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum-audit-after-const-if-10000-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures`. Result: compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `1002` hits / `8998` misses. This supersedes the old 2026-06-05 timeout and verifies the constant-condition void-`if` cleanup parity fix.

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage. A good first profile should explicitly generate `const; drop` debris, constant-condition `if` scaffolds, empty then/live else forms, block-only `unreachable`, and nested large-function pure debris so the direct pass-owned lane does not rely on the broad Binaryen oracle profile to sample those shapes.
