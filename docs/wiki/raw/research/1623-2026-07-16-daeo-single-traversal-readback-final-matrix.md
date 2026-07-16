# 1623 — DAEO single-traversal readback final matrix

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1622`](./1622-2026-07-16-daeo-pair-store-transport-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md), [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md), and [`fuzzing.md`](../../binaryen/passes/dae-optimizing/fuzzing.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and the single locked late DAEO preset slot. It extends only the optimizing post-component rewrite on the already-selected changed definitions.

The first slice closes the traversal-order exposure discovered after note `1622` without a retry scan. The exact terminal wrapper-call transport used to consume its preserved producer block atomically, so the existing traversal never entered that block and could not see the nested pair-store carrier until a forbidden second full traversal. The terminal helper now recursively rewrites only that already-emitted producer body before installing the parent replacement and includes the nested rewrite count.

The next two slices remove exact aggregate-field spills:

1. a tee-captured aggregate is reread to preserve the three-field branch-result order without a first-field spill;
2. a receiver local read moves before its pure field projection, and the field spill becomes `local.tee`, removing the immediate readback while preserving later reads.

All three reuse the existing post-remap selected-function counts, selected-definition validation, strict selected-function encoded-size profitability, and rollback. No second full selected-function traversal, whole-module validation transaction, or whole-module encoding transaction was added.

## Exact code-commit contract

Starting point:

```text
cc7c84a1398922115c2f777dd439a85871c2300a
```

Exactly three code commits were retained:

1. `646349226ab203cefce8951618583d77e78d6e0b feat: fuse nested DAEO pair stores into terminal call transport`
   - red first: the focused traversal fixture reported one rewrite instead of the required parent plus nested pair rewrite;
   - direct delta: `-6` raw / `-6` canonical bytes.
2. `40ef60227e56584caa625f7bfd2ee864a5a6dcbe feat: reread selected DAEO aggregate fields without spills`
   - red first: the focused three-field reorder fixture reported zero rewrites;
   - direct incremental delta: `-8` raw / `-8` canonical bytes.
3. `0d41f27842b66af2a88b57d25da5e85576177e27 feat: tee selected DAEO aggregate fields into receiver calls`
   - red first: the focused receiver/field fixture reported zero rewrites;
   - direct incremental delta: `-2` raw / `-2` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiments

The forbidden full retry was used only as attribution evidence before implementation and was not retained. After commit 1, and again after commit 2, a temporary second traversal was byte-identical, confirming the known fixpoint exposure had been fused into the owning parent helper.

A broader direct-call-result carrier into nested unwrap blocks produced invalid wasm (`popping from empty stack`) and was fully reverted. The first unique-spill version of the receiver/field rewrite was byte-identical because the artifact field local has later reads; the retained commit 3 uses `local.tee` to preserve those reads and removes only the immediate readback.

Func `7008` locals `52` / `60` split-argument sinking was not retried.

## Explicit native binary and oracle

All authoritative evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 3bdb505978a89ad4f661ac0350196eecde5a2fe549bd141e60bc808df883df4e
```

Binaryen was selected explicitly:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
wasm-opt version 130 (version_130)
```

All generated lanes use both DAE normalizers, `--jobs auto`, and the explicit native Starshine binary. Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Consolidated validation

After commit 3:

- `moon info`: passed with existing warnings;
- `moon fmt`: passed; `moon.mod` was restored to the repository multiline `options(source: "src")` spelling;
- `moon test`: `8866/8866` passed;
- `moon build --target native --release src/cmd`: passed;
- `bun validate full --profile ci --target wasm-gc --seed 1784180459434000`: passed;
- no `.mbti` public-API diff exists.

## Direct artifact and Binaryen gap

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

The final Starshine output validates before and after Binaryen v130 canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194737` | `3272249` | raw `564cabedc42fe05f938dd06bbabac638573a1e1d9177999ce97635cd4f112382`; canonical `adaeb2be561e5e0fde11c27a6b7ba1c577a0b16ec0345177802b8434aa1afa1d` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17316` | `+9793` | open parity gap |

Relative to note `1622`:

```text
raw:       3194753 -> 3194737  (-16)
canonical: 3272265 -> 3272249  (-16)
```

Each retained code commit independently reduces both raw and canonical size. Validation, fewer local operations, or an unmeasured representation difference does not close the remaining gap.

## Controlled timing

Absolute ceiling:

```text
17076.04ms
```

Final quiescent pass-local repeats:

```text
16608.001ms
16524.749ms
16568.615ms
```

All are below the ceiling. The first post-commit-1 warm/contention sample was `17364.071ms`; two immediate clean repeats were `16679.312ms` and `16708.858ms`, so the over-ceiling sample is not retained as final evidence.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-1623-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-1623-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-1623-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-1623-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual selected profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1622`. The established agent classification is unchanged: both generated residual families are measured/source-backed intentional Starshine cleanup wins, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

## Plain DAE separation

A fresh direct plain-DAE replay:

- validates;
- emits exactly one `pass[dead-argument-elimination]:start` and one matching `done`;
- emits no `pass[dae-optimizing]:start` and no optimizing post-component cleanup trace;
- writes `3201276` bytes with SHA-256 `dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8`.

All retained behavior remains optimizing-only.

## Exact-once public scheduling

The current dedicated-profile fixture was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`.

All three:

- validate;
- emit the same `38`-byte output with SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- execute exactly one top-level `dae-optimizing` start/done pair;
- retain the late `heap-store-optimization` slot immediately before DAEO (the fixture takes its explicit raw-skip path);
- start `inlining-optimizing` immediately after `dae-optimizing:done`.

## Remaining direct work

The direct gap remains:

```text
raw gap:       +17316
canonical gap: +9793
```

No generated semantic family is open. The next direct iteration should:

1. regenerate the current Func `7007` / `7008` one-use ranking after the aggregate rewrites;
2. inspect the remaining Func `7007` locals `64`, `65`, `81`, and later exact carrier families, without retrying the closed local `166` fixpoint exposure;
3. continue to avoid unchanged Func `7008` local `52` / `60` split-argument sinking;
4. keep changes fused into the existing selected traversal and strict selected-function profitability transaction;
5. retain plain DAE separation and exactly one late DAEO preset slot;
6. stay below the absolute `17076.04ms` controlled ceiling;
7. rerun the complete explicit-native Binaryen-v130 matrix after the next three measured code slices.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
