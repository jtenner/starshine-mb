# 1620 — DAEO remapped carrier cleanup final matrix

Date: 2026-07-15

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1619`](./1619-2026-07-15-daeo-complete-carrier-cleanup-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first and scheduling tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live pass contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md) and [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and extends only the optimizing post-component cleanup on the already-selected changed definitions.

The retained changes run in the existing counted post-remap readback traversal:

1. sink the first exact one-use result in two-producer dispatch arms while preserving both complete direct-call producer slices in their original order;
2. sink both exact one-use stored results in three-producer dispatch arms while preserving all three complete producer slices in their original order;
3. sink exact typed single-result `block i32` carriers through the pure leading zero of terminal `struct.new; return` shapes.

The first two rewrites move only pure caller-local reads before direct calls. Direct calls cannot observe or mutate the caller's locals, and every producer call remains ordered. The terminal block rewrite treats the structured producer as one complete stack-value boundary, requires exact local type/count evidence, and preserves all nested control, calls, traps, and effects inside that block.

The third change emits remapped local types during the already-running local-compaction loop, alongside remapped get/set/tee counts. It adds no second type/count loop, instruction scan, selected-definition validation, or encoding transaction.

Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` slot after `heap-store-optimization` and immediately before `inlining-optimizing`.

## Exact code-commit contract

Starting point:

```text
6568ef50c docs: record DAEO complete carrier cleanup signoff
```

Exactly three code commits were retained:

1. `6001a8252 feat: sink selected DAEO first sibling results`
   - red-first fixture: `DAEO selected readback traversal sinks the first two-producer result`;
   - exact one-set/one-get/no-tee target and two identical complete producer call slices;
   - direct delta: `-8` raw / `-8` canonical bytes.
2. `e5a1a9c97 feat: sink selected DAEO paired sibling results`
   - red-first fixture: `DAEO selected readback traversal sinks two three-producer results`;
   - two distinct exact one-set/one-get/no-tee targets and three identical complete producer call slices;
   - direct delta: `-16` raw / `-16` canonical bytes.
3. `003f50e42 feat: sink selected DAEO terminal block carriers`
   - red-first fixture: `DAEO selected readback traversal sinks typed terminal block carriers`;
   - exact `ValTypeBlockType`/target-type equality plus one-set/one-get/no-tee evidence;
   - remapped types are emitted during existing compaction and reused recursively;
   - direct delta: `-16` raw / `-16` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiments and non-authoritative runs

The following probes were reverted or excluded from signoff:

- a pre-remap complete `block i32` carrier move across three immutable arguments reproduced the known rollback endpoint raw `3194964` / canonical `3272572`; moving the same visible block boundary before compaction perturbs the larger selected cleanup product and is not profitable;
- the typed post-remap three-argument block carrier also regressed to raw `3194854` / canonical `3272404`; it was fully reverted;
- two first compare attempts omitted `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt` and accidentally selected the TinyGo-provided `wasm-opt`, producing non-authoritative Binaryen command-failure counts. The authoritative wasm-smith and random-all lanes were rerun explicitly with Binaryen v130.

These failures reinforce two constraints: evaluate carrier transport in the exact phase where the profitable shape exists, and select the Binaryen v130 executable explicitly for every oracle lane.

## Explicit native binary

All authoritative final direct and compare evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 65429e4aa549bda3e427d41d3e6ee94e46185f709499031cab9887e0652aef12
```

Binaryen v130 is selected explicitly with:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

All generated compare lanes use:

```text
--normalize drop-consts --normalize unreachable-control-debris
--jobs auto
--starshine-bin _build/native/release/build/cmd/cmd.exe
```

Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Validation

Consolidated final validation after commit 3:

- `moon info`: passed with existing warnings;
- `moon fmt`: passed; the unrelated `moon.mod` spelling rewrite was restored;
- `moon test`: `8857/8857` passed;
- `moon build --target native --release src/cmd`: passed;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`: passed;
- full profile highlights include `binary-roundtrip=86820` and `cmd-harness=4096`, all passing;
- no `.mbti` public-API diff exists.

## Direct artifact and Binaryen gap

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Two final Starshine runs are byte-identical and validate before and after Binaryen v130 canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194796` | `3272308` | raw `247b8c4f109626d992d682e917e348d7cea58a4e2ead2354d6c13d3e1811865d`; canonical `aaa213a06dce83fe9974c602f398b7f0b2fdefc9e1bc0da48f228dc4cdf48c15` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17375` | `+9852` | open parity gap |

Relative to note `1619`, this iteration improves the artifact by:

```text
raw:       3194836 -> 3194796  (-40)
canonical: 3272348 -> 3272308  (-40)
```

No remaining direct raw/canonical/function-shape residual is accepted merely because both outputs validate, Starshine is smaller somewhere else, or Starshine uses fewer local operations. The `+9852` canonical gap remains open.

## Controlled timing

Binaryen v130 reference remains:

```text
8538.02ms
```

Two retained final pass-local repeats with no `starshine-sidework` Moon/TinyGo/compiler process in the before/after snapshots are:

```text
16804.456ms  (1.97x Binaryen)
16971.806ms  (1.99x Binaryen)
```

Both are below the absolute `17076.04ms` ceiling. A compiler-contaminated attempt measured `18468.856ms`; another attempt overlapped a recurring side-work compiler at `17564.196ms`. A no-sidework but noisy repeat measured `17202.748ms` and was not selected as one of the controlled repeat pair; the two retained repeats and their median remain below the ceiling, but timing headroom is still narrow.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-remapped-carriers-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-remapped-carriers-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-remapped-carriers-final2-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle tool failures: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-remapped-carriers-final2-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1619`. The existing agent classification is therefore unchanged:

```text
aggregate Starshine - Binaryen raw:       -110224 bytes
aggregate Starshine - Binaryen canonical: -797486 bytes
aggregate Starshine - Binaryen WAT:       -5465849 bytes
positive canonical cases:                 0
positive WAT cases:                       0
```

These two generated residual families remain measured/source-backed intentional Starshine cleanup wins. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals in the authoritative matrix.

## Plain DAE separation

A fresh direct plain-DAE replay on the stripped artifact:

- validates;
- emits exactly one `pass[dae]:start` and one `pass[dae]:done`;
- emits no `pass[dae-optimizing]:start`;
- emits no `post-component-cleanup` trace;
- measures `3810.933ms` pass-local;
- writes `3201276` bytes with SHA-256 `dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8`.

All three retained remapped-carrier changes remain optimizing-only.

## Exact-once public scheduling

The first final dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`.

All three:

- validate;
- emit the same `38`-byte output;
- have SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- execute exactly one top-level `dae-optimizing` start/done pair;
- place the late `heap-store-optimization` skip/start trace immediately before DAEO;
- place `inlining-optimizing:start` immediately after `dae-optimizing:done`.

## Remaining direct work

The direct gap is not eliminated:

```text
raw gap:       +17375
canonical gap: +9852
```

No new generated residual family is open. The large artifact still contains unproved direct output-shape gaps, including surviving one-use locals and block/control carriers in Func `7008` and Func `7007`.

The next iteration should:

1. regenerate current canonical Func `7008` / Func `7007` diffs from native SHA-256 `65429e4a...` and rank the remaining exact post-remap set/get families by direct raw/canonical payoff;
2. prefer post-remap shapes whose profitable form exists after compaction; the pre-remap large `block i32` three-argument transport is a measured rollback and must not be retried unchanged;
3. retain exactly three red-first code commits, each with selected local count/type/effect/control guards and a real direct improvement;
4. reuse the existing counted traversal, selected-definition validation, and selected-function profitability path without another full scan or encoding/validation transaction;
5. rerun the complete direct matrix with explicit `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, controlled timing, plain-DAE separation, and exact-once scheduling.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
