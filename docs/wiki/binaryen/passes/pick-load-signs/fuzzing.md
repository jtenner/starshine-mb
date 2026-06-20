---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `pick-load-signs` Fuzzing Profile

Recommended smoke lane after rebuilding the native CLI:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --keep-going-after-command-failures
```

Dedicated GenValid profile: `pick-load-signs-all`.

`pick-load-signs-all` is a replayable composite profile. GenValid manifests keep `config_label: "pick-load-signs-all"` and record the deterministic selected leaf in `selected_profile`, which the compare-pass summary can aggregate as selected-profile counters.

Current profile leaves:

- `pick-load-signs-signed-extend`: `i32.load8_u -> local.set -> local.get -> i32.extend8_s` positive signed rewrite candidate.
- `pick-load-signs-signed-shift`: `i32.load8_u` followed by a signed shift-pair use.
- `pick-load-signs-unsigned-mask`: `i32.load8_s` followed by an unsigned low-bit mask.
- `pick-load-signs-unsigned-shift`: already-unsigned `i32.load16_u` followed by an unsigned shift-pair use. This keeps the dedicated compare lane parity-clean while still exercising the shift-pair evidence shape; Starshine's broader mutating signed-load-to-unsigned-shift cleanup remains covered by focused pass tests rather than the Binaryen-parity aggregate lane.
- `pick-load-signs-unknown-use-boundary`: narrow load/local producer with an unrecognized equality use that should block rewrite.
- `pick-load-signs-mixed-width-boundary`: mixed signed-width evidence that should block rewrite.
- `pick-load-signs-width-mismatch-boundary`: load/use width mismatch that should block rewrite.
- `pick-load-signs-tee-boundary`: `local.tee` producer boundary, intentionally outside the upstream exact `local.set(load ...)` contract.
- `pick-load-signs-no-memory-boundary`: validating no-memory module for the pass manager skip surface.
- `pick-load-signs-imported-memory`: imported-memory positive candidate.
- `pick-load-signs-i64-watch`: non-mutating Starshine-local i64 watchpoint surface with already-signed `i64.load32_s` plus `i64.extend32_s`; upstream Binaryen `version_129` is effectively i32-only, so mutating i64 cleanup remains focused-test coverage rather than a Binaryen-parity aggregate lane expectation.

Focused generator coverage added with the profile proves profile resolution, aggregate leaf sampling, validating modules, pass-owned optimization candidates, skip/watchpoint boundary modules, and composite manifest `selected_profile` metadata.

Smoke evidence after the profile landed: `.tmp/pass-fuzz-pick-load-signs-profile-smoke-50-v2` used `--count 50 --seed 0x5eed --pass pick-load-signs --gen-valid-profile pick-load-signs-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`; it compared `50/50`, normalized `50`, and had `0` mismatches, validation failures, generator failures, property failures, or command failures. Selected-profile counts sampled all 11 leaves at least once in the run.

The remaining blocker for reclosing `pick-load-signs` under the current final pass closeout standard is running and recording the full four-lane matrix. The older 2026-06-03 audit remains useful behavior evidence, but it predates the now-required pass-specific profile lane.

The final closeout matrix should report these lanes separately:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --gen-valid-profile pick-load-signs-all --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-pick-load-signs-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass pick-load-signs --gen-valid-profile pass-fuzz-stress --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-pass-fuzz-stress-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `pass-fuzz-stress` as the current broad named all-profiles-style lane unless the repo adds a literal random all-profiles profile before closeout.
