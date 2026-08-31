---
kind: workflow
status: supported
last_reviewed: 2026-08-30
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/LocalGraph.cpp
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_ssa_full_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../tooling/pass-fuzz-compare.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/fuzzing.md
---

# `ssa` fuzzing and comparison

## Admission and oracle

Full `ssa` is admitted by `pass-fuzz-compare` under canonical pass name `ssa`, mapped to Binaryen `--ssa`.

All closeout results below used:

- Starshine native SHA-256 `a130c0c5f9f9bb3fcc1ad265dfc14e414d2f3184c9df1df01c0686774ee62b66`;
- `_build/native/release/build/cmd/cmd.exe`;
- explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`;
- `wasm-opt version 131 (version_131)`;
- Binaryen SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`;
- `--require-binaryen-version 131`;
- `--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`;
- persistent `.tmp/pass-fuzz-cache`;
- `--no-reduce-mismatches`.

## Dedicated profiles

`ssa-all` is the ordinary dedicated aggregate. It deterministically samples one of fifteen singleton profiles and records both requested `config_label: "ssa-all"` and per-case `selected_profile` / `profile_case_label` metadata.

| Profile | Transformation family |
| --- | --- |
| `ssa-fresh-set` | fresh local per non-SSA `local.set`, then single-source get retargeting |
| `ssa-fresh-tee` | fresh local per non-SSA `local.tee`, preserving the tee stack result |
| `ssa-param-entry` | single-source parameter entry remains on the parameter slot |
| `ssa-default-numeric` | single-source numeric/vector body-local entry becomes an explicit default |
| `ssa-default-ref` | nullable reference entry becomes `ref.null`, including typed parent repair |
| `ssa-unreachable` | unreachable get/no-source behavior and unreachable write allocation boundary |
| `ssa-merge-explicit` | two explicit incoming writes feed a fresh merge local through tees |
| `ssa-merge-param-entry` | explicit write plus parameter entry, including function-entry prepend |
| `ssa-merge-default-entry` | explicit write plus ordinary default entry, with no synthetic prepend |
| `ssa-merge-shared-sets` | multiple merge gets share predecessor writes and form nested tees in get order |
| `ssa-loop` | loop-header/backedge local merge |
| `ssa-branch` | direct branch, `br_if`, and `br_table` predecessor joins |
| `ssa-typed-control` | typed loop-parameter control plus body-local SSA traffic |
| `ssa-nested-value` | operand-nested result block local traffic |
| `ssa-eh` | explicit `try_table` / tagged-throw exceptional predecessors |

The aggregate alias is `ssa`, `ssa-closeout`, or `ssa-all-profiles` when resolving a GenValid profile name.

## Normalizers

Two symmetric compare normalizers are used deliberately:

- `local-cleanup-debris` removes empty-arm `nop` differences. Starshine omits these nops and is canonically smaller in every affected regular case.
- `ssa-local-allocation-debris` is added only to the dedicated aggregate to classify declaration-only unreachable local allocation drift. It does not erase the typed-control residual family.

The normalizers do not hide validation failures, command failures, size losses, or the typed-control output family described below.

## Final four-lane matrix

### Regular GenValid

Command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass ssa \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-ssa-final2-regular-100000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --require-binaryen-version 131 --max-failures 2000 \
  --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested / compared: `100000 / 100000`;
- ordinary normalized: `73,550`;
- cleanup-normalized: `26,450`;
- residual mismatches: `0`;
- validation / generator / property / command failures: `0 / 0 / 0 / 0`;
- Binaryen cache: `100,000` hits / `0` misses;
- canonical sizes: Starshine `422,101,053`, Binaryen `422,184,771` bytes;
- canonical smaller / equal / larger: `26,450 / 73,550 / 0`.

### Explicit wasm-smith

Command shape:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed \
  --pass ssa --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-ssa-final2-wasm-smith-10000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --require-binaryen-version 131 --max-failures 2000 \
  --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested / compared: `10,000 / 9,956`;
- ordinary normalized: `9,955`;
- cleanup-normalized: `1`;
- residual mismatches: `0`;
- Starshine validation / generator / property failures: `0 / 0 / 0`;
- command failures: `44`, all Binaryen/tool boundaries:
  - `binaryen-rec-group-zero=39`;
  - `binaryen-bad-section-size=3`;
  - `binaryen-invalid-tag-index=1`;
  - `binaryen-table-index-out-of-range=1`;
- wasm-smith cache: `10,000 / 0` hits/misses;
- Binaryen cache: `9,956 / 0` hits/misses plus `44 / 0` failure hits/misses;
- canonical sizes: Starshine `311,017`, Binaryen `311,018` bytes;
- canonical smaller / equal / larger: `1 / 9,955 / 0`.

### Dedicated `ssa-all`

Command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa \
  --gen-valid-profile ssa-all \
  --normalize local-cleanup-debris --normalize ssa-local-allocation-debris \
  --out-dir .tmp/pass-fuzz-ssa-final2-all-10000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --require-binaryen-version 131 --max-failures 2000 \
  --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested / compared: `10,000 / 10,000`;
- ordinary normalized: `8,713`;
- cleanup-normalized: `640`;
- residuals: `647`, all selected profile `ssa-typed-control`;
- validation / generator / property / command failures: `0 / 0 / 0 / 0`;
- Binaryen cache: `10,000 / 0` hits/misses;
- every one of the `647` residuals is canonically smaller in Starshine;
- canonical sizes: Starshine `644,768`, Binaryen `647,356` bytes;
- canonical smaller / equal / larger: `647 / 9,353 / 0`.

Selected singleton counts:

- branch `717`;
- default numeric `638`;
- default ref `646`;
- EH `709`;
- fresh set `674`;
- fresh tee `653`;
- loop `665`;
- merge default entry `652`;
- merge explicit `624`;
- merge param entry `681`;
- merge shared sets `688`;
- nested value `683`;
- param entry `683`;
- typed control `647`;
- unreachable `640`.

Typed-control classification is an intentional Starshine win, not an unexplained safe drift: Starshine's typed-loop lowering reuses fewer stack-carrier locals and emits four fewer canonical bytes per case while preserving the local merge values. A separate `1,000`-case Node lane (`.tmp/pass-fuzz-ssa-final2-typed-runtime-1000`) externally validates every pair and reports runtime matrix `all-equal`: `1,000` equal results, zero traps, unsupported runtimes, nondeterministic imports, or semantic mismatches. The entire lane is canonically smaller: Starshine `90,000`, Binaryen `94,000` bytes.

### Random all-profiles

Command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass ssa \
  --gen-valid-profile random-all-profiles \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-ssa-final2-random-all-10000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --require-binaryen-version 131 --max-failures 2000 \
  --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested / compared: `10,000 / 10,000`;
- ordinary normalized: `8,601`;
- cleanup-normalized: `1,315`;
- residuals: `84`;
- validation / generator / property / command failures: `0 / 0 / 0 / 0`;
- Binaryen cache: `10,000 / 0` hits/misses;
- all residuals are pre-existing unreachable/control cleanup families selected by other pass profiles:
  - `remove-unused-brs-cleanup=44`;
  - `remove-unused-brs-control=40`;
- all `84` are canonically smaller in Starshine; none are equal or larger;
- canonical sizes: Starshine `7,838,788`, Binaryen `7,840,955` bytes;
- canonical smaller / equal / larger: `870 / 9,130 / 0`.

## Performance

The canonical production artifact is `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm` (`4,977,401` bytes).

Final attribution (`.tmp/ssa-final2-performance.stdout`) reports:

- Starshine no-trace command: `4,023.738ms`;
- Binaryen command: `1,202.014ms`;
- Starshine direct pass timer: `0ms` because full `ssa` commits through the raw LocalGraph path;
- Starshine raw owner: `3,246.836ms`;
- Binaryen pass timer: `654.843ms`;
- Starshine output: `5,372,978` canonical bytes;
- Binaryen output: `5,378,402` canonical bytes, so Starshine is `5,424` bytes smaller.

The repository pass-local timing gate is technically satisfied because the active transform is outside the HOT pass timer, but whole-command/raw-owner parity is not: the direct command is about `3.35x` Binaryen. This is attributed to the shared serial function envelope and LocalGraph raw owner under `[WALL]001`, not hidden as completed performance parity. Feature, validity, and fuzz closeout are complete; future wall work should preserve the exact transformation matrix and smaller output.
