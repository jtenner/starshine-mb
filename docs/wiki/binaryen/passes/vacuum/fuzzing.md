---
kind: workflow
status: working
last_reviewed: 2026-06-29
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `vacuum` Fuzzing Profile

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Latest direct GenValid evidence:

- 2026-06-29: `.tmp/pass-fuzz-vacuum-audit-after-const-if-10000-current` used `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd` because the stale `target/native/...` copy was not refreshed in this worktree. Command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum-audit-after-const-if-10000-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures`. Result: compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `1002` hits / `8998` misses. This supersedes the old 2026-06-05 timeout and verifies the constant-condition void-`if` cleanup parity fix.

Dedicated GenValid profile: `vacuum`.

- Profile intent: emit deterministic cleanup-heavy modules with explicit `nop`, scalar/ref pure `const; drop` debris, constant-condition void `if` scaffolds, empty then/live else forms, block-only `unreachable`, empty void blocks, nested pure debris, and a larger pure-debris function so the direct pass-owned lane no longer relies on the broad Binaryen-oracle profile to sample those shapes.
- Implementation/tests: `src/validate/gen_valid.mbt` registers `VacuumProfile`, `vacuum`, and aliases `vacuum-closeout` / `vacuum-all`; `src/validate/gen_valid_tests.mbt` locks profile resolution and the emitted trigger scaffold.
- Closeout-lane evidence: `.tmp/pass-fuzz-vacuum-genvalid-vacuum-10000-after-local-only-safe-binary` ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --gen-valid-profile vacuum --out-dir .tmp/pass-fuzz-vacuum-genvalid-vacuum-10000-after-local-only-safe-binary --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` after the local-only void-body cleanup slice. Result: compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `10000` hits / `0` misses. Manifest selected-profile counts: `vacuum=10000`.
- Smoke evidence: `.tmp/pass-fuzz-vacuum-profile-smoke-100-ref` ran `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass vacuum --gen-valid-profile vacuum --out-dir .tmp/pass-fuzz-vacuum-profile-smoke-100-ref --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`. Result: compared `100/100`, normalized matches `100`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `100` hits / `0` misses. Manifest selected-profile counts: `vacuum=100`. Trace sample `gen-valid-000001.wasm` recorded Starshine `pass:vacuum` total `924us` across two functions (`87us` + `837us`).

Broad random all-profiles evidence:

- 2026-06-29: `.tmp/pass-fuzz-vacuum-random-all-profiles-1000-after-raw-nontrap-final` ran `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass vacuum --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-vacuum-random-all-profiles-1000-after-raw-nontrap-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` after adding raw guarded pure-expression cleanup for call/local-set and large structured-write hazards. Result: compared `1000/1000`, normalized matches `1000`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `1000` hits / `0` misses. Earlier 20/100-case debug lanes with the same seed also completed after the fix, replacing the previous timeout caused by mismatch reduction on case 7.

Explicit wasm-smith smoke evidence:

- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-1000-after-raw-nontrap-final` ran `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 1000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum-wasm-smith-1000-after-raw-nontrap-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures`. Result: compared `997/1000`, normalized matches `997`, cleanup-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `3`, Binaryen cache `997` hits / `0` misses plus Binaryen-failure cache `3` hits / `0` misses. The three command failures are Binaryen/tool parser failures (`case-000029` and `case-000573` empty recursion groups, `case-000662` invalid tag index), not Starshine mismatches.
- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-1000-after-local-only` is superseded by the refreshed lane above. It compared `997/1000` with `997` normalized matches, `0` mismatches, and three Binaryen/tool parser failures.

Ordinary dedicated-profile closeout lane command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --gen-valid-profile vacuum --out-dir .tmp/pass-fuzz-vacuum-genvalid-vacuum-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```
