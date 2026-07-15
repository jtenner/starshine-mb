# DAEO sibling and terminal transport final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130 `dae-optimizing` parity from note `1616` with exactly three red-first optimizing-only changes in the existing selected post-component count/rewrite traversal:

1. sink the final result of each exact two-producer dispatch arm through four pure caller-local consumer arguments while preserving the first result local and both producer calls in order;
2. sink the final result of each exact three-producer dispatch arm through four pure caller-local consumer arguments while preserving the first two result locals and all producer calls in order;
3. sink exact zero-parameter single-result block values through a pure leading `i32.const 0` into terminal `struct.new; return`, removing complete one-use set/readback pairs.

The first two shapes close the sibling call-result transport recommended by note `1616`. The third shape replaces a rejected branch-scoped local-coalescing experiment with a larger current Func `7008`/`7007` one-use transport family.

All retained changes reuse the existing selected-function local counts, recursive rewrite traversal, selected-definition validation, selected-function encoded-size profitability, rollback, and final local compaction. No new module scan, selected-function scan, validation transaction, or encoding transaction was added.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen and semantic contract

Binaryen v130 records DAE-changed functions and calls `OptUtils::optimizeAfterInlining(...)` (`.tmp/DeadArgumentElimination-v130.cpp`, `.tmp/slns-v130-source/src/passes/opt-utils.h`). Its default changed-function cleanup includes `SimplifyLocals`; `.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp` sinks one-use values to their reads when complete use counts and effect ordering permit, and its structured mode carries assignments through block results.

The retained Starshine shapes are deliberately narrower:

- every sibling producer and consumer is a direct call;
- every producer has exactly two caller-local `local.get` operands;
- exactly four pure caller-local consumer arguments move before only the final producer;
- producer call order is unchanged;
- the two-producer arm retains the first result local, and the three-producer arm retains the first two result locals and their readback order;
- only the final result local is removed, with complete `1 get / 1 set / 0 tee` evidence;
- the terminal structured-result shape requires an exact `block; local.set; i32.const 0; local.get; struct.new; return` sequence;
- the block must have zero parameters and exactly one result, including resolved type-index block forms;
- that result type must exactly match the one-use target local type;
- the moved zero is pure and nontrapping, so all block effects, traps, branches, and produced value order remain unchanged;
- malformed type, local, count, or shape evidence fails closed, and selected-definition validation plus strict encoded-size profitability still decides retention.

A direct WebAssembly call cannot observe or mutate its caller's locals. Moving caller-local gets before the final producer therefore preserves the values and does not reorder producer effects. Moving a constant zero before a zero-parameter block likewise preserves every observable operation in the block.

## Exactly three code-changing commits

1. `823dcbd00 feat: sink selected DAEO two-producer results`
   - adds exactly one red-first focused fixture;
   - removes the final set/readback pair in both exact two-producer sibling arms;
   - improves the direct artifact by `14` raw and `14` canonical bytes;
   - development timing was `16557.012ms`, below the `17076.04ms` ceiling.
2. `527e21ed0 feat: sink selected DAEO three-producer results`
   - adds exactly one red-first focused fixture;
   - removes the final set/readback pair in both exact three-producer sibling arms;
   - improves the direct artifact by another `14` raw and `14` canonical bytes;
   - development timing was `16596.951ms`, below the ceiling.
3. `00e0e8599 feat: sink selected DAEO terminal block results`
   - adds exactly one red-first focused fixture;
   - removes `50` exact structured-result set/readback pairs across selected Funcs `7008` and `7007`;
   - improves the direct artifact by another `297` raw and `300` canonical bytes;
   - development timing was `16662.032ms`, below the ceiling.

No fourth code-changing commit was made.

## Rejected experiment

An exact branch-scoped local-coalescing experiment shared the first-result local between the mutually exclusive two- and three-producer continuations. It improved only `4` raw / `6` canonical bytes but measured `17108.656ms` and `17126.210ms`, both above the absolute `17076.04ms` ceiling. The experiment was fully reverted before the third retained commit. Do not retry it unless the proof can be fused with effectively zero additional traversal cost and a fresh endpoint stays below the ceiling.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 86db2642dfbc3b6b1c1e2cdd11517fd146c24529cb73e8fb0f442e88ce004ab2
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

## Direct artifact and controlled repeat stability

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained controlled outputs:

```text
.tmp/daeo-sibling-transport-20260715/head-quiescent-1.wasm
.tmp/daeo-sibling-transport-20260715/head-quiescent-2.wasm
SHA-256 442ff65cd7a3844e1fbef3eec2f2fa7a49370443634191eef013cd2b24c78e42
```

Canonical Binaryen-v130 roundtrips:

```text
.tmp/daeo-sibling-transport-20260715/head-quiescent-1.canonical.wasm
.tmp/daeo-sibling-transport-20260715/head-quiescent-2.canonical.wasm
SHA-256 0240ea5acc26ab40f2c8e50efd803f02cc4059dcd55c53d2b3f074db681d58e1
```

Both raw outputs and both canonical roundtrips are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1616 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1616 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195283` | `3194954` | `3177421` | `+17533` | `-329` |
| canonical wasm | `3272837` | `3272509` | `3262456` | `+10053` | `-328` |
| DAEO pass-local, controlled run 1 | `16828.356ms` | `16690.578ms` | `8538.02ms` | `1.95x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16752.379ms` | `16753.227ms` | `8538.02ms` | `1.96x` | within `<=2x` |

The slower timing probes recorded while unrelated CPU-heavy work was active are not the controlled endpoint. The retained controlled worst repeat has `322.813ms` of headroom below the absolute ceiling.

## Function-body, section, and local-traffic evidence

| defined func | final raw | Binaryen raw | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|
| `7008` | `4820` | `4294` | `4757` | `4332` | `+425` |
| `7007` | `4218` | `3746` | `4451` | `3884` | `+567` |
| `7084` / abs `7105` | `50` | `50` | `50` | `50` | `0` |

The selected pair's combined canonical body gap falls from `+1320` to `+992`. Func `7008` improves by `238` raw and `238` canonical body bytes; Func `7007` improves by `91` raw and `90` canonical body bytes.

Printed local traffic is now:

| defined func | Starshine get/set/tee | Binaryen get/set/tee |
|---:|---:|---:|
| `7008` | `494 / 91 / 49` | `523 / 68 / 79` |
| `7007` | `393 / 98 / 82` | `392 / 101 / 90` |
| pair | `887 / 189 / 131` | `915 / 169 / 169` |

This iteration removes `54` gets and `54` sets: four sibling final-result pairs plus fifty terminal structured-result pairs. Starshine now has fewer gets and tees than Binaryen but still has `20` extra sets and `+992` canonical body bytes in the selected pair. Those shape differences are not accepted wins: no measured downstream, net-size, or performance benefit excuses the larger bodies and module.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75305` | `78167` | `-2862` |
| function | `25327` | `25369` | `-42` |
| code | `2984904` | `2971947` | `+12957` |
| net module | `3272509` | `3262456` | `+10053` |

The direct code and net-module gaps remain open. Smaller type/function sections do not excuse the larger code payload.

Evidence files:

```text
.tmp/daeo-sibling-transport-20260715/function-section-evidence.json
.tmp/daeo-sibling-transport-20260715/local-traffic.json
.tmp/daeo-sibling-transport-20260715/star-raw-pair.print
```

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-sibling-transport-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-sibling-transport-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-sibling-transport-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-sibling-transport-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1616`, as recorded in `.tmp/daeo-sibling-transport-20260715/random-all-byte-identity.json`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay on the large stripped artifact validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `3469.996ms` pass-local. The sibling and terminal transport remains optimizing-only.

The first final dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `807us` for optimize, `1165us` for shrink, and `759us` for O4z. Evidence is in `.tmp/daeo-sibling-transport-20260715/scheduled/scheduling-summary.json`.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- the three new focused fixtures `1/1` each plus the selected uniform-null integration fixture `1/1`;
- full `moon test` `8848/8848`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration closes the named two-producer and three-producer final-result transport gaps and removes fifty additional exact terminal structured-result set/readback pairs while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, one-traversal fact reuse, and the strict `<=2x` controlled pass-local ceiling. These changes reduce Binaryen changed-function cleanup parity gaps; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10053`; selected Funcs `7008`/`7007` retain `+992` combined canonical body bytes and a different local-traffic distribution without a demonstrated Starshine benefit. The next recursive iteration should reduce three exact current one-use transport families rather than retrying the rejected branch coalescer:

1. the `12` Func `7007` terminal shapes `zero-param single-result block; set; i32.const 0; get; direct call; struct.new; return`;
2. exact Func `7008` structured-result locals passed after pure local arguments into terminal direct calls such as the repeated `call 7042` family;
3. exact Func `7008` direct-call results read once after pure local arguments into `call 7053` or a comparably current one-use family.

Each new shape must retain complete type/get/set/tee/dominance/effect evidence, use the existing traversal, improve the direct artifact, and remain below `17076.04ms`. Validation-only or apparent semantic equivalence remains insufficient to waive the residual.
