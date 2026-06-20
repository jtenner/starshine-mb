# Precompute native path policy and bounded evidence refresh

## Question

Resolve the explicit native binary path blocker for canonical pass `precompute` in this checkout, then run a bounded current-code evidence refresh without claiming final closeout for `[O4Z-AUDIT-PC]`.

## Files reviewed

- `docs/README.md` — repo docs/wiki, pass signoff, validation, and native compare command policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — modern final closeout matrix and explicit native `--jobs auto --starshine-bin ...` rule.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` state.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` — modern status refresh.
- `docs/wiki/raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md` — descriptor split slice.
- `docs/wiki/raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md` — dedicated `precompute-all` profile slice.
- `docs/wiki/raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md` — narrow O4z raw-scalar recovery slice and first `_build` explicit-native smoke.
- `moon.mod`, `moon.pkg.json`, `src/cmd/moon.pkg`, `.gitignore`, and `scripts/lib/pass-fuzz-compare-task.ts` — local build output and compare harness path behavior.

## Native path finding and policy

`moon build --target native --release src/cmd` completed with `moon: no work to do`. In this checkout, the documented `target/native/release/build/cmd/cmd.exe` path still does not exist, while the executable native release binary exists at:

```text
_build/native/release/build/cmd/cmd.exe
```

The compare harness resolves a user-provided `--starshine-bin` literally relative to the repo root; it does not synthesize the historical `target/...` path or fall back to `_build/...` when the explicit path is missing. `.gitignore` ignores both `target` and `_build`, so creating a committed target artifact or symlink is not appropriate for this audit slice.

For `[O4Z-AUDIT-PC]` in this checkout, the accepted explicit native compare path is therefore `_build/native/release/build/cmd/cmd.exe` after running `moon build --target native --release src/cmd`. Final closeout reports must state this checkout-local deviation from the generic repo-standard command templates. Do not use the absent `target/...` path for precompute final lanes unless a future build/tooling change actually restores it.

## Commands and results

- `git status --short --branch && moon build --target native --release src/cmd && ls -l target/native/release/build/cmd/cmd.exe || true && ls -l _build/native/release/build/cmd/cmd.exe`
  - Result: worktree was clean; native build completed with no work to do; `target/native/release/build/cmd/cmd.exe` was absent; `_build/native/release/build/cmd/cmd.exe` existed and was executable.

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-native-path-policy-direct-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: timed out after `900s` before writing `result.json`; partial artifacts exist under the out dir but are not a completed compare result.

- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-native-path-policy-direct-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: completed with `jobs=16`; compared `100/100`; normalized `0`; cleanup-normalized `80`; mismatches `20`; validation/generator/property/command failures `0`; cache Binaryen `100` hits / `0` misses; selected profile `binaryen-oracle-portable=100`.
  - Agent classification: this is an open direct regular-GenValid behavior-parity gap, not a Starshine validation failure and not a command-path failure. The sample inspected mismatch (`case-000004-gen-valid`) shows Starshine and Binaryen produce validating but different normalized output after `--precompute` on generated unreachable/control-heavy input. I did not prove this family semantically safe or size-winning in this slice, so it must stay open instead of being accepted as normalized drift.

- `STARSHINE_TRACING=pass _build/native/release/build/cmd/cmd.exe --precompute --out .tmp/precompute-case4-starshine.raw.wasm .tmp/pass-fuzz-precompute-native-path-policy-direct-100/failures/case-000004-gen-valid/input.wasm`
  - Result: command completed and trace showed ordinary HOT `pass[precompute]:start` / mutation activity, not an O4z no-op or missing-native-path failure. This was only a sample inspection aid.

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-native-path-policy-precompute-all-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: completed with `jobs=16`; compared `1000/1000`; normalized `544`; cleanup-normalized `456`; mismatches `0`; validation/generator/property/command failures `0`; cache Binaryen `1000` hits / `0` misses; selected profiles: `precompute-drop-cleanup=147`, `precompute-control=160`, `precompute-gc-atomic-boundary=89`, `precompute-direct-prefix-watch=67`, `precompute-global=133`, `precompute-scalar=255`, `precompute-effect-boundary=149`.

## Classification

- Native path blocker: resolved for this checkout. Use `_build/native/release/build/cmd/cmd.exe` for precompute compare/signoff lanes after native build, and record the deviation from the generic `target/...` templates.
- Dedicated profile evidence: improved. The `precompute-all` 1000-case lane is green with the documented PC normalizers and explicit `_build` native path.
- Regular GenValid direct evidence: open. The 1000-case regular lane timed out before summary, and the bounded 100-case regular lane found `20` raw mismatches that remain unclassified behavior-parity gaps.
- O4z slot/neighborhood evidence: unchanged. This slice did not replay historical slot19/slot43 artifacts or recover additional O4z no-op surfaces.
- `[O4Z-AUDIT-PC]`: remains open and is not closeable under the modern standard.

## Commands not run

- No final closeout lane was run. The completed 1000-case dedicated-profile lane is bounded evidence only and does not replace the required 10000-case dedicated lane or the other closeout lanes.
- No wasm-smith lane was run.
- No broad `pass-fuzz-stress` lane was run.
- No O4z slot19/slot43 artifact replay was run because the historical `.artifacts` paths are still absent in this checkout.
- No pass implementation was attempted in this slice; the newly refreshed regular-GenValid mismatch family needs a focused reduction/TDD slice before any behavior change.

## Next work

1. Reduce and classify the regular GenValid mismatch family from `.tmp/pass-fuzz-precompute-native-path-policy-direct-100/failures/`, starting with `case-000004-gen-valid`, then add the smallest focused precompute regression before changing behavior.
2. If the mismatch family proves to be unreachable/control debris with a semantic-safe normal form, either implement the Starshine cleanup or add a carefully justified normalizer only with measured/source-backed evidence; do not mark it safe based only on validation.
3. Keep the dedicated `precompute-all` lane green as the O4z no-op boundary is narrowed.
4. Final closeout still needs the four-lane matrix with `_build/native/release/build/cmd/cmd.exe`, plus O4z slot/neighborhood decision evidence.
