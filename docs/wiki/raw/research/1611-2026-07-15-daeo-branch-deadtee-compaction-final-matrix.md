# DAEO selected branch, dead-tee, and local-compaction final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130's `dae-optimizing` changed-function cleanup contract on only the exact accepted forwarding-component definitions from note `1610`. It retains three measured, source-backed cleanup shapes:

1. rotate a selected branch-only value `if` into a rebased `br_if` form;
2. remove selected `local.tee` writes whose local is never read while preserving the stack value;
3. compact local declarations made unused by that removal, with all surviving local indexes remapped in the same selected-function traversal.

Plain `dead-argument-elimination` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen source contract and rejected probes

Binaryen v130 records changed functions in `worthOptimizing` and invokes `OptUtils::optimizeAfterInlining(...)` for `dae-optimizing` (`.tmp/DeadArgumentElimination-v130.cpp`). The implementation in `.tmp/slns-v130-source/src/passes/opt-utils.h` uses a filtered runner, a `precompute-propagate` prefix, and the default function optimization sequence.

Reduced fixtures confirmed that `simplify-locals`, `simplify-locals-nostructure`, `local-cse`, `reorder-locals`, and `remove-unused-brs` can optimize related local/control shapes. Direct-artifact probes on accepted Funcs `7008`/`7007` did not improve the selected endpoint, so none of those broad adapters were retained. The committed slices instead isolate exact profitable shapes already exposed by the accepted coalesce/vacuum result.

## Three code-changing commits

1. `cd5acab5c feat: rotate selected DAEO branch-only ifs`
   - adds optimizing-only selected-definition branch-only `if` to rebased `br_if` cleanup;
   - preserves per-definition deep-clone isolation, selected validation, and strict selected-function encoded profitability;
   - adds exactly one red-first outer-branch fixture;
   - improves the artifact by `16` raw and `16` canonical bytes.
2. `a61811ba4 feat: remove selected DAEO never-read local tees`
   - recursively counts local reads and removes `local.tee` writes only when that local has no reads;
   - preserves the produced stack value and uses the existing selected validation/profitability transaction;
   - adds exactly one red-first white-box fixture;
   - improves the artifact by another `1045` raw and `1104` canonical bytes.
3. `9c5335fac perf: fuse selected DAEO dead-tee local compaction`
   - compacts declarations exposed by dead-tee removal and remaps surviving local references;
   - fuses dead-tee erasure, declaration compaction, and local remapping into one large-function traversal and one selected validation/profitability decision;
   - retains the existing small-function dead-tee helper path;
   - adds exactly one red-first local-compaction fixture;
   - improves the artifact by another `78` raw and `67` canonical bytes.

No fourth code-changing commit was made.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 0a2c51842501c036bda1e62e82daec2a90a42f25db022bb6e570c6408b4d4a96
```

All authoritative compare lanes use Binaryen v130 through:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

They use `--jobs auto`, the explicit native Starshine binary, and both DAE normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-post-deadtee-final-20260715/starshine-direct.wasm
SHA-256 ba446d38edbea7b31b157335e06648248145c64b78e81bcdf99dc271957464bc
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-post-deadtee-final-20260715/starshine-direct.canonical.wasm
SHA-256 d654918b48638d1434295d6a209dcc603b1a333b508d29bbdbc56b60cc5e7c91
```

Raw and canonical repeats are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1610 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1610 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3196657` | `3195518` | `3177421` | `+18097` | `-1139` |
| canonical wasm | `3274317` | `3273130` | `3262456` | `+10674` | `-1187` |
| DAEO pass-local, controlled run 1 | `15775.580ms` | `16828.192ms` | `8538.02ms` | `1.97x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `15735.944ms` | `16523.429ms` | `8538.02ms` | `1.94x` | within `<=2x` |

Two earlier final-directory runs at `17373.928ms` and `17800.344ms` overlapped an unrelated `starshine-sidework` `moonrun` consuming about one CPU. They are retained as contention evidence but are not the controlled pass-local signoff. The contention-free repeats are byte-identical and restore the required `<=2x` ceiling.

The final direct trace reports:

```text
post-component-cleanup defs=[7008] passes=[coalesce-locals, vacuum, branch-only-if-to-br-if, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup defs=[7007] passes=[coalesce-locals, vacuum, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup-rollback reason=coalesce-validation-pass-or-encode defs=[7024]
post-component-cleanup-skip reason=non-improving-coalesce-encoded-size defs=[7010]
post-component-cleanup-skip reason=small-local-set defs=[7029]
nested-cleanup-skip reason=large-touched-set touched=46
```

A direct plain-DAE replay validates, reports one `dead-argument-elimination` invocation, emits no `post-component-cleanup` trace, and spends `3439.561ms` pass-local. The optimizing-only replay therefore remains separate from plain DAE.

## Function-body and local evidence

Only defined Funcs `7008` and `7007` account for the module reduction:

| defined func | note 1610 raw | final raw | Binaryen raw | note 1610 canonical | final canonical | Binaryen canonical |
|---:|---:|---:|---:|---:|---:|---:|
| `7008` | `5850` | `5191` | `4294` | `5854` | `5178` | `4332` |
| `7007` | `4824` | `4344` | `3746` | `5095` | `4584` | `3884` |

The compaction evidence is substantial even though declaration encoding is compact:

| defined func | note 1610 locals | final locals | Binaryen locals |
|---:|---:|---:|---:|
| `7008` | `1035` | `421` | `327` |
| `7007` | `2188` | `934` | `665` |

Across the printed pair, final Starshine has `973` `local.get`, `275` `local.set`, and `115` `local.tee` occurrences versus Binaryen's `915`, `169`, and `169`. Removing never-read tees and declarations is therefore a real parity reduction, but the remaining excess `local.get`/`local.set` traffic is still an open parity gap. Fewer tees alone is not claimed as a Starshine win because the selected bodies remain larger.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2985523` | `2971947` | `+13576` |
| net module | `3273130` | `3262456` | `+10674` |

The largest remaining positive canonical body deltas are Func `8429 +1448`, Func `41 +1286`, Func `9347 +1280`, Func `8187 +1256`, Func `7556 +1133`, Func `6377 +1032`, Funcs `7919`/`8185 +984`, Func `1247 +922`, Func `7943 +909`, Func `7008 +846`, and Func `7007 +700`.

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-post-deadtee-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-post-deadtee-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-post-deadtee-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-post-deadtee-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names, file sets, and all `3670` saved failure files are byte-identical to note `1610`, including the `2202` semantic raw/canonical/WAT comparison artifacts. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Exact-once public scheduling

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done line immediately before the `inlining-optimizing` start line.

DAEO timers are `695us` for optimize, `930us` for shrink, and `611us` for O4z.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- three focused commit fixtures `1/1` each;
- full `moon test` `8830/8830`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration moves the direct goalpost in Starshine's favor by `1139` raw and `1187` canonical bytes while preserving validation, generated semantic classifications, exact plain-DAE separation, exact-once public scheduling, deterministic output, and the `<=2x` controlled pass-local ceiling. The retained transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10674`, selected Funcs `7008`/`7007` still have `+1546` combined body bytes and excess `local.get`/`local.set` traffic, and larger independent owners remain. The next iteration should not blindly retry the already non-improving whole adapters. It should derive three distinct reduced/source-backed shapes from the surviving copy/control difference, retain only strict selected-function wins, preserve one validation/profitability transaction per candidate, and keep the explicit native matrix and `<=2x` timing ceiling.
