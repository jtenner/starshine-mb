# DAEO Type 309 call-transport final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130 `dae-optimizing` parity from note `1615` by reducing the exact surviving Type `309` branch-result and call-result transport in selected Func `7008`. It retains exactly three optimizing-only changes:

1. replace the terminal self branch of an exact zero-parameter four-`i32` result aggregate-field block with equivalent fallthrough;
2. flatten that now branch-free exact four-result block into its parent sequence;
3. sink an exact one-use direct-call result through four intervening pure `local.get` consumer arguments into the terminal direct call.

All three changes are fused into the existing accepted post-component count/rewrite traversal. They reuse its complete local-reference counts, selected-definition validation, selected-function encoded-size profitability, and rollback. No new module scan, selected-function scan, validation transaction, or encoding transaction was added.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen and semantic contract

Binaryen v130 records DAE-changed functions and runs `OptUtils::optimizeAfterInlining(...)` (`.tmp/DeadArgumentElimination-v130.cpp`, `.tmp/slns-v130-source/src/passes/opt-utils.h`). The nested default function pipeline includes `SimplifyLocals`; `.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp` explicitly sinks `local.set` values to later `local.get`s when complete use counts and effect ordering allow, and its structured mode converts common local assignments to block results for later cleanup.

The retained Starshine shapes are narrower than the general upstream pass:

- the result block must have exactly zero parameters and four results;
- its body must be exactly four `local.get` producer arguments, one direct call returning a proved non-null aggregate, the field order `2, 0, 1, 3`, and one terminal branch to that same block;
- the aggregate must have exactly three gets, zero sets, and one tee in the complete selected-function counts;
- terminal-self-branch removal is admitted only for that exact four-value body, so fallthrough carries the same four values;
- block flattening is admitted only after the terminal branch is gone and the exact body has no remaining control use;
- one-use call-result sinking requires exactly two pure producer `local.get` arguments, one direct producer call, one set/readback local with complete `1 get / 1 set / 0 tee` evidence, four pure consumer `local.get` arguments, one direct consumer call, and the terminal branch;
- only caller-local gets move across the producer call. A direct WebAssembly call cannot observe or mutate caller locals, so producer/consumer effect order is unchanged;
- malformed type, local, count, or shape evidence fails closed, and selected-definition validation plus strict encoded-size profitability still decides retention.

## Exactly three code-changing commits

1. `c9110bd4a feat: fold selected DAEO four-result self branches`
   - adds exactly one red-first focused fixture;
   - removes the two exact Type `309` terminal self branches;
   - improves the direct artifact by `4` raw and `12` canonical bytes;
   - development timing was `16842.701ms`, below the `17076.04ms` ceiling.
2. `ffee95729 feat: flatten selected DAEO four-result fallthrough blocks`
   - adds exactly one red-first focused fixture;
   - removes both surviving Type `309` wrappers after the self branches fold;
   - improves the direct artifact by another `8` raw and `52` canonical bytes;
   - development timing was `16853.590ms`, below the ceiling.
3. `79c394470 feat: sink selected DAEO one-use call results`
   - adds exactly one red-first focused fixture;
   - sinks the exact one-result producer in each of the two single-result dispatch arms;
   - improves the direct artifact by another `14` raw and `14` canonical bytes;
   - development timing was `16618.636ms`, below the ceiling.

No fourth code-changing commit was made.

A broader all-four-field block-to-terminal-call transport experiment produced byte-identical output and measured `17879.847ms`, above the absolute ceiling. It was rejected and fully reverted before the third commit.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 f5f515c1e2bc396c1667896ef3e780ca7ac3aabdd2e8ea55ae36d9351eccab55
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

Retained controlled outputs:

```text
.tmp/daeo-type309-transport-20260715/starshine-final-1.wasm
.tmp/daeo-type309-transport-20260715/starshine-final-2.wasm
SHA-256 228587b9ebd697aca281583133ad15df6d0c5d19e66bef8a044cbd99542c1c2c
```

Canonical Binaryen-v130 roundtrips:

```text
.tmp/daeo-type309-transport-20260715/starshine-final-1.canonical.wasm
.tmp/daeo-type309-transport-20260715/starshine-final-2.canonical.wasm
SHA-256 902daa93073336c3a28b17dd560d99a27387d965a6b10babfc91320dde9bf929
```

Both raw outputs and both canonical roundtrips are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1615 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1615 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195309` | `3195283` | `3177421` | `+17862` | `-26` |
| canonical wasm | `3272915` | `3272837` | `3262456` | `+10381` | `-78` |
| DAEO pass-local, controlled run 1 | `16902.094ms` | `16828.356ms` | `8538.02ms` | `1.97x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16858.923ms` | `16752.379ms` | `8538.02ms` | `1.96x` | within `<=2x` |

## Function-body, Type 309, and section evidence

| defined func | final raw | Binaryen raw | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|
| `7008` | `5058` | `4294` | `4995` | `4332` | `+663` |
| `7007` | `4309` | `3746` | `4541` | `3884` | `+657` |
| `7084` / abs `7105` | `50` | `50` | `50` | `50` | `0` |

The two selected Type `309` wrappers are gone, matching Binaryen's absence of that control wrapper. Func `7008` improves by `26` raw and `78` canonical body bytes. Func `7007` is unchanged. The pair's combined canonical body gap falls from `+1398` to `+1320`.

The selected pair's printed traffic is now Starshine `941` `local.get` / `243` `local.set` / `131` `local.tee` versus Binaryen `915` / `169` / `169`. This iteration removes two gets and two sets. The remaining excess get/set traffic is still a direct parity gap.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75305` | `78167` | `-2862` |
| function | `25327` | `25369` | `-42` |
| code | `2985232` | `2971947` | `+13285` |
| net module | `3272837` | `3262456` | `+10381` |

The direct code and net-module gaps remain open. Smaller type/function sections do not excuse the larger code payload.

Evidence files:

```text
.tmp/daeo-type309-transport-20260715/function-section-evidence.json
.tmp/daeo-type309-transport-20260715/local-traffic.json
.tmp/daeo-type309-transport-20260715/starshine-pair.print
```

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-type309-transport-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-type309-transport-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-type309-transport-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-type309-transport-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1615`, as recorded in `.tmp/daeo-type309-transport-20260715/random-all-byte-identity.json`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay on the large stripped artifact validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `3401.769ms` pass-local. The Type `309` and one-use call-result cleanup therefore remains optimizing-only.

The first final dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `776us` for optimize, `695us` for shrink, and `746us` for O4z. Evidence is in `.tmp/daeo-type309-transport-20260715/scheduled/scheduling-summary.json`.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- the three new focused fixtures `1/1` each plus the selected uniform-null integration fixture `1/1`;
- full `moon test` `8845/8845`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration removes both selected Type `309` wrappers and two one-use call-result set/readback pairs while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, one-traversal fact reuse, and the strict `<=2x` controlled pass-local ceiling. These transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10381`; selected Funcs `7008`/`7007` retain `+1320` combined canonical body bytes and excess local get/set traffic. The next recursive iteration should reduce three exact current sibling transport shapes rather than retrying the rejected broad block-to-call rewrite:

1. the two-producer dispatch arms where Binaryen keeps the first result local but sinks the second producer directly into the consumer;
2. the three-producer dispatch arms where Binaryen keeps the first two result locals but sinks the third producer directly into the consumer;
3. one exact mutually exclusive branch-local reuse/coalescing shape exposed after those sinks, with complete type/use/branch-scope evidence and no extra traversal.

Any non-improving or over-`17076.04ms` endpoint must be rejected before commit. Validation-only or representation-only residuals remain parity gaps unless measured/source-backed Starshine benefit is proved.
