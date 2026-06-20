---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `pick-load-signs` Fuzzing Profile

Recommended smoke lane after rebuilding the native CLI:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures
```

Dedicated GenValid profile: none documented for this pass yet.

Current status as of the 2026-06-20 refresh: this is the blocker for reclosing `pick-load-signs` under the current final pass closeout standard. The older 2026-06-03 audit remains useful behavior evidence, but it predates the now-required four-lane matrix and did not include a pass-specific GenValid profile lane.

Required future profile:

- stable profile name, likely `pick-load-signs` or `pick-load-signs-all`
- generated valid modules with at least one narrow-load `local.set(load ...)` candidate whenever practical
- signed-use families: direct sign extension and shift-pair evidence
- unsigned-use families: low-bit masks and unsigned shift-pair evidence
- boundary families: unknown use, mixed-width evidence, width mismatch, `local.tee` producer, no-memory skip, imported-memory candidate, and the local i64 Starshine watchpoint surface
- manifest metadata that records the selected subprofile/family for triage when the profile is composite
- focused generator tests proving the profile resolves, emits validating modules, and exercises pass-owned opportunities or boundaries

The final closeout matrix after that profile exists should report these lanes separately:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-wasm-smith-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --gen-valid-profile <pick-load-signs-profile> --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-<profile>-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass pick-load-signs --gen-valid-profile pass-fuzz-stress --out-dir .tmp/pass-fuzz-pick-load-signs-genvalid-pass-fuzz-stress-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `pass-fuzz-stress` as the current broad named all-profiles-style lane unless the repo adds a literal random all-profiles profile before closeout.
