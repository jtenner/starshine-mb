# DAEO post-component function-filtered vacuum replay and final matrix

Date: 2026-07-15

## Scope

This iteration advances the source-backed Binaryen `optimizeAfterInlining` changed-function replay for the exact optimizing-only forwarding-component definitions from note `1609`. After a definition's isolated `coalesce-locals` candidate validates and proves a strict raw reduction, Starshine now probes function-filtered `vacuum` on that same definition. The vacuum candidate is deep-cloned, validated independently, and retained only for a further strict encoded-size reduction. A rejected vacuum candidate preserves the already accepted coalesce result.

Plain `dead-argument-elimination` remains separate and schedules none of this component cleanup. Public `optimize`, `shrink`, and `--optimize -O4z` still execute one late DAEO invocation immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 records changed functions in `worthOptimizing` and invokes `OptUtils::optimizeAfterInlining(...)` for `dae-optimizing` (`.tmp/DeadArgumentElimination-v130.cpp`). `.tmp/slns-v130-source/src/passes/opt-utils.h` implements that replay with a `FilteredPassRunner`, a `precompute-propagate` prefix, and default function optimization passes.

The retained Starshine slice remains narrower than the full upstream replay. It adds only the next measured cleanup family after accepted coalescing and never runs on all `46` broadly touched functions.

## Bounded implementation slices

The iteration contains three bounded code-changing commits after the workflow adjustment:

1. `2029de420 feat: replay vacuum after accepted DAEO coalescing`
   - runs vacuum only after coalesce validation and strict profitability;
   - keeps per-definition deep-clone isolation;
   - preserves the accepted coalesce result if vacuum errors, fails validation, cannot encode, or is non-improving;
   - never retries vacuum for the invalid coalesce candidate Func `7024`.
2. `4561c6561 perf: validate only probed DAEO component definitions`
   - replaces repeated validation of every unchanged function body with module-environment plus selected-defined-function validation;
   - keeps the out-of-range-local rollback regression.
3. `c01e80cf9 perf: prove DAEO cleanup wins from selected function bytes`
   - when the type section is unchanged, encodes only the selected function and requires a strict encoded-function reduction;
   - this is sufficient to prove the code section and module cannot grow, because shrinking one encoded function cannot increase the code-section payload or its length prefix;
   - retains full-module encoded-size comparison as the fallback when a candidate changes the type section.

The red public fixture was committed immediately before the workflow change as `ceb59c939 test: cover DAEO post-coalesce vacuum replay`. It proves the optimizing path removes coalesce-exposed `nop` debris while plain DAE retains its separate local shape. The subsequent workflow contract is recorded in the recursive handoff: future iterations use three code-changing commits with one focused test per shape, one consolidated matrix, one docs commit, and then recurse.

## Performance recovery

The first vacuum implementation moved the artifact but exceeded the pass-local ceiling because it added repeated whole-module validation and encoding:

| stage | DAEO pass-local |
|---|---:|
| initial coalesce + vacuum | `18818.329ms` |
| selected-definition validation | `18101.222ms` |
| selected-function profitability | `15652.661ms` |

The final authoritative direct repeats are `15775.580ms` and `15735.944ms` versus Binaryen v130 `8538.02ms`, or `1.85x` and `1.84x`. This restores the required `<=2x` pass-local bound without weakening validation of the selected candidate or raw profitability.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 a160cb5c201c7282a845d353455d862f35763c43f357fd21508b60b1ab31097e
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
.tmp/daeo-post-vacuum-final-20260715/starshine-direct.wasm
SHA-256 95cee30cb661ea97b5d670918cca2d6a4e6cf91372111d1245dbccdbaf335afd
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-post-vacuum-final-20260715/starshine-direct.canonical.wasm
SHA-256 6c54626c13447bf93b01d3e919bd0c0c9adc708ae9af53e9658aab0a717d6318
```

The repeat raw output and repeat canonical roundtrip are byte-identical. Both raw outputs validate under `wasm-tools validate --features all`.

| dimension | note 1609 | post-vacuum final | Binaryen v130 | final delta vs Binaryen | change vs note 1609 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3196705` | `3196657` | `3177421` | `+19236` | `-48` |
| canonical wasm | `3274365` | `3274317` | `3262456` | `+11861` | `-48` |
| DAEO pass-local, retained run | `15501.032ms` | `15775.580ms` | `8538.02ms` | `1.85x` | within `<=2x` |
| DAEO pass-local, byte-identical repeat | `15737.564ms` | `15735.944ms` | `8538.02ms` | `1.84x` | within `<=2x` |

The final direct trace reports:

```text
post-component-cleanup defs=[7008, 7007] passes=[coalesce-locals, vacuum]
post-component-cleanup-rollback reason=coalesce-validation-pass-or-encode defs=[7024]
post-component-cleanup-skip reason=non-improving-coalesce-encoded-size defs=[7010]
post-component-cleanup-skip reason=small-local-set defs=[7029]
nested-cleanup-skip reason=large-touched-set touched=46
```

Agent judgment:

- Funcs `7008` and `7007` retain a source-backed parity reduction under Binaryen's changed-function optimization contract;
- Func `7024` remains fail-closed and never reaches vacuum because its coalesce candidate is invalid;
- Func `7010` remains unchanged because coalescing is not strictly profitable;
- Func `7029` remains below the local floor;
- no invalid, non-improving, or small-function candidate is retained.

## Function-body deltas

Only two canonical bodies change relative to note `1609`:

| defined func | note 1609 canonical body | final canonical body | Binaryen body | final delta vs Binaryen | change vs note 1609 |
|---:|---:|---:|---:|---:|---:|
| `7008` | `5870` | `5854` | `4332` | `+1522` | `-16` |
| `7007` | `5127` | `5095` | `3884` | `+1211` | `-32` |

Raw bodies change from `5866 -> 5850` for Func `7008` and `4856 -> 4824` for Func `7007`. No other canonical body changes. The full `-48` module improvement is therefore attributed to the exact accepted component definitions, with no hidden positive body regression.

The post-vacuum printed pair contains zero `nop` instructions. It still has substantially more local traffic than Binaryen (`275` vs `169` printed `local.set` occurrences and `973` vs `915` `local.get` occurrences across the two functions), so the local-copy family remains a parity gap rather than a Starshine win.

## Ranked remaining canonical difference

Canonical section payloads:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2986710` | `2971947` | `+14763` |
| net module | `3274317` | `3262456` | `+11861` |

Largest positive canonical body deltas now are:

| rank | defined func | Starshine body | Binaryen body | delta |
|---:|---:|---:|---:|---:|
| 1 | `7008` | `5854` | `4332` | `+1522` |
| 2 | `8429` | `27190` | `25742` | `+1448` |
| 3 | `41` | `6703` | `5417` | `+1286` |
| 4 | `9347` | `16685` | `15405` | `+1280` |
| 5 | `8187` | `2217` | `961` | `+1256` |
| 6 | `7007` | `5095` | `3884` | `+1211` |
| 7 | `7556` | `6158` | `5025` | `+1133` |
| 8 | `6377` | `4185` | `3153` | `+1032` |
| 9 | `8185` | `3413` | `2429` | `+984` |
| 10 | `7919` | `3085` | `2101` | `+984` |

DAEO remains active. Vacuum closes the exposed `nop` family but not the larger local-copy/control gap in Funcs `7008` and `7007` or the independent ranked owners.

## Required direct matrix

### Dedicated `dae-optimizing` profile

```text
.tmp/pass-fuzz-daeo-post-vacuum-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-post-vacuum-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-post-vacuum-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, and `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-post-vacuum-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

The `367` failure-directory names are identical to note `1609`. All `2202` compared saved semantic Starshine/Binaryen raw/canonical/WAT artifacts are byte-identical. The established agent classification therefore remains unchanged:

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

DAEO timers are `661us` for optimize, `622us` for shrink, and `529us` for O4z.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Validation

Green consolidated validation after all three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- focused public post-coalesce vacuum fixture `1/1`;
- focused selected-definition rollback fixture `1/1`;
- focused selected-function profitability fixture `1/1`;
- full `moon test` `8827/8827`;
- native release build;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct output validation and byte-identical repeat;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- `git diff --check`.

## Judgment and continuation

This iteration moves the direct goalpost in Starshine's favor by `48` raw and `48` canonical bytes while preserving zero validation/true-semantic failures, exact plain-DAE separation, exact-once public scheduling, and the `<=2x` pass-local ceiling. The retained difference is a source-backed parity reduction, not a declared Starshine divergence.

The direct canonical gap remains `+11861`. Funcs `7008` and `7007` still contain excess local copy traffic after vacuum. The next source-backed cleanup probe should begin with function-filtered `simplify-locals` or `local-cse` on only the already accepted component definitions, selected by a reduced fixture and measured body evidence. It must preserve deep-clone isolation, selected-definition validation, strict selected-function profitability, and full-module fallback when type sections change. It must not retry Func `7024`, blanket-run on all `46` touched definitions, or weaken nondefaultable/oversized safety boundaries.
