# DAEO adjacent local-order final matrix

Date: 2026-07-14

## Scope

This note closes the bounded adjacent type-stable local-order iteration from notes `1597` and `1598`. It does not close the overall DAEO audit. The retained generic optimizing-only transform improves the direct artifact without a raw-size tradeoff, plain `dead-argument-elimination` remains unchanged, and the remaining positive direct bytes stay open parity gaps.

## Retained behavior

After the existing broad adjacent selector chooses a high-local same-signature caller/callee pair, DAEO applies its bounded `simplify-locals` / `vacuum` cleanup and then type-stable local ordering to exactly those two definitions. Referenced locals are frequency-ordered only within their existing contiguous type runs; unreferenced locals are dropped; parameters and compact local-declaration runs remain stable. The helper resolves the shared function type once, scans exactly two definitions, and allocates name remaps only when a name section exists.

No artifact function index is hardcoded. The current artifact still selects `root_def=7003`, definitions `[7007,7008]`, payoff `4686`, and reports `local_order=type-stable ordered_defs=2`.

The red-first `8193`-definition regression proves local compaction, observable value preservation across a call, validation, exact bounded selection, and plain-DAE separation.

## Fresh explicit native binary

Built after both behavior commits:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 2dc4e78b621484309c1d4469238605054365895e88734d28967f50bb800dcf98
```

Every authoritative compare lane used Binaryen v130 through:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

All lanes used `--jobs auto`, the explicit native binary, and both DAE normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all also used `--no-reduce-mismatches`.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-adjacent-order-final-20260714/starshine-direct.wasm
SHA-256 58523a1416ac35b6793ab1831fc8d8c827fa583cc02f4c8d712effe0a9263d02
```

A second independent invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1596 | adjacent-order final | Binaryen | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197559` | `3197484` | `3177421` | `+20063` |
| canonical wasm | `3275027` | `3274937` | `3262456` | `+12481` |
| DAEO pass-local | `12763.150ms` | `12448.452ms` | `8083.49ms` | `1.54x` |
| Func `7008` canonical body | `6143` | `6113` | `4332` | `+1781` |
| Func `7007` canonical body | `5414` | `5354` | `3884` | `+1470` |

The iteration closes `75` raw and `90` canonical bytes, all of the canonical movement in Funcs `7007` and `7008`. Note `1598`'s controlled triplicate comparison also shows the exact-definition prefilter preserving output while improving the parent median from `12702.219ms` to `12658.665ms`.

Current leading canonical body deltas are Func `7008 +1781`, Func `8429 +1478`, Func `7007 +1470`, Func `9347 +1310`, and Func `41 +1286`. These are open parity gaps, not accepted representation differences or Starshine wins.

## Required compare matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-adjacent-order-final-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected `dae-optimizing=10000`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-adjacent-order-final-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected `binaryen-oracle-portable=100000`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-adjacent-order-final-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-adjacent-order-final-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`;
- mismatch reduction disabled;
- selected subprofiles: `coalesce-locals-structured=293`, `dae-convergence=133`, `ssa-nomerge-smoke=965`, `dae-unused-params=126`, `coalesce-locals-loop-copy-through=300`, `binaryen-oracle-portable=964`, `coverage-forced-portable=1017`, `ssa-nomerge-parity=945`, `dae-unused-returns=117`, `heap2local-struct=422`, `duplicate-import-elimination-nonfunction=517`, `pass-fuzz-stress=999`, `local-subtyping-unreachable-tail=337`, `heap2local-ref=299`, `dae-return-type-refinement=146`, `dae-tail-call-boundary=118`, `duplicate-import-elimination-functions=546`, `local-subtyping-straight-line=344`, `local-subtyping-structured=339`, `heap2local-array=304`, `dae-constant-args=244`, `coalesce-locals-straight-line=401`, `dae-effectful-args=124`.

The failure-directory names and all `2936` `.wasm`/`.wat` semantic artifacts are byte-identical to note `1596`'s complete lane. Agent classification therefore remains the established measured/source-backed Starshine cleanup wins, not a harness claim: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first current dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` using the same explicit native binary. Each mode:

- emits a valid `38`-byte module;
- contains exactly one DAEO start and one matching done;
- runs DAEO immediately before `inlining-optimizing` in the locked late slot.

Measured DAEO pass-local timers were `670us` for optimize, `670us` for shrink, and `574us` for O4z.

The large stripped-artifact whole-command blockers remain outside DAEO and before its slot: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`. They remain owned by `[WALL]001` and are not attributed to this iteration.

## Validation

Green final validation:

- `moon info`;
- `moon fmt`;
- focused `dae_optimizing_test.mbt`: `314/314`;
- full `moon test`: `8809/8809`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1783998375155000`;
- `.mbti` diff from iteration base `552850c0a`: empty;
- `git diff --check`.

Two initial full-gate attempts reported transient nonzero Moon subcommands (`moon info`, then `moon check --target wasm-gc`); both commands passed immediately when replayed directly, and the final redirected full-gate run completed every suite green with the pinned seed. No DAEO or test failure is hidden.

## Judgment and continuation

The adjacent type-stable local-order family is a measured direct Starshine size win relative to note `1596`, and the generated compare matrix remains fully classified. It is not direct Binaryen parity: `+12481` canonical bytes remain, led by Func `7008`, Func `8429`, Func `7007`, Func `9347`, and Func `41`.

The next recursive iteration should re-attribute Func `7008` beyond local ordering, including the remaining parameter/control shape across the nearby `7007..7010` call cycle, or move to Func `8429` if a generic bounded cycle transform cannot be proven safely. Any retained difference must reach Binaryen shape or be a measured/documented Starshine win; plain DAE and exact-once scheduling must remain unchanged, and pass-local time must stay within `<=2x` Binaryen.
