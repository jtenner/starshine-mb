# DAEO two-chain final matrix

Date: 2026-07-13

## Scope

This note refreshes direct, scheduled, performance, and repository validation evidence after notes `1588` and `1589` retained two behavior changes:

1. one DAEO invocation can complete at most two payoff-ranked broad dropped-result wrapper/callee transactions, refreshing facts between them and cleaning at most two completed callees;
2. the low exact-parameter cleanup set follows all productive convergence definitions instead of stopping at the prefix pair.

Plain `dead-argument-elimination` remains free of both optimizing-only schedulers.

Fresh explicit native binary used by every compare lane:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `62a3c7a118d2119c085a3e2d7cb95bb93c23d772c788028a55dcd7fce4794455`.

Every generated lane used:

```text
--normalize drop-consts --normalize unreachable-control-debris
--jobs auto
--starshine-bin _build/native/release/build/cmd/cmd.exe
```

The random-all lane also used `--no-reduce-mismatches`, which changes only failure reduction/artifact work and is the documented way to complete mismatch-counting lanes with already classified residual families.

## Direct artifact endpoint

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Retained output: `.tmp/daeo-low-chain-cleanup-20260713/starshine-direct.wasm`.

- SHA-256 `465d68ec3c822f7bf3f4d536506479cdd0e8cbf60cede646f25a3e23eea74888`;
- repeat output is byte-identical;
- validates with `wasm-tools validate --features all`;
- raw size `3198681`;
- canonical size `3276084` versus Binaryen `3262456`, leaving `+13628`;
- pass-local `9350.478ms` versus Binaryen `8083.49ms`, or `1.16x`, within the repository `<=2x` target.

Current largest positive canonical body owners are:

1. Func `41`: `+1960`;
2. Func `7007`: `+1873`;
3. Func `7008`: `+1848`;
4. Func `8429`: `+1478`;
5. Func `9347`: `+1310`.

The result-chain behavior is closed for the two currently attributed broad chains, but the remaining direct artifact gap is still a parity gap. No remaining owner is classified as an accepted Starshine win.

## Required direct matrix

### Dedicated `dae-optimizing`

Output: `.tmp/pass-fuzz-daeo-converged-dedicated-10000-20260713`.

- seed `0x5eed`;
- profile `dae-optimizing`, selected `dae-optimizing=10000`;
- requested/compared `10000/10000`;
- normalized `10000`;
- cleanup-normalized `0`;
- mismatches/failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

Output: `.tmp/pass-fuzz-daeo-converged-regular-100000-20260713`.

- seed `0x5eed`;
- requested/compared `100000/100000`;
- normalized `100000`;
- cleanup-normalized `0`;
- mismatches/failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

Output: `.tmp/pass-fuzz-daeo-converged-wasm-smith-10000-20260713`.

- seed `0x5eed`;
- requested `10000`, compared `9956`;
- normalized `9955`;
- cleanup-normalized `1`;
- mismatches `0`;
- Starshine validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle classes: rec-group-zero `39`, invalid-tag-index `1`, table-index-out-of-range `1`, bad-section-size `3`;
- cache: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`.

### Random all-profiles

Output: `.tmp/pass-fuzz-daeo-converged-random-all-10000-20260713`.

- seed `0x5555`;
- profile `random-all-profiles`;
- requested/compared `10000/10000`;
- normalized `9633`;
- cleanup-normalized `0`;
- mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- `reduceMismatches=false`.

The failure-directory names exactly match `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-param-chain-20260713`, and the input, Starshine raw/canonical/WAT, and Binaryen raw/canonical/WAT artifacts are byte-identical in every one of the `367` directories. The current residual set is therefore still exactly:

- `coverage-forced-portable=243`;
- `dae-effectful-args=124`.

The source/diff/replay/size classification from note `1581` remains current: aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. Agent judgment: measured/source-backed Starshine cleanup wins, not harness-proved semantic safety. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals in the final direct matrix.

## Scheduled evidence

Using the final dedicated input under `.tmp/daeo-final-iteration-20260713/scheduled-dedicated/`, public `--optimize`, public `--shrink`, and `-O4z` each:

- execute DAEO exactly once;
- finish DAEO immediately before `inlining-optimizing`;
- emit a valid `38`-byte output.

Observed DAEO pass-local times were `1489us`, `696us`, and `655us` respectively. The order remains the locked late neighborhood.

Large scheduled status is unchanged because this iteration did not change the earlier owners:

- public optimize remains blocked before DAEO in direct/reproducible `vacuum`;
- public shrink remains blocked before DAEO in early `ssa-nomerge`;
- public O4z remains blocked before DAEO in early `ssa-nomerge`.

Dedicated exact-once evidence therefore remains green, but large-artifact scheduling completion is not claimed.

## Validation

- red-first two-chain regression failed before implementation and passed after;
- red-first converged-cleanup regression failed before implementation and passed after;
- `dae_optimizing_test.mbt` passed `312/312` after each behavior slice;
- `moon info` passed with existing warnings;
- `moon fmt` passed;
- full `moon test` passed `8807/8807`;
- native release build passed;
- `bun validate full --profile ci --target wasm-gc` passed, including full tests `8807/8807` and all CI-profile validation suites;
- `.mbti` diff from iteration base `43d265531..HEAD` is empty.

## Current closeout status

The required direct matrix is current and pass-local performance is within guidance. DAEO remains active because:

1. the direct artifact still has an unclassified `+13628` canonical gap, led by Func `41` and the paired Func `7007` / `7008` family;
2. large public optimize, shrink, and O4z still do not reach the already locked DAEO slot;
3. completion therefore still requires direct owner reduction/classification and bounded pre-slot `vacuum` / `ssa-nomerge` repairs with large-artifact evidence.
