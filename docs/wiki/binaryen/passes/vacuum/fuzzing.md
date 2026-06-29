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

- 2026-06-29: `.tmp/pass-fuzz-vacuum-random-all-profiles-10000-after-terminal-debris` ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass vacuum --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-vacuum-random-all-profiles-10000-after-terminal-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` after adding raw terminal-`unreachable` debris cleanup. Result: compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `1577` hits / `8423` misses. Selected subprofiles: `binaryen-oracle-portable=1958`, `ssa-nomerge-smoke=1973`, `coverage-forced-portable=2037`, `ssa-nomerge-parity=1970`, `pass-fuzz-stress=2062`.
- 2026-06-29: `.tmp/pass-fuzz-vacuum-random-all-profiles-1000-after-raw-nontrap-final` is superseded by the 10000-case lane above. It compared `1000/1000`, normalized `1000`, and had `0` mismatches/failures after raw guarded pure-expression cleanup for call/local-set and large structured-write hazards.

Explicit wasm-smith evidence:

- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-10000-after-terminal-debris` ran `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum-wasm-smith-10000-after-terminal-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`. Result: compared `9956/10000`, normalized matches `9955`, cleanup-normalized `0`, mismatches `1`, validation/property/generator failures `0`, command failures `44`, Binaryen cache `9956` hits / `0` misses plus Binaryen-failure cache `44` hits / `0` misses. Command failures are Binaryen/tool parser/canonicalization boundaries (`binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`). The remaining mismatch is `case-003694-wasm-smith`: Binaryen materializes a result-loop `f64.const` through a temporary local, while Starshine keeps the direct loop value. Both outputs validate; normalized/canonical Starshine wasm is smaller (`67` vs Binaryen `73` bytes), but raw Starshine output is larger (`76` vs Binaryen `73` bytes) because of unrelated raw type/elem representation. Classification remains open as a loop-result output-shape parity gap until source-backed Binaryen behavior or an accepted Starshine-win rationale is recorded.
- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-scratch-mismatch-replay-after-terminal-debris` replayed the four mismatches from the superseded scratch 10000 wasm-smith run. Terminal-unreachable debris fixes normalized `case-009332`, `case-009390`, and `case-009956`; only `case-003694` remains.
- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-1000-after-raw-nontrap-final` is superseded by the refreshed 10000-case lane above. It compared `997/1000` with `997` normalized matches, `0` mismatches, and three Binaryen/tool parser failures.
- 2026-06-29: `.tmp/pass-fuzz-vacuum-wasm-smith-1000-after-local-only` is superseded by the refreshed lanes above. It compared `997/1000` with `997` normalized matches, `0` mismatches, and three Binaryen empty-recursion-group parser/tool failures.

Ordinary dedicated-profile closeout lane command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --gen-valid-profile vacuum --out-dir .tmp/pass-fuzz-vacuum-genvalid-vacuum-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```
