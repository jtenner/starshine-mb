# DAEO payoff local-order final matrix

Date: 2026-07-14

## Scope

This note closes the bounded payoff-chain local-order iteration from notes `1600` and `1601`. It does not close the overall DAEO audit. The retained optimizing-only behavior improves the direct artifact without a size tradeoff, the single-scan refinement preserves output while removing duplicate traversal, plain `dead-argument-elimination` remains separate, and every remaining positive direct byte stays an open parity gap.

## Retained behavior

After the existing generic dropped-result payoff selector completes its bounded wrapper/callee transactions and `simplify-locals` / `vacuum` cleanup, DAEO applies the existing type-stable local rewrite to exactly the selected terminal callees. Parameters stay fixed; unused body locals are removed; referenced locals move only within their existing contiguous type runs; compact local declaration runs and optional name remaps are rebuilt transactionally.

The shared local-order scan now validates indexes while collecting access counts and first-use ranks, rather than walking each selected body once for validation and again for counts. Its fail-closed behavior is unchanged. The payoff trace reports `ordered_defs=<count>`; the focused one-chain fixture requires `ordered_defs=1`, and the current artifact reports `ordered_defs=2`.

No artifact function index is hardcoded. Plain DAE does not enter this optimizing-only lane.

## Rejected Func 7007..7010 reachability probes

The leading Func `7008` family is a forwarded-parameter cycle:

- `7008 -> 7007`;
- `7007` and `7009 -> 7010`;
- `7010 -> 7008`.

Binaryen removes a forwarded `i32` parameter across the cycle and also removes two nullable-reference parameters from Func `7009`. Two temporary generic direct-callee reachability closures were rejected and reverted:

- a `128`-definition closure missed the target transaction, performed unrelated removals, and worsened output by `+629` raw / `+598` canonical bytes;
- a depth-eight `793`-definition closure still missed the cycle transaction, worsened output by `+899` raw / `+804` canonical bytes, and raised DAEO time to about `17.57s`.

Reachability alone is therefore not a safe ownership proof. The next cycle slice needs parameter-position dependency evidence and an all-or-nothing SCC transaction that rejects escapes, tail calls, writes, unowned callers, and unclassified entry uses.

## Fresh explicit native binary

Built after both retained behavior commits:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 b27d010fcd0e98034e3f1c4adef4592028c06508823f2818dc0240dd7a12b142
```

Every authoritative compare lane used Binaryen v130 through `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, `--jobs auto`, the explicit native Starshine binary, and both DAE normalizers:

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
.tmp/daeo-payoff-order-final-20260714/starshine-direct.wasm
SHA-256 612396c41a4146c0888c9c661a6ef63959889138759236e12398f9b0edcbbe30
```

A second independent invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1599 | payoff-order final | Binaryen | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197484` | `3197420` | `3177421` | `+19999` |
| canonical wasm | `3274937` | `3274877` | `3262456` | `+12421` |
| DAEO pass-local | `12448.452ms` | `13234.748ms` | `8538.02ms` fresh debug | `1.55x` |
| Func `8429` canonical body | `27220` | `27190` | `25742` | `+1448` |
| Func `9347` canonical body | `16715` | `16685` | `15404` | `+1281` |

The iteration closes `64` raw and `60` canonical bytes, split evenly as `-30` canonical bytes in each of Funcs `8429` and `9347`. The controlled parent/child replay in note `1601` is timing-neutral, so no single-scan speedup is claimed. The final pass remains within the required `<=2x` Binaryen bound; it is also below `2x` the retained historical `8083.49ms` Binaryen baseline.

Current leading canonical body deltas are Func `7008 +1781`, Func `7007 +1470`, Func `8429 +1448`, Func `41 +1286`, and Func `9347 +1281`. These are open parity gaps, not accepted representation differences or Starshine wins.

## Required compare matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-payoff-order-final-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-payoff-order-final-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-payoff-order-final-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-payoff-order-final-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`;
- mismatch reduction disabled.

The failure-directory names and all `2936` semantic `.wasm` / `.wat` artifacts are byte-identical to the prior complete measured set. Agent classification therefore remains the established source-backed, measured Starshine cleanup wins, not a harness claim: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first current dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` using the same explicit native binary. Each mode:

- emits a valid `38`-byte module;
- contains exactly one DAEO start and one matching done;
- runs DAEO immediately before `inlining-optimizing` in the locked late slot.

Measured DAEO pass-local timers were `668us` for optimize, `777us` for shrink, and `540us` for O4z.

The large stripped-artifact whole-command blockers remain outside DAEO and before its slot: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`. They remain owned by `[WALL]001` and are not attributed to this iteration.

## Validation

Green final validation:

- `moon info`;
- `moon fmt`;
- focused `dae_optimizing_test.mbt`: `314/314`;
- full `moon test`: `8809/8809`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1783998375155000`;
- `.mbti` diff from iteration base `55a66e368`: empty;
- direct output validation, repeat hash comparison, docs/source/link review, and `git diff --check`.

`moon fmt` rewrote `moon.mod`; that unrelated formatting change was restored before the docs/signoff commit.

## Judgment and continuation

The payoff-chain type-stable local-order family is a measured direct Starshine size win relative to note `1599`, and the generated compare matrix remains fully classified. The single-scan refinement preserves the exact output and fail-closed behavior but is not claimed as a measured performance win.

The overall DAEO audit is not complete: `+12421` canonical bytes remain unclassified. The next recursive iteration should build a generic transactional forwarded-parameter SCC proof for Funcs `7007..7010`. It must rewrite the full parameter-position dependency component atomically, or retain nothing; if that proof cannot be made safely and generically, re-attribute the next leading owner rather than keeping reachability-based unrelated rewrites. Plain DAE separation, exact-once late public scheduling, valid output, the complete direct matrix, and the `<=2x` pass-local bound must remain intact.
