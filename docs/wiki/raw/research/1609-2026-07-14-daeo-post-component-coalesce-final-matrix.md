# DAEO post-component function-filtered coalesce replay and final matrix

Date: 2026-07-14

## Scope

This iteration reduced the first remaining DAE-owned canonical body gap identified by note `1608`: changed forwarding-component definitions were not receiving Binaryen's source-mandated post-DAE function optimization replay because Starshine skipped the full nested lane at `touched=46`.

The retained slice does not enable cleanup across all touched functions. It carries only the exact definition set returned by the optimizing-only forwarding-component transaction and probes `coalesce-locals` one function at a time. Each probe:

- requires at least `16` body locals;
- deep-clones the selected structured body so a rejected probe cannot mutate the retained module through shared nested arrays;
- runs only the function-filtered coalesce adapter;
- validates the whole candidate module;
- re-encodes the candidate and requires a strict raw module-size reduction;
- retains that one function or rolls it back independently.

Plain `dead-argument-elimination` remains separate and schedules none of this cleanup. Public optimize, shrink, and `--optimize -O4z` retain one late DAEO invocation immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 records changed functions in `worthOptimizing` and invokes `OptUtils::optimizeAfterInlining(...)` for `dae-optimizing` (`.tmp/DeadArgumentElimination-v130.cpp`, lines around `345-346`, `399`, `460`, and `533-534`). `.tmp/slns-v130-source/src/passes/opt-utils.h` implements that replay with a `FilteredPassRunner`, prepends `precompute-propagate`, and then runs the default function optimization passes.

The retained Starshine slice is narrower than that complete replay, but it follows the same changed-function filtering contract. `coalesce-locals` was selected because canonical Funcs `7008` and `7007` had hundreds of retained local slots while Binaryen's optimized bodies used far fewer slots. A global `--coalesce-locals` probe was rejected: it ran for about `388s` and produced an invalid local index in unrelated Func `64`. The retained implementation therefore does not broaden module-wide coalescing.

## Red-first coverage

Commit `f091b45d8` added:

- a public DAEO fixture with a forwarding-only parameter component plus nine unrelated dead-parameter helpers, forcing the broad nested scheduler to report `large-touched-set` while the component's high-local function still needs cleanup;
- a fail-closed validation transaction invariant.

The first focused run failed because `run_hot_pipeline_dae_validate_or_rollback` did not exist. The final public fixture proves:

- the forwarding component still removes only its proved parameters;
- the broad touched-set replay remains skipped;
- the high-local component function receives bounded post-component cleanup;
- small component functions are skipped rather than paying for or retaining non-improving cleanup.

The private rollback invariant moved to `pass_manager_wbtest.mbt`, where it constructs an invalid out-of-range `local.get` candidate and requires the original module to be returned unchanged.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 08de8a60b632d3a0b77b2033712f31b581992a31ad8244aee20a7cef990296ac
```

All authoritative compare lanes use Binaryen v130 through:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

They also use `--jobs auto`, the explicit native Starshine binary, and both DAE normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

Two earlier probe directories without the explicit `WASM_OPT_BIN` environment selected the unrelated default `wasm-opt` on `PATH` and produced non-authoritative command-failure counts. They are intentionally excluded from every result below; only the `v130-final-*` directories are authoritative.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-post-component-filtered-20260714/starshine-direct.wasm
SHA-256 537a2eb96801d4c8c9f8712a66a365bf525c88f50879308a42802cb6c57d3850
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-post-component-filtered-20260714/starshine-direct.canonical.wasm
SHA-256 7499729045b06f8561e5c01a26e93a333193836138f23f7b29308c5564c9af8b
```

The repeat direct output and repeat canonical roundtrip are byte-identical. Both direct outputs validate under `wasm-tools validate --features all`.

| dimension | note 1608 | post-component final | Binaryen v130 | final delta vs Binaryen | change vs note 1608 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3197221` | `3196705` | `3177421` | `+19284` | `-516` |
| canonical wasm | `3274791` | `3274365` | `3262456` | `+11909` | `-426` |
| DAEO pass-local, retained run | `13003.761ms` | `15501.032ms` | `8538.02ms` | `1.82x` | within `<=2x` |
| DAEO pass-local, byte-identical repeat | — | `15737.564ms` | `8538.02ms` | `1.84x` | within `<=2x` |

The direct trace reports:

```text
post-component-cleanup defs=[7008, 7007] passes=[coalesce-locals]
post-component-cleanup-rollback reason=validation-pass-or-encode defs=[7024]
post-component-cleanup-skip reason=non-improving-encoded-size defs=[7010]
post-component-cleanup-skip reason=small-local-set defs=[7029]
nested-cleanup-skip reason=large-touched-set touched=46
```

Agent judgment:

- Funcs `7008` and `7007` are retained parity reductions under Binaryen's changed-function optimization contract;
- Func `7024` remains fail-closed because its isolated coalesce candidate does not validate;
- Func `7010` remains unchanged because the valid candidate does not strictly reduce encoded size;
- Func `7029` remains unchanged because its body-local set is below the bounded replay floor;
- no invalid, non-improving, or small-function candidate is retained.

## Function-body deltas

Only two canonical bodies change relative to note `1608`:

| defined func | note 1608 canonical body | final canonical body | Binaryen body | final delta vs Binaryen | change vs note 1608 |
|---:|---:|---:|---:|---:|---:|
| `7008` | `6096` | `5870` | `4332` | `+1538` | `-226` |
| `7007` | `5327` | `5127` | `3884` | `+1243` | `-200` |

Raw body deltas are `-262` for Func `7008` and `-254` for Func `7007`. Funcs `7010`, `7024`, and `7029` are byte-identical to note `1608` in both retained raw and canonical outputs.

The `-426` canonical module improvement is therefore entirely attributed to the two source-backed changed component functions. There is no hidden positive canonical body regression elsewhere.

## Ranked remaining canonical difference

Canonical section payloads:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2986758` | `2971947` | `+14811` |
| net module | `3274365` | `3262456` | `+11909` |

Largest positive canonical body deltas now are:

| rank | defined func | Starshine body | Binaryen body | delta |
|---:|---:|---:|---:|---:|
| 1 | `7008` | `5870` | `4332` | `+1538` |
| 2 | `8429` | `27190` | `25742` | `+1448` |
| 3 | `41` | `6703` | `5417` | `+1286` |
| 4 | `9347` | `16685` | `15405` | `+1280` |
| 5 | `8187` | `2217` | `961` | `+1256` |
| 6 | `7007` | `5127` | `3884` | `+1243` |
| 7 | `7556` | `6158` | `5025` | `+1133` |
| 8 | `6377` | `4185` | `3153` | `+1032` |
| 9 | `8185` | `3413` | `2429` | `+984` |
| 10 | `7919` | `3085` | `2101` | `+984` |

The first local-declaration/coalescing family is reduced but not closed. Funcs `7008` and `7007` remain direct parity gaps, now alongside the previously open `8429`, `41`, `9347`, and other ranked bodies. The retained coalesced bodies visibly expose `nop` and remaining local-copy/control debris, so the next bounded source-backed probe should begin with function-filtered `vacuum` after accepted coalescing, with the same deep-clone, validation, and strict profitability gates. It must not run cleanup across all 46 touched functions.

## Required direct matrix

### Dedicated `dae-optimizing` profile

```text
.tmp/pass-fuzz-daeo-post-component-v130-final-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-post-component-v130-final-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-post-component-v130-final-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, and `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-post-component-v130-final-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

The `367` failure-directory names are identical to note `1608`. All `2202` compared saved semantic Starshine/Binaryen raw/canonical/WAT artifacts are byte-identical to note `1608`. The established agent classification therefore remains unchanged:

- `coverage-forced-portable=243` measured/source-backed Starshine cleanup wins;
- `dae-effectful-args=124` measured/source-backed Starshine cleanup wins;
- aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes;
- no canonical/WAT-positive case;
- no unknown/risky, size-losing generated, Starshine validation, or true-semantic residual.

## Exact-once public scheduling

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places DAEO done immediately before `inlining-optimizing` start.

DAEO timers:

- optimize: `1191us`;
- shrink: `1366us`;
- O4z: `1168us`.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Validation

Green final validation:

- `moon info` with existing warnings;
- `moon fmt`, with the unrelated `moon.mod` rewrite restored;
- focused public post-component fixture `1/1`;
- focused rollback white-box fixture `1/1`;
- full `dae_optimizing_test.mbt` `330/330`;
- full `moon test` `8826/8826`;
- native release build;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct output validation and byte-identical repeat;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- `git diff --check`.

## Judgment and continuation

This iteration retains a measured, source-backed parity reduction: exact changed-function filtering plus per-function rollback and strict raw profitability remove `516` raw and `426` canonical bytes without validation, scheduling, generated-semantic, or pass-local-target regression.

DAEO remains active. The direct canonical gap is now `+11909`, and Funcs `7008`/`7007` remain among the largest code owners. The next iteration should preserve the accepted coalesce stage and probe the next default-function cleanup family on exactly those accepted definitions, beginning with function-filtered `vacuum` to remove coalesce-exposed `nop`/copy debris. Retain a probe only when it validates, strictly improves the artifact without a per-function canonical regression, and keeps DAEO within `<=2x` Binaryen. Plain DAE separation, the broad touched-set guard, oversized/nondefaultable safety, and exact-once late public scheduling remain mandatory.
