# DAEO dead-callee convergence final matrix

Date: 2026-07-14

## Scope

This note closes the bounded dead-callee sink iteration from note `1605`. The retained optimizing-only lane removes unread parameters from exact caller-parameter callees adjacent to the already selected forwarded-cycle neighborhood, refreshes current facts in bounded rounds, and retries unread cycle members. Plain `dead-argument-elimination` does not schedule the lane or any optimizing cleanup.

The direct artifact improves, but the forwarding-only component through defined Func `7024` remains an open parity gap. This note does not claim DAEO completion.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 c49f0a3d9ceafa5d8f839d9cad88ec6187a5a999e97fd53ecd9db1300c22270a
```

All authoritative compare lanes used Binaryen v130 through `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, `--jobs auto`, the explicit native binary, and:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally used `--no-reduce-mismatches --max-failures 10000`.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-computed-carrier-20260714/retained/starshine-direct.wasm
SHA-256 0e18885eaa3d8ca1d5f665911d76570805f772055c0996d37c9087ab812547ae
```

A second invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1604 | dead-callee final | Binaryen v130 | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197404` | `3197391` | `3177421` | `+19970` |
| canonical wasm | `3274861` | `3274829` | `3262456` | `+12373` |
| DAEO pass-local | `13702.810ms` | `14299.444ms` | `8538.02ms` | `1.67x` |

The retained trace is:

```text
pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[7007, 7008, 7010]
pass[dae-optimizing]:forwarded-param-dead-callee-convergence sink_defs=[7014, 7033] cycle_defs=[]
```

Agent judgment: the two sink removals are Binaryen-source-backed dead-parameter parity progress and a measured Starshine size win over the previous endpoint (`-13` raw / `-32` canonical). They do not close the target component. Defined Func `7024` still forwards the candidate `i32` parameter into defined Func `7008`; the remaining Func `7007` / `7008` / `7010` neighborhood also has the computed local injection. The next implementation needs a transactional forwarding-only parameter-component proof where every semantic use is another removable parameter edge. It must preserve arbitrary incoming producer effects rather than proving those values constant.

## Required direct matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-dead-callee-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `dae-optimizing=10000`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-dead-callee-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `binaryen-oracle-portable=100000`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-dead-callee-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache hits/misses `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-dead-callee-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- mismatch reduction disabled;
- Binaryen cache hits/misses `10000/0`.

The failure-directory names and all `2936` semantic `.wasm` / `.wat` artifacts are byte-identical to note `1604`. Agent classification therefore remains the established measured/source-backed Starshine cleanup wins: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first current dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` with the same explicit native binary. Each mode emits a valid `38`-byte module, contains exactly one DAEO start/done pair, and places DAEO immediately before `inlining-optimizing`.

Measured DAEO timers:

- optimize: `647us`;
- shrink: `612us`;
- O4z: `534us`.

The large stripped-artifact pre-slot blockers remain owned by `[WALL]001`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`.

## Validation

Green final validation:

- `moon info`;
- `moon fmt` with unrelated `moon.mod` formatting restored;
- focused `dae_optimizing_test.mbt`: `320/320`;
- full `moon test`: `8815/8815`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1784056348332000`;
- `.mbti` diff from iteration base `b060df730`: empty;
- direct output validation, repeat hash comparison, four-lane explicit-native matrix, scheduling checks, docs/source/link review, and `git diff --check`.

## Judgment and continuation

The dead-callee sink lane is retained as safe Binaryen-shaped progress with a measured direct size win. DAEO remains active: the direct canonical gap is `+12373`, and the unclosed owner is now a forwarding-only parameter dependency component through defined Func `7024`, not a missing computed-value constant proof.

Next slice: derive a generic component where each candidate parameter is read-only and every get is an exact operand of another candidate parameter; require complete use/call coverage, private non-tail boundaries, and transactional callsite/body/local-map/signature application. Arbitrary incoming computed values are allowed only because the component proves they are never semantically observed; their producers and effects must remain ordered.
