# DAEO selected copy/readback cleanup final matrix

Date: 2026-07-15

## Scope

This iteration advances Binaryen v130's `dae-optimizing` changed-function cleanup contract on only the accepted forwarding-component definitions from note `1611`. It retains three distinct measured, source-backed local shapes:

1. replace `struct.get; local.set x; local.get x` with `struct.get; local.tee x`;
2. apply the same stack-equivalent tee formation after a non-void value/type-index `block`;
3. remove an exact-type `local.get param; local.set body` copy when the parameter is unwritten, the body local has exactly one set and one suffix-dominated read, and no tees, then forward that read to the parameter and compact the exposed local.

The first two shapes do not move their producer. The third is the narrow no-nesting copy case described by Binaryen v130 `SimplifyLocals.cpp`: local-get copies can forward to the source local when the copy is proved and no tee is needed. All three run inside the existing per-definition deep-clone, selected-definition validation, and strict selected-function encoded-profitability transaction.

Plain `dead-argument-elimination` / `dae` remains separate. Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` immediately before `inlining-optimizing`.

## Binaryen source contract

Binaryen v130 records changed functions in `worthOptimizing` and calls `OptUtils::optimizeAfterInlining(...)` for `dae-optimizing` (`.tmp/DeadArgumentElimination-v130.cpp`). `.tmp/slns-v130-source/src/passes/opt-utils.h` runs a filtered `precompute-propagate` prefix plus the default function optimization sequence. `.tmp/slns-v130-source/src/passes/SimplifyLocals.cpp` specifically sinks local sets into reads, forms tees for retained values, and forwards local-get copies when nesting/tee constraints permit.

The retained Starshine behavior is narrower. It does not retry the non-improving whole `simplify-locals`, `simplify-locals-nostructure`, `local-cse`, `reorder-locals`, or `remove-unused-brs` adapters from note `1611`; it recognizes only the three measured artifact shapes above.

## Exactly three code-changing commits

1. `174c38941 feat: tee selected DAEO aggregate readbacks`
   - adds exactly one red-first aggregate-field readback fixture;
   - recursively converts selected `struct.get; local.set; local.get` readbacks to tees;
   - improves the direct artifact by `27` raw and `35` canonical bytes.
2. `aecf1988c feat: tee selected DAEO value-block readbacks`
   - adds exactly one red-first value-block readback fixture;
   - extends the same no-movement rewrite to non-void value/type-index blocks;
   - improves the direct artifact by another `6` raw and `6` canonical bytes.
3. `3533e37bd feat: forward selected DAEO immutable parameter copies`
   - adds exactly one red-first one-use immutable-parameter copy fixture;
   - reuses the existing recursive local-reference count scan, requires exact source/destination types, proves an unwritten parameter plus one destination set/read and suffix dominance, forwards the read, and exposes the destination local to the existing compactor;
   - improves the direct artifact by another `14` raw and `12` canonical bytes.

No fourth code-changing commit was made.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 3c70d5d24b0cb4aa0f4f8870290a2508eec9f9d3a14d575fe8e082225d5984c9
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
.tmp/daeo-copy-readback-final-20260715/starshine-direct-1.wasm
SHA-256 bbeb9f1db4153382c4059b706f3165e78ffcee0c53e5fe4ec4eb02edc536cd50
```

Canonical Binaryen-v130 roundtrip:

```text
.tmp/daeo-copy-readback-final-20260715/starshine-direct-1.canonical.wasm
SHA-256 2c6330247e433e2469dcc23b872901e9c3f25f7d6d91e940cabf50c3afcf052c
```

The second raw output and second canonical roundtrip are byte-identical. All retained outputs validate under `wasm-tools validate --features all`.

| dimension | note 1611 | final | Binaryen v130 | final delta vs Binaryen | change vs note 1611 |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3195518` | `3195471` | `3177421` | `+18050` | `-47` |
| canonical wasm | `3273130` | `3273077` | `3262456` | `+10621` | `-53` |
| DAEO pass-local, controlled run 1 | `16828.192ms` | `16691.744ms` | `8538.02ms` | `1.95x` | within `<=2x` |
| DAEO pass-local, controlled run 2 | `16523.429ms` | `16589.565ms` | `8538.02ms` | `1.94x` | within `<=2x` |

The final direct trace preserves the accepted-definition decisions:

```text
post-component-cleanup defs=[7008] passes=[coalesce-locals, vacuum, branch-only-if-to-br-if, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup defs=[7007] passes=[coalesce-locals, vacuum, remove-never-read-local-tees, compact-unused-locals]
post-component-cleanup-rollback reason=coalesce-validation-pass-or-encode defs=[7024]
post-component-cleanup-skip reason=non-improving-coalesce-encoded-size defs=[7010]
post-component-cleanup-skip reason=small-local-set defs=[7029]
```

The new copy/readback shapes are fused into the existing accepted local-cleanup candidate, so they add no second selected validation or profitability transaction.

## Function-body and local-traffic evidence

Only defined Funcs `7008` and `7007` account for the module reduction:

| defined func | note 1611 raw | final raw | Binaryen raw | note 1611 canonical | final canonical | Binaryen canonical | final canonical gap |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `7008` | `5191` | `5171` | `4294` | `5178` | `5160` | `4332` | `+828` |
| `7007` | `4344` | `4317` | `3746` | `4584` | `4549` | `3884` | `+665` |

The immutable-parameter forwarding removes two encoded body-local declarations from Func `7008` (`194 -> 192`); Func `7007` remains at `191` encoded body-local declarations. This declaration count is the code-body local vector, not the broader local-index/traffic count reported in note `1611`.

Across the printed pair, Starshine now has `955` `local.get`, `257` `local.set`, and `131` `local.tee` occurrences versus Binaryen's `915`, `169`, and `169`. Relative to note `1611`, the three shapes remove `18` gets and `18` sets while adding `16` tees. This is a measured parity reduction, but the remaining `+40` gets and `+88` sets still make the selected bodies larger; fewer Binaryen-side tees are not claimed as a Starshine win.

Canonical section payloads are:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2985470` | `2971947` | `+13523` |
| net module | `3273077` | `3262456` | `+10621` |

The direct code gap remains open. The next iteration should inspect the remaining exact selected-function spill/copy families, especially multi-result set sequences and repeated aggregate extraction, and retain them only with source-backed stack/control proofs plus strict selected-function wins.

## Required Binaryen-v130 direct matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-copy-readback-v130-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-copy-readback-v130-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-copy-readback-v130-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failures `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-copy-readback-v130-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

The `367` failure-directory names and all `3670` saved failure files are byte-identical to note `1611`. The established agent classification is unchanged: both families are measured/source-backed Starshine cleanup wins with aggregate deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no positive canonical/WAT case. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals.

## Plain DAE separation and exact-once public scheduling

A direct plain-DAE replay validates, emits exactly one `dead-argument-elimination` start/done pair, emits no `post-component-cleanup` trace, and takes `3439.858ms` pass-local. The selected copy/readback cleanup therefore remains optimizing-only.

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`.

Each mode:

- emits a valid `38`-byte module;
- reports exactly one DAEO start and one DAEO done;
- places the DAEO done line immediately before the `inlining-optimizing` start line.

DAEO timers are `690us` for optimize, `654us` for shrink, and `578us` for O4z.

The large stripped-artifact pre-slot blockers remain separate `[WALL]001` work from notes `1584` and `1611`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge` before reaching DAEO.

## Consolidated validation

Green validation after the three code-changing commits:

- `moon info` with existing warnings;
- `moon fmt`, with its unrelated `moon.mod` rewrite restored;
- three focused commit fixtures `1/1` each;
- full `moon test` `8833/8833`;
- native release build and SHA review;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`, redirected to `.tmp/daeo-copy-readback-final-20260715/validate-full.log`;
- no `.mbti` diff;
- direct raw/canonical validation and byte-identical repeats;
- complete four-lane explicit-native Binaryen-v130 matrix;
- exact-once public scheduling checks;
- direct plain-DAE separation check;
- `git diff --check`.

## Judgment and continuation

This iteration moves the direct goalpost in Starshine's favor by `47` raw and `53` canonical bytes while preserving validation, byte stability, generated semantic classifications, plain-DAE separation, exact-once public scheduling, strict selected-function profitability, and the `<=2x` controlled pass-local ceiling. The retained transformations reduce Binaryen's changed-function cleanup parity gap; they are not intentional Starshine divergences.

DAEO remains active. The direct canonical gap is `+10621`; selected Funcs `7008`/`7007` retain `+1493` combined canonical body bytes and excess local get/set traffic, while larger independent body owners from note `1611` remain. The next recursive iteration should derive exactly three further reduced/source-backed selected-function shapes, prefer one fused analysis/rewrite transaction, reject any non-improving or over-`2x` endpoint, and keep validation-only or representation-only drift open unless a measured/source-backed Starshine benefit is proved.
