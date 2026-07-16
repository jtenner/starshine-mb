# 1625 — DAEO terminal-call argument final matrix

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this is not parity closeout.

Primary sources:

- previous checkpoint: [`1624`](./1624-2026-07-16-daeo-pair-result-final-matrix.md);
- implementation: [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt);
- red-first tests: [`src/passes/pass_manager_wbtest.mbt`](../../../../src/passes/pass_manager_wbtest.mbt);
- live contract: [`dae-optimizing/index.md`](../../binaryen/passes/dae-optimizing/index.md), [`starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md), and [`fuzzing.md`](../../binaryen/passes/dae-optimizing/fuzzing.md).

## Summary

This iteration preserves plain `dead-argument-elimination` / `dae` separation and the single locked late DAEO preset slot. It extends only the optimizing selected-function post-remap cleanup over already-counted, already-remapped accepted definitions.

The first retained slice removes Func `7007` local `61`. It recognizes an exact one-use block result followed by a non-null aggregate projection, two empty GC constructors, and a final call argument. The complete typed producer moves directly into the selected call argument; the projection and constructors retain stack order, while exact result type, one-set/one-get/no-tee counts, caller-local write guards, selected-definition validation, strict selected-function encoded-size profitability, and rollback remain authoritative.

The second retained slice removes Func `7008` local `29`. It recognizes Binaryen v130's exact target-first terminal-call shape: a complete one-use block producer is delayed until after the four-operand prefix call and becomes the first of the final three consumer arguments. The third retained slice handles the sibling target-last shape and removes Func `7008` locals `126` and `127`: a pure scalar final argument and zero move before the complete block producer, which becomes the consumer's final argument. Both transactions guard every caller local moved across the producer.

No second selected-function traversal, whole-module validation transaction, whole-module encoding transaction, plain-DAE behavior, or preset slot was added.

## Exact code-commit contract

Starting point:

```text
6c625a2e123d2864f2cb03d9c6d1de517b7d3488
```

Exactly three code commits were retained:

1. `ee146697b feat: sink DAEO block results through composite call arguments`
   - red first: the focused fixture reported zero rewrites instead of one;
   - direct incremental delta: `-4` raw / `-4` canonical bytes.
2. `e080eba53 feat: sink DAEO block results into target-first terminal calls`
   - red first: the focused fixture reported zero rewrites instead of one;
   - direct incremental delta: `-4` raw / `-4` canonical bytes.
3. `9f82eb0d0 feat: sink DAEO block results into target-last terminal calls`
   - red first: the focused fixture reported zero rewrites instead of one;
   - direct incremental delta: `-8` raw / `-12` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiment

A nested fallthrough pair-result transport for Func `7007` local `81` failed red first and then passed its focused white-box test, but the direct artifact was byte-identical. All code and test changes were reverted. The rejected patch is preserved at:

```text
.tmp/daeo-recursive-1625-20260716/rejected-fallthrough-pair-transport.patch
```

Do not retry that patch unchanged. Func `7008` locals `52` and `60` also remain closed to unchanged split-argument retries.

## Explicit native binary and oracle

All authoritative evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 b5296018f93bb6bde6b2789d6452f2a52038fea95709500ddda40ee3b603cdf4
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
- `moon test`: `8872/8872` passed;
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
| Starshine final | `3194711` | `3272201` | raw `8944268cf336f1c76a9ead8fec66a9fbff69e205136205b46c5cd32c08962785`; canonical `ff3342c95f12376ea794f3018d817cd20366b00bb9ff3f19c89acaf1a89d7a3d` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17290` | `+9745` | open parity gap |

Relative to note `1624`:

```text
raw:       3194727 -> 3194711  (-16)
canonical: 3272221 -> 3272201  (-20)
```

Each retained code commit independently reduces both raw and canonical size. Validation, fewer local operations, or an unmeasured representation difference does not close the remaining gap.

## Controlled timing

Absolute ceiling:

```text
17076.04ms
```

The shared host produced unstable unpinned wall samples under variable load. The final controlled protocol pins the single-threaded native replay to CPU `2` with `taskset -c 2` and inserts a ten-second quiet interval between repeats. Final pass-local `pipeline` timings are:

```text
16657.065ms
16567.610ms
16862.325ms
```

All three controlled repeats are below the ceiling.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-1625-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-1625-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-1625-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-1625-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual selected profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names, all `3670` saved files, and all `10000` case records are byte-identical to note `1624`. The established agent classification is unchanged: both generated residual families are measured/source-backed intentional Starshine cleanup wins, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

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
- retain the late `heap-store-optimization` slot immediately before DAEO, taking its explicit raw-skip path on the fixture;
- start `inlining-optimizing` immediately after `dae-optimizing:done`.

## Current residual ranking and next work

The retained changes remove Func `7007` local `61` and Func `7008` locals `29`, `126`, and `127`. Current exact one-set/one-get/no-tee carriers include:

```text
Func 7007: locals 158, 159, 169, 170, 76, 80, 81, 28, 171, 79, 78, 74, ...
Func 7008: locals 60, 52, 33, 34, 128, 129, 130, 36, 43, 44, 37, 84, ...
```

This is an investigation queue, not semantic or profitability proof. The next direct iteration should:

1. inspect complete producer/consumer stacks for Func `7007` locals `158`, `159`, `169`, and `170`, then `76`, `80`, and `79`;
2. treat the local `81` fallthrough patch as closed unless a materially different owner transaction is found;
3. inspect Func `7008` locals `33`, `34`, `128`, `129`, and `130`, while continuing to avoid unchanged local `52` / `60` split-argument sinking;
4. keep changes fused into the existing selected traversals and strict selected-function profitability transaction;
5. retain plain DAE separation and exactly one late DAEO preset slot;
6. stay below the absolute `17076.04ms` controlled ceiling;
7. rerun the complete explicit-native Binaryen-v130 matrix after the next three measured code slices.

The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
