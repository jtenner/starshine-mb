---
kind: research
status: current
last_reviewed: 2026-06-29
sources:
  - ./1356-2026-06-29-heap-store-optimization-raw-plain-fastpath.md
  - ./1355-2026-06-29-heap-store-optimization-tiny-plain-fastpath.md
  - ./1354-2026-06-29-heap-store-optimization-hot-candidate-speed-rerun.md
  - ./1139-2026-06-25-heap-store-optimization-hot-candidate-benchmark.md
  - ./1138-2026-06-25-heap-store-optimization-final-closeout.md
  - ./1137-2026-06-25-heap-store-optimization-final-compare-matrix.md
  - ./1136-2026-06-25-heap-store-optimization-final-closeout-moon-validation.md
  - ./1113-2026-06-25-heap-store-optimization-post-refcast-safety-audit.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../agent-todo.md
---

# HSO final closeout after raw plain fast path

## Question

After the 2026-06-29 raw/lowered plain `struct.new` fast path fixed the reopened HOT-path speed blocker, can `[O4Z-AUDIT-HSO]` be closed again with refreshed direct compare evidence?

## Answer

Yes. Direct `heap-store-optimization` is closed again for the current Binaryen `version_130` audit scope.

The 2026-06-25 closeout in `1138` was superseded by `1139` only because the speed evidence was too narrow: a plain `struct.new` HOT-candidate fixture missed the user's `0.95x` Binaryen-speed target. That blocker is now closed by `1356`, whose raw/lowered exact plain-chain path reaches median Starshine `0.781ms` versus Binaryen `1.366ms` on the same 2000-function candidate fixture while keeping raw-skip reported as `no` and normalized/canonical outputs equal.

This note adds the refreshed post-speed compare signoff. The full four-lane HSO compare matrix was rerun with the rebuilt native Starshine binary and parallel workers. All compared cases matched with zero mismatches, validation failures, property failures, generator failures, or Starshine command failures. The explicit `wasm-smith` lane retained the same `44` Binaryen/oracle command failures as the earlier matrix; those are classified here as tool/oracle boundaries because no Starshine output was compared for those cases and all `9956` compared cases normalized.

## Refreshed validation and build evidence

Commands run in this closeout thread:

```sh
moon build --target native --release src/cmd
```

Result: passed, `Finished. moon: no work to do`.

```sh
moon info
moon fmt
```

Result: both passed; `moon info` reported the existing warning set.

```sh
moon test --package jtenner/starshine/passes --file perf_test.mbt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test --package jtenner/starshine/passes --file registry_test.mbt
moon test src/passes
```

Result:

- `perf_test.mbt`: `105/105` passed.
- `heap_store_optimization_test.mbt`: `417/417` passed.
- `registry_test.mbt`: `7/7` passed.
- `moon test src/passes`: `3576/3576` passed.

Repo-wide `moon test` was also attempted after `moon info`/`moon fmt`; it failed in the unrelated `src/cmd/cmd_wbtest.mbt` test `run_cmd_with_adapter skips irrelevant env overlay probes when cli already fixes startup mode`, where the observed env probes included `STARSHINE_IGNORE_IMPLICIT_TRAPS`. This is not an HSO failure and did not affect the focused HSO, pass-package, native-build, or compare evidence above.

## Refreshed direct compare matrix

All lanes used:

```sh
--jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The harness selected `16` jobs and the default cache directory `.tmp/pass-fuzz-cache`.

### Regular GenValid lane

```sh
bun fuzz compare-pass \
  --pass heap-store-optimization \
  --count 100000 \
  --seed 0x5eed \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-hso-full-100000-20260629
```

Result:

- requested/compared: `100000/100000`
- normalized matches: `100000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile counts: `binaryen-oracle-portable=100000`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `100000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

### Explicit wasm-smith lane

```sh
bun fuzz compare-pass \
  --pass heap-store-optimization \
  --wasm-smith \
  --count 10000 \
  --seed 0x5eed \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-hso-full-wasm-smith-10000-20260629 \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/9956`
- normalized matches: `9956`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `44`
- command-failure classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`
- cache: wasm-smith `10000` hits / `0` misses; Binaryen `9956` hits / `0` misses; Binaryen failures `44` hits / `0` misses

Agent classification: the `44` command failures are tool/Binaryen oracle boundaries, not HSO mismatches. They match the earlier closeout class distribution from `1137`, and every compared case normalized.

### Dedicated HSO profile lane

```sh
bun fuzz compare-pass \
  --pass heap-store-optimization \
  --count 10000 \
  --seed 0x5eed \
  --gen-valid-profile heap-store-optimization \
  --normalize local-cleanup-debris \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-hso-full-profile-10000-20260629 \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `0`
- cleanup-normalized matches: `10000`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile counts: `heap-store-optimization=10000`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

Interpretation: the only normalization used is the already documented HSO-profile-only `local-cleanup-debris` normalizer for Starshine's smaller folded-store cleanup output.

### Random all-profiles GenValid lane

```sh
bun fuzz compare-pass \
  --pass heap-store-optimization \
  --count 10000 \
  --seed 0x5555 \
  --gen-valid-profile random-all-profiles \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-hso-full-random-all-profiles-10000-20260629 \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile counts: `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, `binaryen-oracle-portable=1958`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

## Closeout evidence map

- Source/lit and Binaryen strategy refresh: `0776`.
- Source-backed behavior and safety matrix through HSO-C/H: `1113`, with exact descriptor `ref.cast` closed in `1109`.
- Earlier closeout evidence: `1136` Moon/native validation, `1137` full compare matrix, and `1138` O4z slot replay remain durable historical evidence.
- Reopening reason: `1139` found the proper plain `struct.new` candidate-running benchmark missed the user's `0.95x` speed target.
- Speed blocker closure: `1354` confirmed the blocker remained after later OI work; `1355` partially reduced HOT-path cost but still missed target; `1356` added the raw/lowered plain-chain path and met the target.
- Post-speed correctness closure: this note reran the full direct compare matrix with the rebuilt native binary and found no HSO mismatches or Starshine failures.

## Backlog disposition

`[O4Z-AUDIT-HSO]` is closed again and removed from the active backlog. The old `1138` closeout stays marked superseded for the 2026-06-25 speed conclusion, but this `1357` note supersedes the reopened `1139` status with fresh speed and compare evidence.

## Reopening criteria

Reopen HSO only if one of these occurs:

- Binaryen source/lit behavior changes the HSO movement or side-effect contract.
- A direct, dedicated-profile, wasm-smith, random-all-profiles, source-backed, or O4z-neighborhood case produces an HSO-owned mismatch not covered by the documented dedicated-profile `local-cleanup-debris` cleanup normalizer.
- A validation failure, Starshine command failure, or semantic mismatch is attributed to HSO.
- A new candidate-running HSO family misses the accepted speed target and is not covered by the raw complete-default-chain or raw plain-`struct.new` fast paths.
- Future edits broaden the raw fast path beyond its current simple childless-constant/ref.null, same-local, consecutive-store proof without equivalent safety evidence.
