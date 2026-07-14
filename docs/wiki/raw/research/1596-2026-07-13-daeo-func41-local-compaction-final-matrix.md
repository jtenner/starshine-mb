# DAEO Func 41 local-compaction final matrix

Date: 2026-07-13

## Scope

This note closes the bounded Func `41` removed-parameter local-compaction iteration from notes `1594` and `1595`. It does not classify the remaining direct artifact delta as acceptable. Plain `dead-argument-elimination` remains free of optimizing-only cleanup, public scheduling remains unchanged, and the retained direct difference is a measured size improvement relative to note `1593` while the remaining positive bytes stay open parity gaps.

## Retained implementation

On modules with more than `4096` defined functions, DAEO inspects only definitions already touched by the boundary core. A candidate must have at least `128` locals, have fewer parameters than the original definition, and expose at least `16` removable unreferenced locals. The selector ranks by removed-local count and then definition index, rewriting only the best candidate.

The implementation first attempts direct current-reference compaction and enters the existing exact lowered-cleanup fallback only when direct compaction is insufficient. The current artifact selects definition `41`, removes `168` locals, and reports `mode=fallback`. No retained selector hardcodes the artifact function index.

A red-first `4097`-definition regression locks optimizing-only selection, direct-mode prefiltering, local-count reduction, trace identity, validation, and plain-DAE separation.

## Fresh explicit native binary

Built after both behavior commits:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 648217241b157b7144a7e2d1b023688f5a78b52f8d0d7fec5358c28394bc08ac
```

Every authoritative compare lane used Binaryen v130 via `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, the explicit native Starshine binary, `--jobs auto`, and both required normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

The first accidentally unpinned wasm-smith/random-all attempts resolved PATH Binaryen v116 and are non-authoritative; the v130 reruns below supersede them.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-f41-final-20260713/starshine-direct.wasm
SHA-256 b592b4f13de2826798149ddd4e6a9701ddb0af26ee6161d901359d6762de1059
```

A second independent invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1593 | Func-41 final | Binaryen | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3198310` | `3197559` | `3177421` | `+20138` |
| canonical wasm | `3275701` | `3275027` | `3262456` | `+12571` |
| DAEO pass-local | `11088.465ms` | `12763.150ms` | `8083.49ms` | `1.58x` |
| Func `41` canonical body | `7377` | `6703` | `5417` | `+1286` |

The iteration closes `751` raw and `674` canonical bytes, all of the canonical movement in Func `41`. The direct prefilter preserves output and improved the controlled note `1594` replay from `13662.779ms` to `12704.043ms`; the final replay remains inside the required `<=2x` Binaryen target.

Current leading canonical body deltas are Func `7008 +1811`, Func `7007 +1530`, Func `8429 +1478`, Func `9347 +1310`, and Func `41 +1286`. These are open parity gaps, not accepted representation differences or Starshine wins.

## Required compare matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-f41-final-v130-dedicated-10000-20260713
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected `dae-optimizing=10000`;
- Binaryen cache hits/misses `9984/16`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-f41-final-v130-regular-100000-20260713
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `314/99686`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-f41-final-v130-wasm-smith-10000-20260713
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache `10000/0`, Binaryen success cache `106/9850`, Binaryen failure cache `0/44`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-f41-final-v130-random-all-10000-20260713
```

Run with `--no-reduce-mismatches`:

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `5324/4676`;
- failure-directory names and all `2936` current `.wasm`/`.wat` semantic artifact files are byte-identical to note `1593`'s preceding complete lane.

Agent classification therefore remains the established measured/source-backed Starshine cleanup wins, not a harness claim: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` using the same explicit native binary. Each mode:

- emits a valid `38`-byte module;
- contains exactly one DAEO start and one matching done;
- runs DAEO immediately before `inlining-optimizing` in the locked late slot.

Measured DAEO pass-local timers were `653us` for optimize, `658us` for shrink, and `624us` for O4z. Bare `-O4z` only sets optimization/shrink levels and does not itself request the public preset; the authoritative public O4z replay therefore uses `--optimize -O4z`, matching the existing preset contract.

The large stripped-artifact whole-command blockers remain outside DAEO and before its slot: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`. They remain owned by `[WALL]001` and are not attributed to this iteration.

## Validation

Green final validation:

- `moon info`;
- `moon fmt`;
- focused `dae_optimizing_test.mbt`: `314/314`;
- full `moon test`: `8809/8809`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1783998375155000`;
- `.mbti` diff from iteration base `9c3a69ea1`: empty;
- `git diff --check`.

An unseeded full-gate attempt reached the fuzz stage after `8809/8809` tests and aborted in the known seed-dependent generator/metamorphic surface. The pinned seed above completed every suite green; no DAEO failure is hidden.

## Judgment and continuation

The Func `41` family is a measured direct Starshine size win relative to note `1593`, and the generated compare matrix remains fully classified. It is not direct Binaryen parity: `+12571` canonical bytes remain, led now by the partially closed adjacent `[7007,7008]` family at `+3341` aggregate canonical body bytes.

The next recursive iteration should begin by re-attributing current Funcs `7008` and `7007`, especially the remaining local/control shape after the existing adjacent cleanup. Any retained widening must stay generic, validate, improve direct raw/canonical size or reach Binaryen shape, preserve plain DAE and exact-once scheduling, and remain within `<=2x` Binaryen pass-local time.
