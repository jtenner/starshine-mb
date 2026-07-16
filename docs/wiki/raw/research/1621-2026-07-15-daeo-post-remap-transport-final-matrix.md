# 1621 — DAEO post-remap transport final matrix

Date: 2026-07-15

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1620`](./1620-2026-07-15-daeo-remapped-carrier-cleanup-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first and scheduling tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live pass contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md), [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md), and [`fuzzing.md`](../../binaryen/passes/dae-optimizing/fuzzing.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and the single locked late DAEO preset slot. It extends only the optimizing post-component rewrite on the already-selected changed definitions.

The three retained exact shapes are:

1. sink a selected one-argument, single-result block carrier directly into its sole call consumer;
2. sink a selected terminal four-argument carrier while preserving the complete ordered argument stack;
3. forward a selected identity block carrier directly to its terminal consumer.

All three reuse the existing counted post-remap selected-function traversal, remapped local types and access counts, exact one-set/one-get/no-tee evidence, selected-definition validation, selected-function encoded-size profitability, and fail-closed rollback. No second full instruction scan, whole-module validation transaction, or whole-module encoding transaction was added.

Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` slot after late `heap-store-optimization` and immediately before `inlining-optimizing`.

## Exact code-commit contract

Starting point:

```text
9b17a07486b9dd8008d1eb8883b19ba39ff7f2c7
```

Exactly three code commits were retained:

1. `472c9d715 feat: sink selected DAEO one-argument block carriers`
   - red first: the focused fixture failed on the intentionally unbound helper before implementation;
   - exact one-set/one-get/no-tee block carrier with a single terminal call use;
   - direct delta: `-8` raw / `-8` canonical bytes.
2. `b47d5652f feat: sink selected DAEO terminal four-argument carriers`
   - red first: the focused fixture failed on the intentionally unbound helper before implementation;
   - preserves all four complete terminal arguments and their source order;
   - incremental direct delta: `-12` raw / `-12` canonical bytes.
3. `ba6e5c10b feat: forward selected DAEO identity block carriers`
   - red first: the focused fixture failed on the intentionally unbound helper before implementation;
   - exact identity block forwarding under the same remapped type/count guards;
   - incremental direct delta: `-9` raw / `-9` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiment

A split-argument block-carrier probe was measured and fully reverted. It enlarged the artifact from the note `1620` baseline to:

```text
raw:       3194830  (+34)
canonical: 3272372  (+64)
```

The rejected patch is retained locally at `.tmp/daeo-recursive-1621-20260715/rejected-split-arg-block.patch` for attribution only. Splitting the carrier away from its complete argument stack perturbs downstream selected cleanup and is a measured size-losing parity probe, not a safe representation difference. It must not be retried unchanged.

## Explicit native binary

All authoritative final direct and compare evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 d3c8e65cd95dea2240168e755438d73af9c656e96ee65b5dbfd4041dec09f4b1
```

Binaryen v130 is selected explicitly with:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

All generated compare lanes use both DAE normalizers, parallel workers, and the explicit native Starshine binary. Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Validation

Consolidated final validation after commit 3:

- `moon info`: passed with existing warnings;
- `moon fmt`: passed; `moon.mod` is restored to the repository's multiline `options(source: "src")` spelling;
- `moon test`: `8860/8860` passed;
- `moon build --target native --release src/cmd`: passed;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`: passed;
- no `.mbti` public-API diff exists.

## Direct artifact and Binaryen gap

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Final Starshine runs are deterministic and valid before and after Binaryen v130 canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194767` | `3272279` | raw `73fedae373b0d9103ed88b41d6d00ec6f775a73acef6b961048ba035311349ef`; canonical `7e3caa9f51dfb979aa362b72c7c6310f0933333c8f22228fa0a61fa94b7e55d4` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17346` | `+9823` | open parity gap |

Relative to note `1620`, this iteration improves the artifact by:

```text
raw:       3194796 -> 3194767  (-29)
canonical: 3272308 -> 3272279  (-29)
```

Each retained code commit independently reduces both raw and canonical size. Validation, fewer local operations, or a different valid output shape do not close the remaining direct gap.

## Controlled timing

The absolute controlled pass-local ceiling is:

```text
17076.04ms
```

Three clean final repeats with no competing side-work process in the retained before/after snapshots are:

```text
16654.333ms
16519.364ms
16618.874ms
```

All three are below the ceiling. Timing headroom remains narrow, so future work should remain fused into the existing selected traversal and profitability transaction.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-post-remap-transport-final-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-post-remap-transport-final-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-post-remap-transport-final-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle tool failures: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-post-remap-transport-final-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1620`. The established agent classification is unchanged:

```text
aggregate Starshine - Binaryen raw:       -110224 bytes
aggregate Starshine - Binaryen canonical: -797486 bytes
aggregate Starshine - Binaryen WAT:       -5465849 bytes
positive canonical cases:                 0
positive WAT cases:                       0
```

These two generated residual families remain measured/source-backed intentional Starshine cleanup wins. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

## Plain DAE separation

A fresh direct plain-DAE replay on the stripped artifact:

- validates;
- emits exactly one `pass[dae]:start` and one `pass[dae]:done`;
- emits no `pass[dae-optimizing]:start`;
- emits no post-component cleanup trace;
- measures `3434.181ms`;
- writes `3201276` bytes with SHA-256 `dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8`.

All three retained post-remap transport changes remain optimizing-only.

## Exact-once public scheduling

The dedicated-profile scheduling fixture was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`.

All three:

- validate;
- emit the same `38`-byte output;
- have SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- execute exactly one top-level `dae-optimizing` start/done pair;
- retain the locked late slot after `heap-store-optimization`;
- start `inlining-optimizing` immediately after `dae-optimizing:done`.

## Current Func `7007` / `7008` residual ranking

The current canonical artifact was rescanned for exact one-set/one-get/no-tee locals. The shortest remaining carriers, ranked by producer-to-consumer instruction distance, are:

```text
Func 7007: local 84=40, 85=40, 165=46, 166=46, 59=77, 60=77
Func 7008: local 60=85, 52=89, 29=128, 33=144, 34=161,
           127=162, 128=162, 129=162, 130=163, 126=167
```

The ranking is an investigation queue, not proof of profitability or semantic admissibility. Several leading shapes include structured control, aggregate field extraction, multiple complete call arguments, or ambient stack producers. The rejected split-argument probe demonstrates that local distance alone is insufficient: future slices must preserve complete value-producing stacks and measure direct raw and canonical output before retention.

## Remaining direct work

The direct gap remains:

```text
raw gap:       +17346
canonical gap: +9823
```

No generated semantic family is open. The next direct iteration should:

1. start from the current Func `7007` / `7008` exact-carrier ranking above and inspect complete producer/consumer stack slices;
2. prefer exact post-remap shapes that reuse the existing count/type/rewrite traversal and selected-function profitability path;
3. treat the split-argument block probe as a measured size-losing rollback and do not retry it unchanged;
4. retain plain `dae` separation and exactly one late DAEO preset slot;
5. stay below the absolute `17076.04ms` controlled ceiling;
6. rerun the complete explicit-native matrix, controlled timing, plain-DAE separation, and exact-once public scheduling after the next three measured code slices.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
