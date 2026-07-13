# DAEO post-payoff matrix and scheduled refresh

Date: 2026-07-13

## Scope

This slice refreshes closeout evidence after the retained payoff-ranked `12293 -> 8429` result-chain behavior from note `1586`. It completes three required direct lanes, records the concrete random-all runtime blocker, refreshes exact-once dedicated scheduling, attributes large public shrink, and runs the repository release gate. No optimizer behavior changes in this slice.

Fresh explicit native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`.

All generated DAE/DAEO lanes used:

```text
--normalize drop-consts --normalize unreachable-control-debris
--jobs auto
--starshine-bin _build/native/release/build/cmd/cmd.exe
```

## Completed direct lanes

### Dedicated `dae-optimizing`

Output: `.tmp/pass-fuzz-daeo-payoff-dedicated-10000-20260713`.

- requested/compared `10000/10000`;
- normalized `10000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `dae-optimizing=10000`;
- Binaryen cache `10000/0`.

### Regular GenValid

Output: `.tmp/pass-fuzz-daeo-payoff-regular-100000-20260713`.

- requested/compared `100000/100000`;
- normalized `100000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

Output: `.tmp/pass-fuzz-daeo-payoff-wasm-smith-10000-20260713`.

- requested `10000`, compared `9956`;
- normalized `9955`;
- cleanup-normalized `1`;
- mismatches `0`;
- Starshine validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle classes: rec-group-zero `39`, invalid-tag-index `1`, table-index-out-of-range `1`, bad-section-size `3`;
- cache: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`.

Agent judgment: these three lanes contain no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Random-all blocker

The required command targeted `.tmp/pass-fuzz-daeo-payoff-random-all-10000-20260713` with `10000`, seed `0x5555`, and profile `random-all-profiles`. It timed out after `1800s` without `result.json`.

The partial manifest contains `307` completed records:

- normalized matches `295`;
- raw mismatches `12`;
- mismatch profiles: `coverage-forced-portable=9`, `dae-effectful-args=3`;
- no partial command/validation/generator/property failure was recorded;
- every file in all `12` partial failure directories is byte-identical to the same case in the prior complete post-param-chain lane.

Agent judgment: the observed partial residuals are unchanged members of the previously measured/source-backed cleanup-win families, not new harness-proved facts. However, a `307/10000` partial run is not closeout evidence. The four-lane matrix remains incomplete and DAEO stays active.

The timeout is primarily harness normalization/artifact work rather than direct Starshine execution: direct current DAEO on sampled coverage-forced case `281` completed in `0.005s`. A continuation should either let the required lane finish with a sufficiently long budget or add a semantics-preserving harness reuse/resume path; it must not replace the required full lane with the partial classification.

## Scheduled evidence

Using dedicated input `gen-valid-000001.wasm`, public `--optimize`, public `--shrink`, and `-O4z` each:

- execute `dae-optimizing` exactly once;
- place it after the late `heap-store-optimization` event and immediately before `inlining-optimizing`;
- emit a valid `38`-byte output.

Artifacts and traces are under `.tmp/daeo-payoff-20260713/scheduled-dedicated/`.

Large public shrink is now directly attributed. A fresh traced `--shrink` run on the `3204405`-byte stripped artifact timed out after `300s`, produced `3679` lines / `539734` bytes, never reached DAEO, and was still in early `ssa-nomerge` at absolute Func `1780`. This matches the large O4z owner family from note `1584`, while public optimize remains separately blocked in vacuum.

Current scheduled owner split:

- public optimize: direct/reproducible `vacuum` blocker;
- public shrink: early `ssa-nomerge` blocker;
- public O4z: early `ssa-nomerge` blocker.

## Validation

- `moon info` passed with existing warnings.
- `moon fmt` passed.
- full `moon test` passed `8806/8806`.
- native release build passed; final hash is above.
- `bun validate full --profile ci --target wasm-gc` passed when output was redirected to files, including full tests `8806/8806` and all CI-profile validation suites. Two earlier interactive invocations exited nonzero while their warning-heavy output was truncated; the redirected rerun is the authoritative complete result.
- `.mbti` diff from iteration base `9d962bbd3..HEAD` is empty.

## Remaining closeout blockers

1. Complete the required `10000` random-all lane after the retained behavior change.
2. Attribute and reduce the new largest direct canonical body owner, defined Func `9347`; the module remains `+14846` canonical bytes versus Binaryen.
3. Repair or bound the pre-DAEO scheduled owners so large optimize, shrink, and O4z reach the already locked DAEO slot.
4. Rerun final direct/scheduled performance and release evidence after any further retained behavior change.
