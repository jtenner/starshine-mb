---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ./1644-2026-07-17-daeo-func8185-post-o0-residual.md
  - ./1643-2026-07-17-daeo-func8185-i64-zero-carrier.md
  - ./1627-2026-07-16-daeo-consumed-call-argument-slot-checkpoint.md
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# DAEO final direct closeout matrix

## Scope and tools

This note refreshes the full direct `dae-optimizing` generated closeout matrix after the exact one-set/sixteen-get `i64.const 0` carrier in note `1643`. It does not change optimizer behavior and does not close the separately owned public `optimize` / `shrink` / O4z pre-DAEO whole-command blockers from note `1584`.

The native release executable was forcibly relinked from the current workspace state by removing only the generated executable and rerunning:

```sh
moon build --target native --release src/cmd
```

Fresh executable evidence:

- path: `_build/native/release/build/cmd/cmd.exe`;
- size: `10162896` bytes;
- SHA-256: `3180bb10194a19fff1c939beee4d6d2b20f1f830aee0be34fa7e37e1097f55fa`.

Every authoritative lane set:

```sh
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

and confirmed `wasm-opt version 130 (version_130)`. A preliminary regular lane accidentally used the PATH `wasm-opt version 116`; it is non-authoritative and excluded from every result and classification below.

All four authoritative lanes used:

```sh
--pass dae-optimizing
--normalize drop-consts
--normalize unreachable-control-debris
--jobs auto
--starshine-bin _build/native/release/build/cmd/cmd.exe
--keep-going-after-command-failures
```

The default persistent `.tmp/pass-fuzz-cache` was retained. Starshine outputs were regenerated; only Binaryen oracle and wasm-smith inputs/failures were cacheable.

## Required matrix

### Regular GenValid, 100000

Artifacts: `.tmp/pass-fuzz-daeo-closeout-regular-100000-v130-20260717/`.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 100000 --seed 0x5eed --pass dae-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-daeo-closeout-regular-100000-v130-20260717 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- requested/compared: `100000/100000`;
- normalized: `100000`;
- cleanup-normalized: `0`;
- mismatches: `0`;
- validation/generator/property/command failures: `0`;
- selected profile: `binaryen-oracle-portable=100000`;
- cache: Binaryen success `100000/0`; all other cache counters `0/0`.

### Dedicated `dae-optimizing`, 10000

Artifacts: `.tmp/pass-fuzz-daeo-closeout-dedicated-10000-v130-20260717/`.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 --seed 0x5eed --pass dae-optimizing \
  --gen-valid-profile dae-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-daeo-closeout-dedicated-10000-v130-20260717 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- requested/compared: `10000/10000`;
- normalized: `10000`;
- cleanup-normalized: `0`;
- mismatches: `0`;
- validation/generator/property/command failures: `0`;
- selected profile: `dae-optimizing=10000`;
- cache: Binaryen success `10000/0`; all other cache counters `0/0`.

### Explicit wasm-smith, 10000

Artifacts: `.tmp/pass-fuzz-daeo-closeout-wasm-smith-10000-v130-20260717/`.

```sh
bun scripts/pass-fuzz-compare.ts \
  --wasm-smith --count 10000 --seed 0x5eed --pass dae-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-daeo-closeout-wasm-smith-10000-v130-20260717 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- requested/compared: `10000/9956`;
- normalized: `9955`;
- cleanup-normalized: `1`;
- mismatches: `0`;
- validation/generator/property failures: `0`;
- command failures: `44`, all Binaryen/oracle classes:
  - `binaryen-rec-group-zero=39`;
  - `binaryen-invalid-tag-index=1`;
  - `binaryen-table-index-out-of-range=1`;
  - `binaryen-bad-section-size=3`;
- cache: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

Agent judgment: the `44` failures are tool/Binaryen failures, not Starshine validation or semantic failures. The one cleanup-normalized case is the already documented generated unreachable/control debris family admitted only by the two explicit DAE normalizers.

### Random all profiles, 10000

Artifacts: `.tmp/pass-fuzz-daeo-closeout-random-all-10000-v130-20260717/`.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 --seed 0x5555 --pass dae-optimizing \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-daeo-closeout-random-all-10000-v130-20260717 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 10000 --keep-going-after-command-failures \
  --no-reduce-mismatches
```

- requested/compared: `10000/10000`;
- normalized: `9633`;
- cleanup-normalized: `0`;
- mismatches: `367`;
- validation/generator/property/command failures: `0`;
- cache: Binaryen success `10000/0`; all other cache counters `0/0`;
- mismatch profile split: `coverage-forced-portable=243`, `dae-effectful-args=124`.

The failure-directory set exactly matches note `1627`'s `.tmp/pass-fuzz-daeo-1627-final-random-all-10000-20260716/`. A recursive relative-file comparison checked all `3670` files across the `367` directories and found `0` changed files and `0` file-set differences.

The current residual size totals are therefore unchanged from the established source/replay-backed classification:

- Starshine raw delta: `-110224` bytes;
- Starshine canonical delta: `-797486` bytes;
- Starshine WAT delta: `-5465849` bytes;
- canonical-positive cases: `0`;
- WAT-positive cases: `0`.

Agent judgment: these `367` are the same measured/source-backed Starshine cleanup wins already classified in note `1627`, not a harness claim based on validity or size alone. `coverage-forced-portable` removes generated pure/unreachable cleanup debris after the same observable prefix; `dae-effectful-args` preserves removed-argument effects in order while deleting additional dead cleanup structure. Exact byte identity against the already reviewed failure corpus means the note-`1643` zero-carrier and subsequent selected artifact-only cleanup did not create a new generated family. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals in this matrix.

## Direct closeout decision

The direct generated closeout matrix is current after note `1643`:

- zero true semantic mismatches;
- zero Starshine validation failures;
- zero unknown/risky or generated size-losing residual families;
- unchanged, explicitly classified random-all cleanup wins;
- unchanged Binaryen/oracle-only wasm-smith command failures;
- both required DAE normalizers and an explicit freshly relinked native binary used in every authoritative lane.

The accepted current artifact remains:

- raw `3203060`, SHA-256 `367c7eaf8979696ea64b414d064fff48ca559cde83c0bc5b9417d20359f6ccf6`;
- canonical `3263950`, SHA-256 `66337f04f33ffbcceca2240bec20c21b386d5114224d2b02b0f51ca545051e7b`;
- Binaryen-v130 canonical `3262456`;
- canonical gap `+1494`, below the required `< +10000` boundary;
- Func `8185` body `2458` versus final Binaryen `2429`, with the residual `+29` closed against speculative movement/coalescing by note `1644`.

No public API changed and `.mbti` review is empty. The unrelated `moon.mod` formatter drift remains unstaged.

## Remaining release blocker

Direct DAEO generated behavior/output closeout is complete. Final release closure still requires fresh attribution and safe repair or source-backed closure of the public current-artifact pre-slot owners:

- `--optimize`: previously direct `vacuum`;
- `--shrink`: previously early `ssa-nomerge`;
- `--optimize -O4z`: previously early `ssa-nomerge`.

Those are `[WALL]001` whole-command/preset owners. They must be refreshed on the current binary and must reach the locked exact-once DAEO slot, or be closed with concrete current pass traces and an explicit release decision; direct-pass matrix success alone does not erase them.
