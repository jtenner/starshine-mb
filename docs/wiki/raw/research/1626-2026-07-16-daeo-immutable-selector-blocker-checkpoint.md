# DAEO immutable-selector blocker checkpoint

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after one retained red-first code commit. The requested three-commit matrix stopped early at a concrete single-traversal/canonical-profitability blocker. Direct Binaryen v130 parity remains open.

Primary sources:

- code commit `ff07fd35e` (`feat: delay DAEO immutable selectors past side calls`);
- `src/passes/pass_manager.mbt`;
- `src/passes/pass_manager_wbtest.mbt`;
- prior checkpoint [`1625`](./1625-2026-07-16-daeo-terminal-call-argument-final-matrix.md);
- live pass contract [`../../binaryen/passes/dae-optimizing/starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md);
- full local evidence under `.tmp/daeo-recursive-1626-20260716/` and `.tmp/pass-fuzz-daeo-1626-final-*`.

## Retained code slice

The retained slice removes Func `7008` local `43`. The selected post-remap readback traversal recognizes Binaryen v130's exact selector shape:

1. read a non-null struct reference;
2. read an immutable `i32` field;
3. compare it with an exact integer tag;
4. choose between two constant `i32` arms;
5. save the selector to a one-set/one-get/no-tee carrier;
6. execute the exact sibling side-call chain;
7. read the selector as the middle argument of the following call chain.

The rewrite delays only the immutable-field selector expression across the sibling calls and substitutes it at its sole readback. It requires a flattened type-section lookup proving the field immutable, a non-null source reference, exact selector type and access counts, and the exact complete producer/consumer stack. It does not classify arbitrary calls as pure and does not move mutable-field reads. The existing selected-definition validation, strict encoded-size profitability, rollback, and final module validation remain the owning transaction.

The focused fixture failed red with `0 != 1`, then passed after implementation. Final extracted Func `7008` contains no `local.set 43` / `local.get 43` pair.

## Why the requested three commits stopped at one

Every retained code commit had to improve both the raw endpoint and the Binaryen-v130 canonical endpoint relative to its immediate parent. After the selector slice, the remaining investigated candidates did not satisfy that contract:

- sequential loop-bound local reuse passed its red-first fixture but tied both endpoints;
- nested array-item sinking first regressed raw by `3` bytes while tying canonical, then a flatter form tied both endpoints;
- moving that array-item splice to the post-remap readback traversal also tied both endpoints;
- combining sequential bound reuse with post-remap array-item sinking still tied both endpoints;
- rehoming one high-index one-use local into a newly dead one-byte slot improved raw by `4` bytes but tied canonical.

Rejected experiments are preserved locally as:

```text
.tmp/daeo-recursive-1626-20260716/rejected-sequential-loop-bound-reuse.patch
.tmp/daeo-recursive-1626-20260716/rejected-nested-array-item-sink.patch
.tmp/daeo-recursive-1626-20260716/rejected-flat-nested-array-item-sink.patch
.tmp/daeo-recursive-1626-20260716/rejected-post-remap-array-item-sink.patch
.tmp/daeo-recursive-1626-20260716/rejected-combined-sequential-array.patch
.tmp/daeo-recursive-1626-20260716/rejected-high-local-dead-slot-rehome.patch
```

The concrete blocker is transaction order. Several remaining local-carrier opportunities become dead only inside the one allowed post-remap readback traversal, after the selected local declaration compaction/remap has already been fixed. Making those probes canonical-winning requires another body remap/compaction after readback, which is a second selected-function traversal and violates the current one-traversal constraint. The alternative direct-call carriers require complete call-effect evidence before moving producers across sibling calls; that evidence is not owned by the current readback traversal, and treating those calls as pure would be unsafe. The iteration therefore stopped rather than retain raw-only, tied, or unproved changes.

## Direct artifact and Binaryen v130 comparison

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Oracle:

```text
wasm-opt version 130 (version_130)
```

The final Starshine output validates before and after Binaryen v130 canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194707` | `3272197` | raw `0f37debdb33bffc2f7e1136f6db302595fb4f3262abd169f07af9ffab845b796`; canonical `5eb2cd204f6f5df1f72ca8ec771193b7206c7b23bd62a115ec469a37afbcf1d9` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17286` | `+9741` | open parity gap |

Relative to note `1625`:

```text
raw:       3194711 -> 3194707  (-4)
canonical: 3272201 -> 3272197  (-4)
```

Validation, fewer local operations, a raw-only win, or a tied endpoint does not close the remaining gap.

## Controlled timing

Absolute ceiling:

```text
17076.04ms
```

The controlled protocol pinned each single-threaded native replay to CPU `2` with `taskset -c 2` and inserted a ten-second quiet interval between repeats. Final pass-local `pipeline` timings are:

```text
16513.537ms
16698.406ms
16730.872ms
```

All three repeats remain below the ceiling.

## Required direct compare matrix

The explicit native binary SHA-256 is:

```text
260c9b1b6f3ed314adc98a7222af3f9b45b5edb0b92e8055aab2488f9029b33a
```

All lanes used Binaryen v130 explicitly and both DAE cleanup normalizers.

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-1626-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-1626-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-1626-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-1626-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual selected profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names, all `3670` saved files, and all `10000` case records are byte-identical to note `1625`. The established agent classification remains measured/source-backed intentional Starshine cleanup wins, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

## Plain DAE and public scheduling

A fresh direct plain-DAE replay validates, emits exactly one `dead-argument-elimination` start/done pair, emits no `dae-optimizing` start, emits no optimizing post-component cleanup trace, and remains byte-identical to note `1625`:

```text
3201276 bytes
dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8
```

The current dedicated-profile fixture was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`. All three validate, emit the same `38`-byte output with SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`, execute exactly one top-level DAEO start/done pair, keep the late HSO raw-skip immediately before DAEO, and start `inlining-optimizing` immediately after DAEO finishes.

## Consolidated validation

- `moon info` passed;
- `moon fmt` passed and the repository `moon.mod` spelling was restored;
- `moon test` passed `8873/8873`;
- native release `src/cmd` build passed;
- direct Starshine and Binaryen v130 outputs validate before and after canonicalization;
- the first full CI-profile invocation aborted in the wasm-gc fuzz harness before reporting suites; an immediate complete rerun passed every reported suite at seed `1784210258417000`, including `validate-valid=5000`, `validate-invalid-ast=2650`, `binary-roundtrip=86820`, and `cmd-harness=4096`.

No `.mbti` public API snapshot changed.

## Next work

The continuation should not retry the rejected patches unchanged. It should choose one of two ownership changes:

1. prove a way to fold newly dead post-remap locals into the existing compaction/remap without a second selected body traversal; or
2. add reusable, source-backed direct-call effect summaries to the existing owner so Func `7008` locals `128`, `129`, `130`, `44`, and later call-produced carriers can be moved only with complete stack/effect evidence.

Continue to inspect Func `7007` locals `158`, `159`, `169`, `170`, `76`, `80`, and `79`, but do not retain local-slot reuse unless both raw and canonical endpoints improve. Preserve plain DAE separation, exactly one late public DAEO slot, selected validation/profitability/rollback, and the `17076.04ms` ceiling. The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
