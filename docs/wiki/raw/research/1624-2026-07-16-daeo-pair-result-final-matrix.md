# 1624 — DAEO pair-result final matrix

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1623`](./1623-2026-07-16-daeo-single-traversal-readback-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md), [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md), and [`fuzzing.md`](../../binaryen/passes/dae-optimizing/fuzzing.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and the single locked late DAEO preset slot. It extends only the optimizing selected-function cleanup over the already-counted, already-remapped accepted definitions.

The first two slices close the remaining Func `7007` paired-store spills discovered in note `1623`. The existing paired-store helper already moved the first receiver read before the complete typed producer and removed the first result spill. The retained extension now recognizes the producer's exact terminal same-aggregate field pair, moves the first receiver read into that successful producer arm, performs the first `struct.set` there, and changes the producer to return only the second field. The second receiver remains a nontrapping local read before the producer, so the second result reaches its `struct.set` directly. Two-call and one-call producers are admitted separately and each independently shrinks raw and canonical output.

The third slice handles the surviving Func `7008` numeric readback in the earlier selected forwarding traversal: exact `i32.wrap_i64; local.set; local.get` becomes `i32.wrap_i64; local.tee`. `i32.wrap_i64` is pure and nontrapping, and the tee preserves the later local read. The first attempt placed this rule in the later readback traversal and was byte-identical; the retained rule is fused into the traversal that owns the artifact shape.

No second full selected-function traversal, whole-module validation transaction, or whole-module encoding transaction was added. Selected-definition validation, strict selected-function encoded-size profitability, and rollback remain authoritative.

## Exact code-commit contract

Starting point:

```text
8a677800a04996e97ef02d99de6cefa7d135e0d1
```

Exactly three code commits were retained:

1. `1ae6d63df feat: store first DAEO pair result inside two-call producers`
   - red first: the focused fixture reported zero rewrites instead of one;
   - direct incremental delta: `-4` raw / `-14` canonical bytes.
2. `5d5426a33 feat: store first DAEO pair result inside one-call producers`
   - red first: the second result still had one get instead of zero;
   - direct incremental delta: `-4` raw / `-12` canonical bytes.
3. `048ae933c feat: tee DAEO i64-to-i32 readbacks in the selected traversal`
   - red first: the focused fixture reported zero rewrites instead of one;
   - direct incremental delta: `-2` raw / `-2` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiments

A naive pair-result reversal placed both receivers below a reversed two-result block. The resulting module was invalid because the first `struct.set` saw the second result where its receiver was required. A second version moved the first store inside a single-result producer but attempted to consume a receiver below the block control-frame height; that also failed validation. Both were reverted. The retained transaction reads the first receiver inside the exact successful producer arm and leaves only the second result as the block result.

An exact Func `7007` local `81` nested-consumer transport passed its focused white-box fixture but was byte-identical on the direct artifact and was reverted. The rejected patch is saved under `.tmp/daeo-recursive-1624-20260716/rejected-nested-pair-transport.patch`; do not retry it unchanged.

An `i32.wrap_i64` tee added only to the later readback traversal was also byte-identical because that traversal does not own the surviving artifact stage. The rule was reverted and then retained in the existing selected forwarding traversal, where it removes the actual set/readback pair.

Func `7008` locals `52` / `60` split-argument sinking was not retried.

## Explicit native binary and oracle

All authoritative evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 ad40793df6a356f12e76cbdb8e587739c6de2b590f1792ee1c84a2dd84ecaa1d
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
- `moon test`: `8869/8869` passed;
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
| Starshine final | `3194727` | `3272221` | raw `421148fa0a6590749ca22cc13877bbdfd6eb1a13b533f2b456680e64514808fe`; canonical `f4fc202629bd7e9e6359009cd319bcb217576cee7f1bdee17909f6425bd3abe1` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17306` | `+9765` | open parity gap |

Relative to note `1623`:

```text
raw:       3194737 -> 3194727  (-10)
canonical: 3272249 -> 3272221  (-28)
```

Each retained code commit independently reduces both raw and canonical size. Validation, fewer local operations, or an unmeasured representation difference does not close the remaining gap.

## Controlled timing

Absolute ceiling:

```text
17076.04ms
```

Final pass-local repeats from `perf:timer name=pipeline`:

```text
16669.816ms
16659.436ms
16620.041ms
```

All are below the ceiling.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-1624-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-1624-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-1624-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-1624-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual selected profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1623`. The established agent classification is unchanged: both generated residual families are measured/source-backed intentional Starshine cleanup wins, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

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

## Current residual ranking and next work

The retained pair-result changes remove Func `7007` locals `64` and `65`; the retained conversion tee removes the surviving Func `7008` local `27` readback. The current shortest one-use queue begins:

```text
Func 7007: local 61, 79, 81, 158, 159, 169, 170, 76, 80, 78, 74, ...
Func 7008: local 52, 60, 29, 84, 33, 34, 126, 127, 128, 129, 130, ...
```

The ranking is an investigation queue, not semantic or profitability proof. The next direct iteration should:

1. inspect the complete producer/consumer stacks for Func `7007` local `61`, then `79` and later candidates;
2. treat the local `81` nested-consumer patch as closed unless a materially different owner transaction is found;
3. continue to avoid unchanged Func `7008` local `52` / `60` split-argument sinking;
4. keep changes fused into the existing selected traversals and strict selected-function profitability transaction;
5. retain plain DAE separation and exactly one late DAEO preset slot;
6. stay below the absolute `17076.04ms` controlled ceiling;
7. rerun the complete explicit-native Binaryen-v130 matrix after the next three measured code slices.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
