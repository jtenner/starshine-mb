# DAEO terminal-local sinking final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130 `dae-optimizing` parity from note `1614` by closing the remaining selected Func `7105` terminal-local gap. It retains exactly three source-backed optimizing-only changes:

1. sink the pure default aggregate producer through its one-use local into terminal Func `7106`;
2. move the three pure parameter gets before the two sentinel producers and keep the first sentinel result on the operand stack;
3. remove the remaining adjacent second-sentinel set/readback, then trim all exposed body locals.

The final rewrite is fused into the selected sentinel-fold application and is restricted to the removed-parameter transaction's `primary_def`. Caller rewrites only remove the uniform-null argument; the null test, sentinel selects, default aggregate, and terminal locals all belong to the changed callee. This avoids rescanning giant touched callers, adds no whole-module fact scan, and preserves the forwarding-component transaction's existing authoritative call facts.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 records DAE-changed functions and runs `OptUtils::optimizeAfterInlining(...)` (`.tmp/DeadArgumentElimination-v130.cpp`, `.tmp/slns-v130-source/src/passes/opt-utils.h`). The nested default function pipeline includes `SimplifyLocals`, whose source explicitly sinks a `local.set` value to its next `local.get` when effect ordering and use counts permit (`.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp`).

The retained Starshine shapes are narrower:

- the default aggregate suffix must be exact `array.new_fixed 0; i32.const 0; struct.new; local.set`, followed by five pure `local.get` arguments, one exact readback, and a terminal direct call;
- the first sentinel lane requires two exact `i64 != 4294967296` select producers, three leading parameter gets, complete one-get/one-set/no-tee evidence for the first result, and the same terminal aggregate/call suffix;
- the second sentinel lane requires the post-first-sink exact stack shape and complete one-get/one-set/no-tee evidence for the remaining result;
- all moved prefixes are only `local.get`; allocation order relative to the sentinel producers is preserved;
- trailing-local trimming uses the existing complete local-reference extent proof;
- the cleanup application is limited to `result.primary_def`, while the original full touched set remains preserved for scheduling.

## Exactly three code-changing commits

1. `cb13830f9 feat: sink selected DAEO terminal default aggregates`
   - adds exactly one red-first focused fixture;
   - removes the default aggregate set/readback and four newly trailing locals;
   - improves the direct artifact by `12` raw and `12` canonical bytes;
   - development timing was `16705.382ms`, below the `17076.04ms` ceiling.
2. `33579ad7e feat: sink selected DAEO first sentinel results`
   - adds exactly one red-first focused fixture;
   - moves only the three pure leading parameter gets and leaves the first sentinel result on the stack;
   - improves the direct artifact by another `4` raw and `4` canonical bytes;
   - development timing was `16851.963ms`, below the ceiling.
3. `48aa9a095 feat: sink selected DAEO second sentinel results`
   - adds exactly one red-first focused fixture;
   - removes the remaining sentinel set/readback and the final two body locals;
   - fuses default/sentinel sinking into one primary-definition selected application;
   - improves the direct artifact by another `6` raw and `6` canonical bytes.

No fourth code-changing commit was made.

A separate second selected-function application produced the same final bytes but measured `17717.926ms`, `17448.084ms`, and `17602.414ms`; it was rejected before the third commit. A broader touched-set fusion also exceeded the ceiling. Restricting the exact cleanup to `primary_def` produced controlled repeats under the ceiling. Non-controlled runs while another workspace was compiling were recorded but excluded from the controlled endpoint; the final quiescent pair below is the retained performance evidence.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 541418778e981eaf9ff96bf70081afced819b3645a04db076fc01da1ce916ba9
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
.tmp/daeo-terminal-locals-final-20260715/starshine-final-5.wasm
.tmp/daeo-terminal-locals-final-20260715/starshine-final-6.wasm
SHA-256 b78df049911631de91ef96f044d7476529ba68e423283332b83780d48d75ccca
```

Canonical Binaryen-v130 roundtrips:

```text
.tmp/daeo-terminal-locals-final-20260715/starshine-final-5.canonical.wasm
.tmp/daeo-terminal-locals-final-20260715/starshine-final-6.canonical.wasm
SHA-256 5395d4666cf80da3cfeddc3afea6ee358ff68686f2ac73ecd62d7cb0ab5bc26e
```

Both raw outputs and both canonical roundtrips are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1614 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1614 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195331` | `3195309` | `3177421` | `+17888` | `-22` |
| canonical wasm | `3272937` | `3272915` | `3262456` | `+10459` | `-22` |
| DAEO pass-local, controlled run 1 | `16775.956ms` | `16902.094ms` | `8538.02ms` | `1.98x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16692.599ms` | `16858.923ms` | `8538.02ms` | `1.97x` | within `<=2x` |

## Function-body and section evidence

| defined func | final raw | Binaryen raw | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|
| `7008` | `5084` | `4294` | `5073` | `4332` | `+741` |
| `7007` | `4309` | `3746` | `4541` | `3884` | `+657` |
| `7084` / abs `7105` | `50` | `50` | `50` | `50` | `0` |

Func `7105` now exactly matches Binaryen's five-parameter, zero-body-local terminal stack shape. Its previous `+22` body gap is closed. Funcs `7008`/`7007` are unchanged and still retain `+1398` combined canonical body bytes.

The selected pair's printed traffic remains Starshine `943` `local.get` / `245` `local.set` / `131` `local.tee` versus Binaryen `915` / `169` / `169`. Those excess get/set operations remain a direct parity gap.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75305` | `78167` | `-2862` |
| function | `25327` | `25369` | `-42` |
| code | `2985310` | `2971947` | `+13363` |
| net module | `3272915` | `3262456` | `+10459` |

The direct code and net-module gaps remain open. Smaller type/function sections do not excuse the larger code payload.

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-terminal-locals-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-terminal-locals-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-terminal-locals-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-terminal-locals-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1614`, as recorded in `.tmp/daeo-terminal-locals-final-20260715/random-all-byte-identity.json`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay on the large stripped artifact validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `3428.788ms` pass-local. The primary-definition terminal sinking therefore remains optimizing-only.

The first final dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `692us` for optimize, `703us` for shrink, and `611us` for O4z. Evidence is in `.tmp/daeo-terminal-locals-final-20260715/scheduled/scheduling-summary.json`.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- the three new focused fixtures `1/1` each plus the selected uniform-null integration fixture `1/1`;
- full `moon test` `8842/8842`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration closes Func `7105`'s entire `+22` raw/canonical body gap and all six body locals while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, fact reuse, and the strict `<=2x` controlled pass-local ceiling. The retained transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10459`; selected Funcs `7008`/`7007` retain `+1398` combined canonical body bytes and excess local get/set traffic. The next recursive iteration should derive exactly three further reduced/source-backed Type `309` branch-result/call transport or local-copy shapes from those two functions, reject any non-improving or over-`2x` endpoint, and keep validation-only or representation-only drift open unless a measured/source-backed Starshine benefit is proved.
