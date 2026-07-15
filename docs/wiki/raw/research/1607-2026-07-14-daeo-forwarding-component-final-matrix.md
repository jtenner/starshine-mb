# DAEO forwarding-only parameter component final matrix

Date: 2026-07-14

## Scope

This note closes the bounded forwarding-only parameter-component slice recommended by notes `1605` and `1606`. The retained optimizing-only lane starts from the exact forwarded-cycle neighborhood, proves that every read of each selected parameter is only an exact direct-call operand into another selected parameter or a closed unread sink, expands through rewriteable caller-parameter predecessors, and removes every selected call operand, callee parameter, local index, and function-signature slot transactionally.

Plain `dead-argument-elimination` does not schedule this lane. Public `optimize`, `shrink`, and `--optimize -O4z` retain the exact-once late DAEO slot immediately before `inlining-optimizing`.

This slice closes the previously identified Func `7007` / `7008` / `7010` / `7024` forwarding component. It does not close the full direct artifact gap.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 cb9a2832171faa49b8bf654981a4f4cf1808c9425085328909299d52a8642005
```

All authoritative compare lanes used Binaryen v130 through `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, `--jobs auto`, the explicit native binary, and:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally used `--no-reduce-mismatches --max-failures 10000`.

## Retained behavior

The component proof is generic and does not hardcode artifact function indexes. Its safety boundary requires:

- private, non-escaped defined functions with direct-call coverage and no tail-call boundary;
- read-only selected parameters;
- complete recursive local-get counts;
- every selected get to survive a bounded stack-effect walk as an exact operand of another direct-call parameter;
- either a real selected forwarding cycle or a closed unread sink, with at least two definitions from the previously proved cycle neighborhood;
- rewrite preflight before optional caller-parameter predecessor expansion;
- exact call-count coverage and all-or-nothing callsite, body, local-map, and signature application;
- preservation of arbitrary incoming producers through the existing effect-aware operand localization path.

The shared exact stack-effect model now includes `struct.get`, `struct.get_s`, `struct.get_u`, `array.get`, `array.get_s`, and `array.get_u`, which are required to prove and rewrite the artifact's exact operands without treating computed values as constants.

Focused public-pipeline coverage includes:

- a closed forwarding-only cycle plus bridge with an effectful incoming producer;
- plain-DAE separation;
- one observed non-forwarding use;
- parameter writes;
- export and `ref.func` escape;
- tail-call boundaries;
- non-exact operand slices;
- preservation of the separate constant-anchored SCC lane.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-forwarding-component-20260714/starshine-direct-final.wasm
SHA-256 3234b8ad98051f153ae0e04dde5ba2670ab12345678fddcd890486c5dd8d66c9
```

A second invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

The retained trace is:

```text
pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[7007, 7008, 7010]
pass[dae-optimizing]:forwarded-param-dead-callee-convergence sink_defs=[7014, 7033] cycle_defs=[]
pass[dae-optimizing]:forwarded-param-component-transaction defs=[7008, 7007, 7024, 7029, 7010] params=5
```

The selected transaction removes the target `i32` parameter from defined Funcs `7007`, `7008`, `7010`, and `7024`, plus the closed downstream sink parameter in defined Func `7029`. Arbitrary incoming computed producers remain evaluated and ordered; no computed value is replaced by a constant.

| dimension | note 1606 | component final | Binaryen v130 | final delta vs Binaryen |
|---|---:|---:|---:|---:|
| raw wasm | `3197391` | `3197423` | `3177421` | `+20002` |
| canonical wasm | `3274829` | `3274791` | `3262456` | `+12335` |
| DAEO pass-local | `14299.444ms` | `14405.477ms` | `8538.02ms` | `1.69x` |

Agent judgment:

- the five-parameter transaction is Binaryen-source-backed behavior parity progress and closes the named forwarding-component semantic gap;
- canonical output improves by `38` bytes over note `1606`, so the retained semantic shape is smaller after neutral Binaryen roundtrip;
- raw Starshine output grows by `32` bytes because effect-preserving localization and current encoder/type layout are not yet as compact before canonical roundtrip. This is a measured size-losing raw representation residue, not a Starshine win, and remains open under the direct artifact gap;
- pass-local performance remains within the required `<=2x` bound.

The remaining direct artifact gap is therefore `+20002` raw / `+12335` canonical. The next slice must re-attribute the first remaining canonical/function-level owner and separately determine whether the `32`-byte raw localization/encoding regression can be removed without weakening effect preservation.

## Required direct matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-forwarding-component-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-forwarding-component-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-forwarding-component-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, and `binaryen-bad-section-size=3`;
- wasm-smith cache hits/misses `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-forwarding-component-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- mismatch reduction disabled;
- Binaryen cache hits/misses `10000/0`.

The failure-directory names and all `2936` semantic `.wasm` / `.wat` artifacts are byte-identical to note `1606`. Agent classification therefore remains the established measured/source-backed Starshine cleanup wins: `coverage-forced-portable=243` and `dae-effectful-args=124`, aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first current dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z` with the same explicit native binary. Each mode emits a valid `38`-byte module, contains exactly one DAEO start/done pair, and places DAEO immediately before `inlining-optimizing`.

Measured DAEO timers:

- optimize: `692us`;
- shrink: `628us`;
- O4z: `526us`.

The large stripped-artifact pre-slot blockers remain owned by `[WALL]001`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`.

## Validation

Green final validation:

- `moon info` with existing warnings;
- `moon fmt` with unrelated `moon.mod` formatting restored;
- focused forwarding-component tests `5/5`;
- focused `dae_optimizing_test.mbt` `327/327`;
- full `moon test` `8822/8822`;
- `moon build --target native --release src/cmd`;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- `.mbti` diff from iteration base `9c471e999`: empty;
- direct output validation, repeat hash comparison, four-lane explicit-native matrix, scheduling checks, docs/source/link review, and `git diff --check`.

## Judgment and continuation

The forwarding-only parameter component is closed as Binaryen parity. DAEO remains active because the direct artifact still differs by `+12335` canonical bytes and the new endpoint retains a measured `+32` raw pre-canonical representation regression versus note `1606`.

Next slice: produce a function/type/section-ranked canonical diff between the retained Starshine and Binaryen outputs, identify the first remaining DAE-owned semantic or cleanup owner, and separately inspect the component's localized removed operands for a generic effect-preserving `drop`/stack-slice shape that can recover the raw `32` bytes without changing order or trap behavior. Retain only source-backed parity or a measured Starshine win, keep plain DAE separate, and preserve exact-once public scheduling.
