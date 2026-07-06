# Duplicate Import Elimination GenValid Profile And Timing Evidence

Date: 2026-07-06

## Scope

This note records the dedicated `duplicate-import-elimination` GenValid profile, direct pass-local timing fixture evidence, and final direct-pass closeout matrix for the O4z DIE audit. The four required fuzz lanes are complete as of this note: regular GenValid 100000, explicit wasm-smith 10000, dedicated DIE GenValid profile 10000, and random-all-profiles 10000.

## Code changes summarized

- Added GenValid profile leaves:
  - `duplicate-import-elimination-functions`
  - `duplicate-import-elimination-nonfunction`
  - aggregate/closeout profile `duplicate-import-elimination`
- Aliases:
  - `duplicate-import-elimination-closeout`
  - `duplicate-import-elimination-all`
  - `duplicate-import-elimination-all-profiles`
  - `die`
  - `die-closeout`
- Added `duplicate-import-elimination` to `random-all-profiles` sampling.
- Added manifest `profile_case_label` values:
  - `duplicate-import-elimination:functions`
  - `duplicate-import-elimination:nonfunction-negative`

The functions leaf emits same `(module, base)` duplicate function imports with a different-signature first representative, then two same-signature void imports so the Binaryen v130 current-representative reset rule is exercised. It also includes `call`, `ref.func`, `elem declare`, `export`, `start`, and module-code users of duplicate function imports. The nonfunction leaf emits duplicate global imports with the same `(module, base)` as a negative case because current Binaryen DIE is function-import-only.

## Validation commands

- Red-first profile test before implementation:
  - `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt`
  - Failed because `DuplicateImportElimination*Profile` constructors did not exist and the test referenced the new expected profile behavior.
- After implementation:
  - `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` — `134/134` passed.
  - `moon fmt` — passed.
  - `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` — `97/97` passed, with pre-existing warnings in `ir/hot_verify.mbt`, `wast/module_wast.mbt`, and `wast/parser.mbt`.
  - `moon build --target native --release src/cmd` — passed and refreshed `_build/native/release/build/cmd/cmd.exe`, with pre-existing unused-function warnings in `src/passes/pass_manager.mbt` and WAST warnings.

## GenValid profile smoke

Command:

```sh
moon run src/fuzz -- --emit-gen-valid-batch --count 8 --seed 0x5eed --out-dir .tmp/die-genvalid-profile-smoke --gen-valid-profile duplicate-import-elimination --manifest .tmp/die-genvalid-profile-smoke/manifest.json
```

Result:

- generated `8/8`
- attempts `8`
- skipped candidates `0`
- manifest `profile=duplicate-import-elimination`
- selected both function-opportunity and nonfunction-negative cases.

## Dedicated profile compare lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-import-elimination --gen-valid-profile duplicate-import-elimination --out-dir .tmp/pass-fuzz-die-genvalid-duplicate-import-elimination-10000-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result from `result.json`:

- requested: `10000`
- compared: `10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: wasm-smith `0/0`, Binaryen `10000` hits / `0` misses, Binaryen failures `0/0`
- selected profiles:
  - `duplicate-import-elimination-functions`: `7500`
  - `duplicate-import-elimination-nonfunction`: `2500`
- profile case labels:
  - `duplicate-import-elimination:functions`: `7500`
  - `duplicate-import-elimination:nonfunction-negative`: `2500`

Agent classification: behavior-parity match for this dedicated profile lane. The functions leaf exercises the source-confirmed current-representative reset plus function-user rewrites, while the nonfunction leaf confirms the current Binaryen function-import-only negative contract.

## Remaining required fuzz lanes

### Regular GenValid 100000

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass duplicate-import-elimination --out-dir .tmp/pass-fuzz-die-genvalid-100000-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result from `result.json`:

- requested: `100000`
- compared: `100000`
- normalized matches: `100000`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: wasm-smith `0/0`, Binaryen `1315` hits / `98685` misses, Binaryen failures `0/0`
- selected profiles: `binaryen-oracle-portable=100000`

Agent classification: behavior-parity match for the regular GenValid lane.

### Explicit wasm-smith 10000

Required unnormalized command:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass duplicate-import-elimination --out-dir .tmp/pass-fuzz-die-wasm-smith-10000-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Unnormalized result from `result.json`:

- requested: `10000`
- compared: `9956`
- normalized matches: `9955`
- cleanup-normalized matches: `0`
- raw mismatches: `1`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `44`
- command failure classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`
- cache: wasm-smith `10000` hits / `0` misses, Binaryen `106` hits / `9850` misses, Binaryen failures `0` hits / `44` misses

The single raw mismatch was `.tmp/pass-fuzz-die-wasm-smith-10000-20260706/failures/case-009332-wasm-smith`. The input has no duplicate function imports; it only has an imported memory and an unreachable block/control shape. Binaryen normalizes the unreachable tail to `drop(memory.size); drop(f64.const); unreachable`; Starshine's normalized output has the same prefix followed by `drop(unreachable); unreachable`. Agent classification: semantic-safe unreachable-control-debris representation drift unrelated to DIE, not a duplicate-import-elimination behavior mismatch. Both paths trap before any later observable value, and no DIE import rewrite is involved.

Confirmation command with the existing cleanup normalizer:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass duplicate-import-elimination --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-die-wasm-smith-10000-unreachable-normalized-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Normalized confirmation result:

- requested: `10000`
- compared: `9956`
- normalized matches: `9955`
- cleanup-normalized matches: `1`
- raw mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `44`, all the same Binaryen/tool classes as the unnormalized run
- cache: wasm-smith `10000` hits / `0` misses, Binaryen `9956` hits / `0` misses, Binaryen failures `44` hits / `0` misses

Agent classification: wasm-smith lane is accepted for DIE behavior parity with one classified semantic-safe unreachable-control-debris output-shape drift and 44 Binaryen/tool command failures outside Starshine's pass semantics.

### Random all-profiles GenValid 10000

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass duplicate-import-elimination --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-die-random-all-profiles-10000-20260706 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result from `result.json`:

- requested: `10000`
- compared: `10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: wasm-smith `0/0`, Binaryen `4725` hits / `5275` misses, Binaryen failures `0/0`
- selected profile counts:
  - `local-subtyping-structured=549`
  - `coverage-forced-portable=1102`
  - `duplicate-import-elimination-functions=800`
  - `coalesce-locals-straight-line=438`
  - `heap2local-struct=484`
  - `ssa-nomerge-smoke=1154`
  - `ssa-nomerge-parity=1126`
  - `pass-fuzz-stress=1117`
  - `binaryen-oracle-portable=1148`
  - `heap2local-ref=308`
  - `local-subtyping-straight-line=551`
  - `heap2local-array=295`
  - `coalesce-locals-structured=322`
  - `duplicate-import-elimination-nonfunction=274`
  - `coalesce-locals-loop-copy-through=332`
- DIE profile case labels:
  - `duplicate-import-elimination:functions=800`
  - `duplicate-import-elimination:nonfunction-negative=274`

Agent classification: behavior-parity match for the random all-profiles lane, including `1074` sampled DIE-profile cases.

## Final direct-pass closeout assessment

The source-confirmed Binaryen contract was refreshed against local `wasm-opt version 130` and byte-identical official `version_130` / current `main` `DuplicateImportElimination.cpp`. The direct Starshine pass now matches that function-import-only, current-representative contract with no unclassified semantic or validation mismatches across the required four-lane matrix. The only observed raw output drift was the wasm-smith unreachable-control-debris case above, classified as semantic-safe and unrelated to DIE's import rewrite contract.

`[O4Z-AUDIT-DIE]` is closed for direct `--pass duplicate-import-elimination` behavior parity and the user-requested 1x direct pass-local timing target. Remaining future work is ordinary late-tail preset/neighborhood proof or future-upstream drift if Binaryen widens DIE beyond function imports.

## Timing fixtures

Generated under `.tmp/die-timing/` from Python/WAT, then parsed with `wasm-tools parse` and validated with `wasm-tools validate --features all`.

Fixtures:

- `.tmp/die-timing/die-import-heavy-2000i-128u.wasm`
  - `2002` imports: one different-signature reset function import, `2000` duplicate void function imports, and one unique void function import.
  - `128` call users plus periodic `ref.func` users, export/start/element users.
  - wasm size: `51194` bytes.
- `.tmp/die-timing/die-user-heavy-800i-4000u.wasm`
  - `802` imports: one different-signature reset function import, `800` duplicate void function imports, and one unique void function import.
  - `4000` call users plus periodic `ref.func` users, export/start/element users.
  - wasm size: `32117` bytes.

Measurement method:

- Starshine: `_build/native/release/build/cmd/cmd.exe --tracing pass --duplicate-import-elimination <fixture> -o /tmp/die-star-out.wasm`; parse `perf:timer name=pass:duplicate-import-elimination elapsed_us=...`.
- Binaryen: `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --duplicate-import-elimination <fixture> -o /tmp/die-bin-out.wasm`; parse `[PassRunner] running pass: duplicate-import-elimination... <seconds> seconds.`
- Repeats: `35` per fixture with first `5` warmups discarded.
- Summary written to `.tmp/die-timing/die-timing-summary-20260706.json`.

Timing results:

| Fixture | Starshine median | Binaryen median | Ratio |
| --- | ---: | ---: | ---: |
| `die-import-heavy-2000i-128u.wasm` | `0.447 ms` | `2.00646 ms` | `0.223x` |
| `die-user-heavy-800i-4000u.wasm` | `0.2835 ms` | `0.946297 ms` | `0.300x` |

This satisfies the user-requested direct pass-local target on these fixtures (`Starshine median <= Binaryen median`). Together with the completed fuzz matrix above, this closes the direct DIE performance criterion; reopen if these fixtures regress or a more representative direct DIE workload exposes a slower pass-local owner.

## Reopening criteria

Reopen DIE profile/timing work if:

- current Binaryen widens DIE beyond function imports;
- the dedicated profile stops generating both function duplicate and nonfunction negative cases;
- any dedicated profile compare lane develops raw mismatches, validation failures, property failures, generator failures, or command failures;
- any required closeout matrix lane develops unclassified semantic drift, Starshine validation failures, property failures, generator failures, or Starshine command failures;
- Starshine pass-local median on the two established `.tmp/die-timing/` fixtures regresses above Binaryen median under the same measurement method;
- a more representative direct DIE workload demonstrates a slower pass-local owner than the synthetic fixtures cover.
