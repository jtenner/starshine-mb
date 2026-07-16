# 1622 — DAEO pair-store transport final matrix

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1621`](./1621-2026-07-15-daeo-post-remap-transport-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first and scheduling tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live pass contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md), [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md), and [`fuzzing.md`](../../binaryen/passes/dae-optimizing/fuzzing.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and the single locked late DAEO preset slot. It extends only the optimizing post-component rewrite on the already-selected changed definitions.

The three retained exact shapes are:

1. forward the first result of a two-call, two-result typed block directly into the first of two paired `struct.set` consumers while keeping the second result in its original spill;
2. apply the same stack-preserving paired-store transport to the one-call producer sibling;
3. sink an exact single-result block through a pure leading zero into a terminal wrapper call, `struct.new`, and `return`.

The paired-store transport moves only the first receiver's nontrapping `local.get` before the complete producer. It requires exact one-set/one-get/no-tee evidence for both produced locals, rejects producer writes to the moved receiver, preserves producer call/trap/result order, and leaves the second spill unchanged. The terminal-call transport moves only `i32.const 0` before the complete producer and requires exact remapped type plus one-set/one-get/no-tee evidence.

All three reuse the existing counted post-remap selected-function traversal, remapped local types/counts, selected-definition validation, selected-function encoded-size profitability, and fail-closed rollback. No second full instruction scan, whole-module validation transaction, or whole-module encoding transaction was added.

Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` slot after late `heap-store-optimization` and immediately before `inlining-optimizing`.

## Exact code-commit contract

Starting point:

```text
90013c1db7c8cc81807e3cf8a633bc5306cac474
```

Exactly three code commits were retained:

1. `3f00abf23 feat: forward selected DAEO two-call pair-store carriers`
   - red first: the focused fixture failed on the intentionally unbound two-call helper;
   - complete two-call producer plus paired-store result ordering;
   - direct delta: `-6` raw / `-6` canonical bytes.
2. `7632c6b1e feat: forward selected DAEO one-call pair-store carriers`
   - red first: the focused fixture failed on the intentionally unbound one-call helper;
   - reuses the same exact pair-store transaction with one producer call;
   - incremental direct delta: `-6` raw / `-6` canonical bytes.
3. `f7376fb62 feat: sink selected DAEO terminal call block carriers`
   - red first: the focused fixture failed on the intentionally unbound terminal-call helper;
   - moves only a pure zero before the complete typed producer and preserves wrapper/construction/return order;
   - incremental direct delta: `-2` raw / `-2` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiments

The note `1621` split-argument block-carrier patch was not retried unchanged.

Two narrower attribution probes applied that split-argument rewrite separately to the current Func `7008` local `52` and local `60` candidates. Each independently enlarged the artifact to:

```text
raw:       3194794  (+27 from note 1621)
canonical: 3272318  (+39 from note 1621)
```

Both probes were fully reverted and are retained locally at `.tmp/daeo-recursive-1622-20260715/rejected-split-singletons.patch`. The result confirms that the split consumer-argument family remains size-losing even when isolated; it is not a hidden profitable subset and must not be retried unchanged.

## Explicit native binary

All authoritative final direct and compare evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 c24dfe348a0e28b6583380a880371e1c7868657e0b2fbcdb46973650171995e9
```

Binaryen v130 is selected explicitly with:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

All generated compare lanes use both DAE normalizers, parallel workers, and the explicit native Starshine binary. Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Validation

Consolidated final validation after commit 3:

- `moon info`: passed with existing warnings;
- `moon fmt`: passed; `moon.mod` was restored to the repository's multiline `options(source: "src")` spelling after formatting/validation commands;
- `moon test`: `8863/8863` passed;
- `moon build --target native --release src/cmd`: passed;
- `bun validate full --profile ci --target wasm-gc --seed 1784151000000000`: passed;
- no `.mbti` public-API diff exists.

## Direct artifact and Binaryen gap

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Final Starshine output is valid before and after Binaryen v130 canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194753` | `3272265` | raw `fa4102a7f83db1066d0a9381805b2c8c29ddac8fd3cec6bc6c99bf53cf596d38`; canonical `917c25f38db2b55992f49e4a1a7d4c220a75010b9da6bce909a53ab57c445b59` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17332` | `+9809` | open parity gap |

Relative to note `1621`, this iteration improves the artifact by:

```text
raw:       3194767 -> 3194753  (-14)
canonical: 3272279 -> 3272265  (-14)
```

Each retained code commit independently reduces both raw and canonical size. Validation, fewer local operations, or a different valid output shape do not close the remaining direct gap.

## Controlled timing

The absolute controlled pass-local ceiling is:

```text
17076.04ms
```

The final quiescent repeats whose before/after process snapshots contain no competing Moon, pass-fuzz, Starshine, or side-work process are:

```text
16831.058ms
16767.293ms
16948.172ms
```

All three are below the ceiling. Earlier warm/contention probes are not used as signoff evidence; one unrelated side-work Moon test was explicitly allowed to finish before the retained final sequence. Timing headroom remains narrow, so future work should remain fused into the existing selected traversal and profitability transaction.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-pair-store-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-pair-store-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-pair-store-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle tool failures: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-pair-store-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1621`. The established agent classification is unchanged:

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
- measures `3627.753ms`;
- writes `3201276` bytes with SHA-256 `dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8`.

All three retained pair-store/terminal-call changes remain optimizing-only.

## Exact-once public scheduling

The current dedicated-profile scheduling fixture was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`.

All three:

- validate;
- emit the same `38`-byte output;
- have SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- execute exactly one top-level `dae-optimizing` start/done pair;
- retain the locked late slot after `heap-store-optimization`;
- start `inlining-optimizing` immediately after `dae-optimizing:done`.

## Current Func `7007` / `7008` residual ranking

A fresh raw selected-function scan after the three retained changes gives:

```text
Func 7007: local 166=46, 64=73, 59=77, 60=77, 65=142,
           81=145, 158=148, 159=148, 169=148, 170=148, ...
Func 7008: local 60=85, 52=89, 29=128, 33=144, 34=161,
           127=162, 128=162, 129=162, 130=163, 126=167, ...
```

The two retained paired-store changes remove the previous shortest Func `7007` candidates while leaving the rejected Func `7008` split-argument candidates unchanged. The ranking remains an investigation queue, not proof of profitability or semantic admissibility. Future slices must inspect complete producer/consumer stacks, preserve source order, and measure direct raw plus canonical output before retention.

## Remaining direct work

The direct gap remains:

```text
raw gap:       +17332
canonical gap: +9809
```

No generated semantic family is open. The next direct iteration should:

1. inspect the remaining Func `7007` local `166` pair-store shape and determine why it did not join the retained one-/two-call family after remapping;
2. continue through Func `7007` locals `64`, `59`, `60`, `65`, and `81`, then Func `7008` local `29`, but do not retry local `52` / `60` split-argument sinking unchanged;
3. prefer exact post-remap shapes that reuse the existing count/type/rewrite traversal and selected-function profitability path;
4. retain plain `dae` separation and exactly one late DAEO preset slot;
5. stay below the absolute `17076.04ms` controlled ceiling;
6. rerun the complete explicit-native matrix, controlled timing, plain-DAE separation, and exact-once public scheduling after the next three measured code slices.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
