# DAEO consumed call-argument slot checkpoint

Date: 2026-07-16

Status: current direct `dae-optimizing` checkpoint after one retained red-first code commit. The requested three-commit iteration stopped early at a concrete profitability/evidence blocker. Direct Binaryen v130 parity remains open.

Primary sources:

- code commit `adf4aa7c3` (`feat: reuse consumed DAEO call argument slots`);
- `src/passes/pass_manager.mbt`;
- `src/passes/pass_manager_wbtest.mbt`;
- prior checkpoint [`1626`](./1626-2026-07-16-daeo-immutable-selector-blocker-checkpoint.md);
- live pass contract [`../../binaryen/passes/dae-optimizing/starshine-strategy.md`](../../binaryen/passes/dae-optimizing/starshine-strategy.md);
- local evidence under `.tmp/daeo-recursive-1627-20260716/` and `.tmp/pass-fuzz-daeo-1627-final-*`.

## Retained code slice

The retained slice removes one high one-set/one-get call-result carrier by reusing the local slot consumed by the call's first argument. Complete callsite value-slice attribution is fused into the existing selected-function local-count traversal, so the accepted change adds no second selected-function body traversal.

The rewrite requires:

1. a direct call immediately followed by the high carrier `local.set`;
2. a complete value slice for every call argument;
3. an exact first argument rooted in the reusable source local;
4. matching source-local, call-result, and destination-local types;
5. exactly one destination set, one destination get, and no destination tee;
6. a terminal return consumer;
7. no later reference to the consumed source local;
8. the existing selected-definition validation, strict encoded-size profitability check, rollback, and final module validation.

The collector first uses a high-local call/`local.set` prefilter, then resolves the direct function type without adding a whole-body retry. The focused fixture failed red because the new collector was unbound, then passed after implementation. The retained artifact improves both required endpoints by `4` bytes.

## Why the requested three commits stopped at one

Every retained code commit had to improve both the raw endpoint and the Binaryen-v130 canonical endpoint relative to its immediate parent. The remaining bounded probes did not satisfy that contract:

- consumed block-argument slot reuse tied both endpoints;
- unreachable terminal slot reuse tied both endpoints;
- dead-suffix terminal slot reuse tied both endpoints;
- block-producer slot reuse worsened raw by `8` bytes and canonical by `10` bytes.

Rejected experiments are preserved locally as:

```text
.tmp/daeo-recursive-1627-20260716/rejected-consumed-block-arg-slot-reuse.patch
.tmp/daeo-recursive-1627-20260716/rejected-unreachable-terminal-slot-reuse.patch
.tmp/daeo-recursive-1627-20260716/rejected-dead-suffix-terminal-slot-reuse.patch
.tmp/daeo-recursive-1627-20260716/rejected-block-producer-slot-reuse.patch
```

The concrete blocker is now narrower. Broader terminal, unreachable, and dead-suffix slot aliases do not change the encoded endpoint, while moving a block producer into the reusable slot makes both endpoints larger. Further canonical progress appears to require stronger path-sensitive lifetime/effect evidence or another compaction/remap opportunity that can be folded into the existing selected traversal. Adding a second selected-function body traversal remains outside the iteration contract.

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
| Starshine final | `3194703` | `3272193` | raw `27e8518b453b0f761baccac8a26ace50fb84b53bc6c2a3d3df47e9c0bc932804`; canonical `31b352364136b731571087091c8867b39f6b213924587890b7d0b0db351f8489` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17282` | `+9737` | open parity gap |

Relative to note `1626`:

```text
raw:       3194707 -> 3194703  (-4)
canonical: 3272197 -> 3272193  (-4)
```

Validation, fewer local operations, a tied endpoint, or an isolated raw win does not close the remaining gap.

## Controlled timing

Absolute ceiling:

```text
17076.04ms
```

The controlled protocol pinned each single-threaded native replay to CPU `2` with `taskset -c 2` and inserted a ten-second quiet interval between repeats. The final trace integer timers report pass-local `pipeline` timings of:

```text
16611.320ms
16706.526ms
16765.932ms
```

All three repeats remain below the ceiling. The high-local call/`local.set` prefilter and direct function-type resolution were required to recover this headroom after the initial implementation exceeded the ceiling.

## Required direct compare matrix

The explicit native binary SHA-256 is:

```text
fad834ed0d10e25d71f890c4c96afd4e8c0f0db3ec74f533191152c91c892a53
```

All lanes used Binaryen v130 explicitly and both DAE cleanup normalizers.

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-1627-final-dedicated-10000-20260716
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-1627-final-regular-100000-20260716
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-1627-final-wasm-smith-10000-20260716
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-1627-final-random-all-10000-20260716
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual selected profiles remain `coverage-forced-portable=243` and `dae-effectful-args=124`.

All `367` failure-directory names, all `3670` saved files, and all `10000` case records are byte-identical to note `1626`. The established agent classification remains measured/source-backed intentional Starshine cleanup wins, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals in the authoritative matrix.

## Plain DAE and public scheduling

A fresh direct plain-DAE replay validates, emits exactly one `dead-argument-elimination` start/done pair, emits no `dae-optimizing` start, emits no optimizing post-component cleanup trace, and remains byte-identical to note `1626`:

```text
3201276 bytes
dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8
```

The current dedicated-profile fixture was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`. All three validate, emit the same `38`-byte output with SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`, execute exactly one top-level DAEO start/done pair, keep the late HSO raw-skip immediately before DAEO, and start `inlining-optimizing` immediately after DAEO finishes.

## Consolidated validation

- `moon info` passed;
- `moon fmt` passed and the repository `moon.mod` spelling was restored;
- `moon test` passed `8874/8874`;
- native release `src/cmd` build passed;
- direct Starshine and Binaryen v130 outputs validate before and after canonicalization;
- the first `bun validate full --profile ci --target wasm-gc` invocation passed `moon test` but aborted in the wasm-gc fuzz process with `RuntimeError: unreachable` before reporting the CI suites;
- the immediate complete rerun passed every reported suite at seed `1784217961829000`, including `validate-valid=5000`, `validate-invalid-ast=2650`, `binary-roundtrip=86820`, and `cmd-harness=4096`.

No `.mbti` public API snapshot changed.

## Next work

The continuation should not retry the rejected patches unchanged. It should choose a bounded owner that can improve both endpoints without another selected-function body traversal:

1. derive stronger path-sensitive lifetime/effect evidence in the existing count walk so terminal or structured producers can safely reuse an already consumed slot; or
2. expose another exact remap/compaction opportunity during the current traversal, rather than after it; or
3. re-rank the remaining Func `7007` locals `158`, `159`, `169`, `170`, `76`, `80`, and `79` for a distinct independently profitable transport.

Preserve plain DAE separation, exactly one late public DAEO slot, selected validation/profitability/rollback, explicit Binaryen-v130 comparison, and the `17076.04ms` ceiling. The broader pre-DAEO `[WALL]001` optimize-vacuum and shrink/O4z-ssa-nomerge blockers remain outside this direct-pass iteration.
