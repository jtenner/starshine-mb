# DAEO forwarded-cycle final matrix

Date: 2026-07-14

## Scope

This note closes the bounded forwarded-parameter-cycle iteration from note `1603`. The generic constant-anchored transaction and exact-cycle precompute remain optimizing-only; plain DAE is unchanged. The retained cycle precompute is a measured direct size win, but the artifact's computed-local `i32` signature family remains an open parity gap.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 a8c076d2234c156db85362e69a0d0e4006a98c43dc2c349ddf9f34450ad7c7be
```

All authoritative compare lanes used Binaryen v130 through `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, `--jobs auto`, the explicit native binary, and:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all also used `--no-reduce-mismatches --max-failures 10000`.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-forwarded-cycle-final-20260714/starshine-direct.wasm
SHA-256 3faeb630bd90e49fbeef9f3c849543f2c5840b1fe9739d97355a24f5363e1bc8
```

A second invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1602 | forwarded-cycle final | Binaryen v130 | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197420` | `3197404` | `3177421` | `+19983` |
| canonical wasm | `3274877` | `3274861` | `3262456` | `+12405` |
| DAEO pass-local | `13234.748ms` | `13702.810ms` | `8538.02ms` | `1.60x` |

The artifact trace reports only the exact discovered cleanup component:

```text
pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[7007, 7008, 7010]
```

No artifact function index is hardcoded. The retained change closes `16` raw and `16` canonical bytes and remains within the required `<=2x` Binaryen pass-local bound.

The constant-anchored SCC transaction does not fire on this artifact. Func `7007` still supplies Func `7010`'s removable `i32` position through computed call-result body locals, not through a materializable literal, immutable global, or exact parameter `local.get`. The transaction correctly rejects that partial proof. The remaining `+12405` canonical bytes are parity gaps, not accepted representation drift.

## Required direct matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-forwarded-cycle-final-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `dae-optimizing=10000`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-forwarded-cycle-final-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `binaryen-oracle-portable=100000`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-forwarded-cycle-final-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache hits/misses `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-forwarded-cycle-final-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- mismatch reduction disabled;
- Binaryen cache hits/misses `10000/0`.

The failure-directory names and all `2936` semantic `.wasm` / `.wat` artifacts are byte-identical to note `1602`. Agent classification therefore remains the established source-backed, measured Starshine cleanup wins: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first current dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` with the same explicit native binary. Each mode emits a valid `38`-byte module, contains exactly one DAEO start/done pair, and places DAEO immediately before `inlining-optimizing`.

Measured DAEO timers:

- optimize: `697us`;
- shrink: `629us`;
- O4z: `541us`.

The large stripped-artifact pre-slot blockers remain owned by `[WALL]001`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`.

## Validation

Green final validation:

- `moon info`;
- `moon fmt` with unrelated `moon.mod` formatting restored;
- focused `dae_optimizing_test.mbt`: `319/319`;
- full `moon test`: `8814/8814`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1784056348332000`;
- `.mbti` diff from iteration base `7e4b0257063a8007b9c1c4b4dae60b3f21f86319`: empty;
- direct output validation, repeat hash comparison, four-lane explicit-native matrix, scheduling checks, docs/source/link review, and `git diff --check`.

## Judgment and continuation

The exact-cycle precompute is retained as a measured direct Starshine size win. The all-or-nothing transaction is retained as reusable, focused behavior with explicit negative guards, but it has not yet closed the artifact family.

The DAEO audit remains active. The next slice should identify the specific Binaryen optimizing-after-inlining cleanup or value analysis that exposes the computed Func `7007 -> 7010` `i32` actuals as zero, then encode an equivalent generic proof. It must not assume arbitrary computed recursive values equal the external anchor, select unrelated reachable definitions, widen plain DAE, or disturb exact-once late public scheduling.
