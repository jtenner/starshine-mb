# DAEO selected uniform-null cleanup final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130 `dae-optimizing` parity from note `1613` by following a direct callee reached from the accepted forwarding-component definitions. It retains exactly three source-backed optimizing-only changes:

1. reuse the forwarding-component transaction's existing authoritative call facts to find a private non-tail direct callee whose final read-only reference parameter is uniformly passed `ref.null`, then remove that argument and parameter transactionally;
2. immediately fold the materialized `ref.null; ref.is_null; if` in the changed callee through the existing selected null-test folder;
3. replace the callee's exact `i64 == 4294967296 ? 0 : i32.wrap_i64` shape, whose else arm contains a never-read `local.tee`, with the equivalent stack-ordered `select`.

The selected callee is defined Func `7084`, absolute Func `7105`. Binaryen removes the same final nullable-reference parameter and materializes the same default aggregate producer. Starshine now has the same five-parameter boundary, but still retains local-set/readback traffic and six body locals versus Binaryen's zero, so Func `7105` remains a direct parity gap.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 collects constant actuals during DAE, rewrites all direct calls and the callee signature/body together, and records changed functions for `OptUtils::optimizeAfterInlining(...)` (`.tmp/DeadArgumentElimination-v130.cpp`). The nested helper runs precompute propagation and the default function optimization sequence (`.tmp/slns-v130-source/src/passes/opt-utils.h`). `SimplifyLocals.cpp` sinks local values to reads when effect ordering permits, while ordinary instruction optimization turns constant conditions and equivalent branch/select forms into simpler stack expressions.

The retained Starshine behavior is narrower:

- candidate discovery starts only from definitions already proved by the optimizing-only forwarding-component transaction;
- it reuses that transaction's call facts rather than adding a second whole-module call scan;
- the callee must be private, non-tail, direct-call-covered, and have a final unwritten parameter with one exact uniform `ref.null` actual;
- caller rewrite counts, callee replacement, local remapping, signature/type repair, and touched tracking remain all-or-nothing;
- null-test folding uses the existing exact `ref.null; ref.is_null; if` proof;
- sentinel folding requires the literal `4294967296`, a result-`i32` `if`, an exact zero then-arm, the same source local in the else arm, and a tee local with zero gets, zero sets, and exactly one tee.

## Exactly three code-changing commits

1. `353431cb1 feat: materialize selected DAEO uniform null suffixes`
   - adds exactly one red-first selected-caller fixture;
   - reuses forwarding-component call facts and removes Func `7105`'s final uniform-null argument/parameter;
   - improves the direct artifact by `34` raw and `34` canonical bytes;
   - controlled development repeats were `17020.645ms` and `17016.406ms`, both below the `17076.04ms` ceiling.
2. `bdb68ee4e feat: fold selected DAEO materialized null tests`
   - adds exactly one red-first null-test convergence fixture;
   - folds the newly materialized null condition to the default-producing arm;
   - improves the direct artifact by another `13` raw and `13` canonical bytes.
3. `9884d6e01 feat: fold selected DAEO sentinel wrap conditionals`
   - adds exactly one red-first sentinel-wrap fixture;
   - removes the never-read tee and replaces the exact branch with an equivalent `select`;
   - improves the direct artifact by another `10` raw and `10` canonical bytes.

No fourth code-changing commit was made.

A separate terminal-call local-inlining experiment passed its reduced fixture but made no direct artifact improvement and measured `17939.219ms`, above the ceiling. It was fully reverted before commit 3. Earlier attempts to rerun aggregate leader forwarding after readback also produced byte-identical direct artifacts and were reverted before any commit.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 8056e53f534c097aa6cf4537b7271af8847f55eabf16ea6962931d577f298164
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

## Direct artifact and repeat stability

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-uniform-null-final-20260715/starshine-direct-1.wasm
SHA-256 44aedfd4319c6a5420cb3a5f74734a09cd8175a9505a7a3088ebd94acf5544d4
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-uniform-null-final-20260715/starshine-direct-1.canonical.wasm
SHA-256 edfca62a1d89bbb9293e8e9a1a49d11028f09900d4c2a8cee2305eef4353e0f2
```

The second raw output and second canonical roundtrip are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1613 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1613 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195388` | `3195331` | `3177421` | `+17910` | `-57` |
| canonical wasm | `3272994` | `3272937` | `3262456` | `+10481` | `-57` |
| DAEO pass-local, controlled run 1 | `16394.952ms` | `16775.956ms` | `8538.02ms` | `1.96x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16537.075ms` | `16692.599ms` | `8538.02ms` | `1.96x` | within `<=2x` |

The final trace still accepts post-component local cleanup only for Funcs `7008` and `7007`; the uniform-null rewrite is fused into the forwarding-component transaction's existing fact lifetime and touched set. It adds no second whole-module call-fact scan.

## Function-body and local-traffic evidence

| defined func | final raw | Binaryen raw | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|
| `7008` | `5084` | `4294` | `5073` | `4332` | `+741` |
| `7007` | `4309` | `3746` | `4541` | `3884` | `+657` |
| `7084` / abs `7105` | `72` | `50` | `72` | `50` | `+22` |

Relative to note `1613`, Func `7008` falls another `4` raw/canonical body bytes and Func `7007` another `8`; the selected pair's combined canonical gap is now `+1398`, down from `+1410`. Func `7105` now has Binaryen's five-parameter signature, but Starshine retains six body locals and three terminal local-set/readback lanes. Binaryen has zero body locals there.

The selected pair still prints `943` `local.get`, `245` `local.set`, and `131` `local.tee` occurrences versus Binaryen's `915`, `169`, and `169`. The excess get/set traffic remains a direct parity gap. The new Func `7105` boundary cleanup is not claimed as an intentional Starshine divergence.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75305` | `78167` | `-2862` |
| function | `25327` | `25369` | `-42` |
| code | `2985332` | `2971947` | `+13385` |
| net module | `3272937` | `3262456` | `+10481` |

The direct code and net-module gaps remain open. Smaller type/function sections do not excuse the larger code payload.

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-uniform-null-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-uniform-null-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-uniform-null-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-uniform-null-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1613`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay on the large stripped artifact validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `4827.246ms` pass-local. The selected uniform-null discovery, null-test folding, and sentinel folding therefore remain optimizing-only.

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `697us` for optimize, `661us` for shrink, and `554us` for O4z.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- three focused commit fixtures `1/1` each;
- full `moon test` `8839/8839`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration moves the direct goalpost in Starshine's favor by `57` raw and `57` canonical bytes while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, fact reuse, and the strict `<=2x` controlled pass-local ceiling. The retained transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10481`; selected Funcs `7008`/`7007` retain `+1398` combined canonical body bytes and excess local get/set traffic, while Func `7105` retains a `+22` body gap from local-set/readback cleanup. The next recursive iteration should derive exactly three further reduced/source-backed shapes from Func `7105` terminal local traffic and the surviving Type `309` branch-result/call sequences, reject any non-improving or over-`2x` endpoint, and keep validation-only or representation-only drift open unless a measured/source-backed Starshine benefit is proved.
