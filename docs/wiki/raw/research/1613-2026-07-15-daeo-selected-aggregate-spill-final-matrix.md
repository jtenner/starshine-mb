# DAEO selected aggregate-spill cleanup final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130's `dae-optimizing` changed-function cleanup contract on the accepted forwarding-component definitions from note `1612`. It retains exactly three distinct measured, source-backed aggregate-local shapes:

1. collapse a two-field non-null aggregate extraction sequence when both adjacent `struct.get` results are stored to one-use locals and immediately read back in extraction order;
2. in an exact four-field extraction cluster whose readback order is field `2, 0, 1, 3`, sink field `2` past the adjacent field `3` read and remove only the first readback temporary;
3. on that residual four-field shape, move the already-unspilled field `2` read to the stack-leading position and remove the remaining field `0`, `1`, and `3` one-use spills.

All reads are adjacent `struct.get` operations on the same proven non-null aggregate with one common struct type and no intervening call, mutation, or other effect. The first shape does not move a producer. The latter two apply Binaryen's SimplifyLocals sinking contract only across adjacent nontrapping field reads. Every removed temporary has exactly one set, one get, and no tee. The rewrites update the existing local-reference counts and expose declarations to the existing compactor in the same traversal.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 records changed functions in `worthOptimizing` and calls `OptUtils::optimizeAfterInlining(...)` for `dae-optimizing` (`.tmp/DeadArgumentElimination-v130.cpp`). `.tmp/slns-v130-source/src/passes/opt-utils.h` runs a filtered `precompute-propagate` prefix plus the default function optimization sequence. `.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp` sinks local sets into their reads when effect ordering permits, removes one-use stores, and forms tees for retained values.

The retained Starshine behavior is narrower. It recognizes only the exact adjacent non-null aggregate clusters measured here. It does not generalize across calls, stores, nullable aggregates, mixed aggregate types, repeated target locals, or targets without exact one-set/one-get/no-tee counts.

## Exactly three code-changing commits

1. `410af02d4 feat: collapse selected DAEO two-field aggregate spills`
   - adds exactly one red-first focused two-field fixture;
   - preserves both field-read producer positions and removes two balanced set/get pairs;
   - improves the direct artifact by `27` raw and `27` canonical bytes.
2. `696688ebb feat: forward selected DAEO reordered aggregate leaders`
   - adds exactly one red-first focused four-field leader fixture;
   - sinks only the field-2 leader past adjacent field 3 and removes its temporary;
   - improves the direct artifact by another `14` raw and `14` canonical bytes.
3. `d718e33cc feat: collapse selected DAEO residual aggregate spills`
   - adds exactly one red-first focused residual four-field fixture;
   - composes the residual field-0/field-1/field-3 collapse in the same traversal and removes the remaining three temporaries;
   - improves the direct artifact by another `42` raw and `42` canonical bytes.

No fourth code-changing commit was made.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 bd381c2c17f08b8f97213fa04e2e721e5a4367c4864edbb47eaff97498d8b4fb
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
.tmp/daeo-aggregate-spill-final-20260715/starshine-direct-1.wasm
SHA-256 fa85d569d27484b4c91e2dc0e61048034e2345c1e33397e8d8af84cd8728e8be
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-aggregate-spill-final-20260715/starshine-direct-1.canonical.wasm
SHA-256 a77ac36ee14e53b8a679fd5f8b2f171280bdda3b2617a854c13d29a79e819b81
```

The second raw output and second canonical roundtrip are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1612 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1612 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195471` | `3195388` | `3177421` | `+17967` | `-83` |
| canonical wasm | `3273077` | `3272994` | `3262456` | `+10538` | `-83` |
| DAEO pass-local, controlled run 1 | `16691.744ms` | `16394.952ms` | `8538.02ms` | `1.92x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16589.565ms` | `16537.075ms` | `8538.02ms` | `1.94x` | within `<=2x` |

The final direct trace preserves the accepted-definition decisions:

```text
post-component-cleanup defs=[7008] passes=[coalesce-locals, vacuum, branch-only-if-to-br-if, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup defs=[7007] passes=[coalesce-locals, vacuum, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup-rollback reason=coalesce-validation-pass-or-encode defs=[7024]
post-component-cleanup-skip reason=non-improving-coalesce-encoded-size defs=[7010]
post-component-cleanup-skip reason=small-local-set defs=[7029]
```

The aggregate-spill shapes are fused into the existing accepted local-cleanup candidate. They add no second selected validation or profitability transaction.

## Function-body and local-traffic evidence

Only defined Func `7008` accounts for this iteration's module reduction; Func `7007` remains byte-identical to note `1612`.

| defined func | note 1612 raw | final raw | Binaryen raw | note 1612 canonical | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `7008` | `5171` | `5088` | `4294` | `5160` | `5077` | `4332` | `+745` |
| `7007` | `4317` | `4317` | `3746` | `4549` | `4549` | `3884` | `+665` |

The aggregate spill collapse removes twelve encoded raw body-local declarations from Func `7008` (`192 -> 180`). Func `7007` remains at `191` encoded raw body-local declarations. Canonical roundtripping expands equivalent local type groups differently (`200` and `255` declarations respectively), so raw body-local counts are the stable comparison for this iteration.

Across the printed pair, Starshine now has `943` `local.get`, `245` `local.set`, and `131` `local.tee` occurrences versus Binaryen's `915`, `169`, and `169`. Relative to note `1612`, this removes `12` gets and `12` sets without adding tees. The remaining `+28` gets / `+76` sets still make the selected bodies larger; fewer Binaryen-side tees are not claimed as a Starshine win.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2985387` | `2971947` | `+13440` |
| net module | `3272994` | `3262456` | `+10538` |

The direct code gap remains open. The next iteration should inspect the four-result `Type 309` branch-result spills immediately following the now-collapsed aggregate extraction clusters, plus the remaining Func `7007` structured local traffic. Any retained rewrite must prove exact stack order, control dominance, local types, and Binaryen source behavior before measuring a strict selected-function win.

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-aggregate-spill-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-aggregate-spill-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-aggregate-spill-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-aggregate-spill-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1612`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay validates, emits exactly one `dae` start/done pair, emits no `post-component-cleanup` trace, and takes `3655.659ms` pass-local. The selected aggregate-spill cleanup therefore remains optimizing-only.

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done event immediately before the `inlining-optimizing` start event.

DAEO timers are `693us` for optimize, `648us` for shrink, and `564us` for O4z.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work from notes `1584`, `1611`, and `1612`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- three focused commit fixtures `1/1` each;
- full `moon test` `8836/8836`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`, redirected to `.tmp/daeo-aggregate-spill-final-20260715/validate-full.log`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration moves the direct goalpost in Starshine's favor by `83` raw and `83` canonical bytes while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, strict selected-function profitability, and the `<=2x` controlled pass-local ceiling. The retained transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10538`; selected Funcs `7008`/`7007` retain `+1410` combined canonical body bytes and excess local get/set traffic, while the larger independent body owners from note `1611` remain. The next recursive iteration should derive exactly three further reduced/source-backed selected-function shapes, beginning with the surviving four-result branch spill/call argument sequence after the aggregate clusters, reject any non-improving or over-`2x` endpoint, and keep validation-only or representation-only drift open unless a measured/source-backed Starshine benefit is proved.
