# DAEO complete call transport final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130 `dae-optimizing` parity from note `1617` with exactly three red-first optimizing-only changes in the existing selected post-component count/rewrite traversal:

1. carry an exact zero-parameter single-result block through `i32.const 0`, one direct unary call, and terminal `struct.new; return`;
2. carry exact one-use structured block results after two pure caller-local arguments into a direct call, with complete type/count evidence and a recursive guard against producer-block writes to either moved local;
3. carry one exact complete nested direct-call value slice through one pure caller-local argument into the terminal consumer, preserving the prefix call, final producer call, side-call suffix, constructor, and return order.

The first slice closes the twelve current Func `7007` block-result/zero/unary-call terminals recommended by note `1617`. The second sinks four current Func `7008` structured results into the repeated `call 7042` family; one apparent sibling correctly remains local because its producer can rewrite a would-be moved caller local. The third replaces rejected partial `call 7053`/`call 10815` attempts with a complete stack slice and removes one accepted Func `7008` set/readback pair.

All retained changes reuse the existing selected-function local counts, recursive rewrite traversal, selected-definition validation, selected-function encoded-size profitability, rollback, and final local compaction. The structured block matchers are fused into one prefiltered helper, and the complete direct-call slice extends an already-called matcher. No new module scan, selected-function scan, validation transaction, encoding transaction, or substantial every-instruction helper was added.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen and semantic contract

Binaryen v130 records DAE-changed functions and calls `OptUtils::optimizeAfterInlining(...)` (`.tmp/DeadArgumentElimination-v130.cpp`, `.tmp/slns-v130-source/src/passes/opt-utils.h`). Its default changed-function cleanup includes `SimplifyLocals`; `.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp` sinks one-use values to their reads when complete use counts and effect ordering permit, and its structured mode carries assignments through block results.

The retained Starshine shapes are deliberately narrower:

- every removed carrier has complete `1 get / 1 set / 0 tee` evidence;
- every block has zero parameters and exactly one result, including resolved type-index block forms;
- the block result type exactly matches the removed body-local type;
- the zero moved before the block is pure and nontrapping;
- the two moved call arguments are exact caller-local gets, and the producer block is recursively proved not to write either local when global write counts do not already prove immutability;
- the complete direct-call slice starts before the prefix call that supplies the final producer, so no ambient stack value is captured or displaced;
- every direct call stays in its original order;
- the terminal drop, two side calls, constant, final local, constructor, and return are required as an exact suffix before the complete slice is admitted;
- malformed type, local, count, dominance, effect, or suffix evidence fails closed;
- selected-definition validation and strict selected-function encoded-size profitability still decide retention.

A direct WebAssembly call cannot observe or mutate its caller's locals. Moving pure caller-local gets before complete direct-call producer slices therefore preserves their values, while matching the whole producer stack slice preserves call operands and effect order. Moving a constant zero before a zero-parameter block likewise preserves every observable operation in the block.

## Exactly three code-changing commits

1. `6d0287de2 feat: sink selected DAEO block results through calls`
   - adds exactly one red-first focused fixture;
   - removes the twelve current Func `7007` block-result set/readback carriers through the unary call;
   - improves the direct artifact by `66` raw and `65` canonical bytes;
   - development controlled timings were `17069.985ms` and `16915.068ms`, both below the `17076.04ms` ceiling.
2. `802cc6ed2 feat: sink selected DAEO structured call arguments`
   - adds exactly one red-first focused fixture;
   - fuses the existing block transports into one prefiltered matcher and removes four current Func `7008` structured-result carriers before `call 7042`;
   - keeps the fifth apparent sibling fail-closed because its block can rewrite a moved local;
   - leaves raw size unchanged but improves canonical size by `4` bytes;
   - development controlled timings were `16905.158ms` and `16821.258ms`, both below the ceiling.
3. `e0f17be91 feat: sink selected DAEO complete call slices`
   - adds exactly one red-first focused fixture;
   - recognizes the complete producer slice including the prefix direct call, rather than starting in the middle of an ambient stack value;
   - removes one accepted Func `7008` direct-call result carrier;
   - improves the direct artifact by another `7` raw and `7` canonical bytes;
   - development controlled timings were `16778.930ms` and `16774.514ms`, both below the ceiling.

No fourth code-changing commit was made.

## Rejected experiments

Three non-retained endpoints were fully reverted before commit 3:

- a broad `call 7053` result transport that started at the final producer operands but omitted the preceding `call 7096` stack value;
- a narrower constant-middle version of that same partial slice;
- a partial `call 10815` slice that omitted the preceding `call 7097` result.

Each partial slice displaced an ambient producer operand, made Func `7008` fail the existing never-read-local-tee validation/encoding retention step, and rolled that function back to a much larger pre-cleanup shape. The resulting endpoint was raw `3195898` / canonical `3273521`, a regression of `+1010` raw / `+1081` canonical bytes versus commit 2. Those attempts were rejected as incorrect/non-improving before commit.

A one-pure-argument structured-block transport probe was byte-identical to commit 2 and was also reverted as a no-op. Future call-result transport must begin at the complete stack value slice, not merely at the visible final call operands.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 2e46318b273bc3c17bf0843f8fcd816e886e8b88e566ab6e64a191ad5ab25021
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

Retained controlled output:

```text
.tmp/daeo-call-transport-20260715/final-quiescent-1.wasm
.tmp/daeo-call-transport-20260715/final-quiescent-3.wasm
SHA-256 1a344b46c460151984a40c22f51f22f25698525cd61daf04f5d208bff7df73e5
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-call-transport-20260715/final-quiescent-1.canonical.wasm
SHA-256 41aa09257a683004c2c1223438e8e486a1664a84a9253ff0c6f778ea52741762
```

The retained raw repeats are byte-identical, and all raw/canonical outputs validate under `wasm-tools validate --features all`.

| dimension | note 1617 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1617 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3194954` | `3194881` | `3177421` | `+17460` | `-73` |
| canonical wasm | `3272509` | `3272433` | `3262456` | `+9977` | `-76` |
| DAEO pass-local, controlled run 1 | `16690.578ms` | `16757.176ms` | `8538.02ms` | `1.96x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16753.227ms` | `16741.469ms` | `8538.02ms` | `1.96x` | within `<=2x` |

A second final-directory run measured `17831.023ms`, but unrelated `starshine-sidework` native compilation began during that run at `2026-07-15 18:41:47` and consumed a CPU core. It is not a controlled endpoint. The retained controlled worst repeat has `318.864ms` of headroom below the absolute ceiling.

## Function-body, section, and local-traffic evidence

| defined func | final raw | Binaryen raw | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|
| `7008` | `4813` | `4294` | `4746` | `4332` | `+414` |
| `7007` | `4152` | `3746` | `4386` | `3884` | `+502` |
| `7084` / abs `7105` | `50` | `50` | `50` | `50` | `0` |

The selected pair's combined canonical body gap falls from `+992` to `+916`. Func `7007` improves by `66` raw / `65` canonical body bytes; Func `7008` improves by `7` raw / `11` canonical body bytes.

Printed local traffic is now:

| defined func | Starshine get/set/tee | Binaryen get/set/tee |
|---:|---:|---:|
| `7008` | `493 / 90 / 49` | `523 / 68 / 79` |
| `7007` | `383 / 88 / 82` | `392 / 101 / 90` |
| pair | `876 / 178 / 131` | `915 / 169 / 169` |

Starshine now has `39` fewer gets and `38` fewer tees but still has `9` extra sets and `+916` canonical body bytes in the selected pair. Those shape differences are not accepted wins: no measured downstream, net-size, or performance benefit excuses the larger bodies and module.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75305` | `78167` | `-2862` |
| function | `25327` | `25369` | `-42` |
| code | `2984828` | `2971947` | `+12881` |
| net module | `3272433` | `3262456` | `+9977` |

The direct code and net-module gaps remain open. Smaller type/function sections do not excuse the larger code payload.

Evidence files:

```text
.tmp/daeo-call-transport-20260715/function-section-evidence.json
.tmp/daeo-call-transport-20260715/local-traffic.json
.tmp/daeo-call-transport-20260715/star-raw-pair.print
```

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-call-transport-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-call-transport-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- selected profile `binaryen-oracle-portable=100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-call-transport-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-call-transport-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1617`, as recorded in `.tmp/daeo-call-transport-20260715/random-all-byte-identity.json`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay on the large stripped artifact validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `3762.602ms` pass-local. The complete call transport remains optimizing-only.

The first final dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `862us` for optimize, `761us` for shrink, and `629us` for O4z. Evidence is in `.tmp/daeo-call-transport-20260715/scheduled/scheduling-summary.json`.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- the three new focused fixtures `1/1` each plus the selected uniform-null integration fixture `1/1`;
- full `moon test` `8851/8851`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical controlled repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration closes the named twelve Func `7007` unary-call terminals, four safe Func `7008` structured-result call arguments, and one exact complete nested-call result carrier while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, one-traversal fact reuse, and the strict `<=2x` controlled pass-local ceiling. These changes reduce Binaryen changed-function cleanup parity gaps; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+9977`; selected Funcs `7008`/`7007` retain `+916` combined canonical body bytes and a different local-traffic distribution without a demonstrated Starshine benefit. The next recursive iteration should start from complete stack slices rather than visible final-call operands:

1. reduce the two current Func `7008` `call 7053` carriers whose complete producer begins before `call 7096`, includes the final `call 7106`, and is followed by the exact drop/constructor/return suffix;
2. reduce the third current `call 7053` carrier whose complete producer includes the conditional selector, `call 7123`, `call 7096`, and final `call 7106`;
3. derive one exact branch/block-result carrier into the remaining `call 7053` family or another current one-use local only after direct measurement proves a strict raw or canonical improvement.

Each new shape must retain complete type/get/set/tee/dominance/effect evidence, start at the complete value slice, reuse the existing traversal, improve the direct artifact, and remain below `17076.04ms`. Validation-only or apparent semantic equivalence remains insufficient to waive the residual.
