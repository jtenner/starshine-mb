---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-07-10
sources:
  - https://moonbitlang.github.io/moon/commands.html
  - https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md
  - ../../../../AGENTS.md
  - ../../../README.md
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../_build/native/release/build/cmd/cmd.exe
  - ../../../../target/native/release/build/cmd/cmd.exe
related:
  - ../../tooling/pass-fuzz-compare.md
  - ../../tooling/validation-gates.md
  - ../../tooling/fuzz-runner.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# Native Build Output Path Policy - 2026-07-10

## Scope

This bridge records the distinction between MoonBit's public command interface and Starshine's local, freshness-sensitive native CLI path used by parallel `compare-pass` runs.

## Primary-source recheck

The official Moon command manual documents `moon build` / `moon run` target-and-release invocation surfaces. It does **not** make a repository-specific promise that Starshine's freshly built CLI should be selected from `target/native/...` rather than `_build/native/...`. The exact artifact path is therefore local build-layout evidence, not a portable MoonBit CLI guarantee.

## Local evidence checked

- `moon build --target native --release src/cmd` is the required preparatory build for parallel compare-pass lanes.
- `scripts/lib/pass-fuzz-compare-task.ts` accepts an explicit `--starshine-bin`; with concurrent jobs it avoids parallel `moon run` processes that contend on `_build/.moon-lock`.
- This worktree contains both `_build/native/release/build/cmd/cmd.exe` and `target/native/release/build/cmd/cmd.exe`. Presence alone is insufficient evidence of freshness: a legacy `target/...` artifact can persist after a build that refreshed `_build/...`.
- `AGENTS.md` and `docs/README.md` therefore define the current Starshine policy: after a current native release build, pass `_build/native/release/build/cmd/cmd.exe`; treat `target/native/...` as stale unless its timestamp or hash proves it is the same freshly built binary.

## Durable conclusions

1. Copyable current compare-pass commands must use `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd`.
2. Historical reports may retain the path that was actually used. Do not rewrite them as if the run used a different executable.
3. A `target/native/...` path is valid only when a maintainer explicitly verifies it against the freshly built `_build/...` artifact; it is not the default signoff path.
4. Pages that document generic pass signoff should link to the canonical compare-pass workflow instead of independently inventing native-path guidance.

## Links checked

- Moon command manual: <https://moonbitlang.github.io/moon/commands.html>
- Moon manual source: <https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md>
- Local signoff policy: [`../../../../AGENTS.md`](../../../../AGENTS.md), [`../../../README.md`](../../../README.md)
- Harness concurrency implementation: [`../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts)
- Current and legacy artifact locations: [`../../../../_build/native/release/build/cmd/cmd.exe`](../../../../_build/native/release/build/cmd/cmd.exe), [`../../../../target/native/release/build/cmd/cmd.exe`](../../../../target/native/release/build/cmd/cmd.exe)
