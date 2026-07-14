# DAEO adjacent-chain final matrix

Date: 2026-07-13

## Scope

This note closes the bounded adjacent-constructor-chain iteration started in notes `1591` and `1592`. It does not classify the remaining direct artifact delta as acceptable. The retained behavior is optimizing-only, keeps plain `dead-argument-elimination` unchanged, preserves the exact late public schedule, and advances the current direct artifact with a measured size win inside the pass-local `<=2x` target.

## Retained implementation

For broad modules with more than `8192` defined functions, DAEO now:

1. finds adjacent same-signature caller/callee pairs in the bounded defined-function range `4097..8199`;
2. requires at least `128` locals in both functions and a direct second-to-first call edge;
3. checks only the preceding eight definitions for a productive broad exact-literal root;
4. ranks successful roots by aggregate-constructor count and the pair by dropped-result cleanup payoff;
5. rewrites the selected root once, then applies only `simplify-locals` and `vacuum` to the selected pair.

No retained selector contains the artifact function indexes. The current artifact reports `roots=2 pairs=1`, selects `root_def=7003`, and cleans definitions `[7007, 7008]` with payoff `4686`. A red-first `8193`-function regression locks root rewriting, pair cleanup, candidate counts, trace selection, validation, and plain-DAE separation.

## Fresh explicit native binary

Built after the behavior commits:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 9852421b3bd3d1d99ba0ffc790c2697a42af16558c4bb3b08e9d1f93d17a5516
```

All direct compare lanes below used that explicit binary and both required normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-adjacent-final-20260713/starshine-direct.wasm
SHA-256 5f799dd0bd6c347041c33147f8c2230c19ed8a384cad5c0d1f0f67c6c6cbdf05
```

A second independent direct invocation is byte-identical. The output validates with `wasm-tools validate --features all`.

| dimension | note 1590 | adjacent final | Binaryen | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3198681` | `3198310` | `3177421` | `+20889` |
| canonical wasm | `3276084` | `3275701` | `3262456` | `+13245` |
| DAEO pass-local | `9350.478ms` | `11088.465ms` | `8083.49ms` | `1.37x` |

The new family closes `371` raw and `383` canonical bytes. The retained endpoint is slower than note `1590` because it performs the additional exact-parameter transaction and pair cleanup, but it remains under the repository `<=2x` pass-local target. Compared with the first retained adjacent-selector implementation in note `1591`, note `1592`'s pair-first prefilter preserves output and reduces selector cost by `13.9%` on its controlled replay.

Current leading canonical body deltas remain Func `41 +1960`, Func `7008 +1811`, Func `7007 +1530`, Func `8429 +1478`, and Func `9347 +1310`. The `[7007,7008]` family is smaller but not byte-parity; Func `41` is again the largest direct body owner. These are open parity gaps, not accepted representation differences or Starshine wins.

## Required compare matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-adjacent-final-dedicated-10000-20260713
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected `dae-optimizing=10000`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-adjacent-final-regular-100000-20260713
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-adjacent-final-wasm-smith-10000-20260713
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache hits/misses `10000/0`;
- Binaryen success hits/misses `9956/0`, failure hits/misses `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-adjacent-final-random-all-10000-20260713
```

Run with `--no-reduce-mismatches`:

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`;
- failure-directory names and all `2569` current semantic artifact files are byte-identical to note `1590`'s preceding complete lane.

Agent classification therefore remains the previously measured/source-backed Starshine cleanup wins, not a harness claim: `coverage-forced-portable=243` and `dae-effectful-args=124`, with aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first dedicated-profile generated input was replayed through public `--optimize`, public `--shrink`, and `-O4z` using the same explicit native binary. Each mode:

- emits a valid `38`-byte module;
- contains exactly one `pass[dae-optimizing]:start` and one matching `done`;
- runs DAEO immediately before `inlining-optimizing` in the locked late neighborhood.

Measured DAEO timers were:

| mode | DAEO pass-local |
|---|---:|
| optimize | `659us` |
| shrink | `618us` |
| `-O4z` | `526us` |

The large stripped-artifact whole-command blockers remain outside DAEO and before its slot: optimize is blocked in `vacuum`; shrink and O4z are blocked in early `ssa-nomerge`. This iteration changes neither owner.

## Validation

Green final validation:

- `moon info`;
- `moon fmt`;
- focused `dae_optimizing_test.mbt`: `313/313`;
- full `moon test`: `8808/8808`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc`, seed `1783998375155000`;
- `.mbti` diff from iteration base `0f3af6350`: empty;
- `git diff --check`.

An earlier full-gate attempt exposed a seed-dependent pre-existing `validate-valid-metamorphic` generator failure: `add-duplicate-equivalent-imported-memory64 produced invalid module: type mismatch`. A native replay reported the same generator-owned failure. It is not attributed to DAEO; the final full gate above completed green after registry refresh.

## Judgment and next owner

The adjacent chain is a measured Starshine size win relative to the prior Starshine endpoint, while the generated compare matrix remains classified and green under the established DAEO policy. It is not direct Binaryen parity: `+13245` canonical bytes remain, and no evidence justifies accepting them.

The next recursive DAEO iteration should begin from Func `41`, then remeasure the partially closed `[7007,7008]` family. It must keep the same constraints: no artifact-index hardcoding in retained selectors, no plain-DAE scheduling, direct Binaryen parity or a measured/documented Starshine win, fresh explicit-native four-lane evidence after behavior changes, and no widening that exceeds `2x` Binaryen pass-local time.
