---
kind: workflow
status: working
last_reviewed: 2026-06-25
sources:
  - ../../../raw/research/0856-2026-06-25-code-pushing-all-post-throw-ref-refresh.md
  - ../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md
  - ../../../raw/research/0854-2026-06-25-code-pushing-regular-100000-post-call-barrier-refresh.md
  - ../../../raw/research/0853-2026-06-25-code-pushing-pass-fuzz-stress-post-call-barrier-refresh.md
  - ../../../raw/research/0852-2026-06-25-code-pushing-wasm-smith-post-call-barrier-refresh.md
  - ../../../raw/research/0851-2026-06-25-code-pushing-all-post-call-barrier-refresh.md
  - ../../../raw/research/0850-2026-06-25-code-pushing-call-barrier.md
  - ../../../raw/research/0849-2026-06-25-code-pushing-pass-fuzz-stress-post-boundary-refresh.md
  - ../../../raw/research/0848-2026-06-25-code-pushing-multilabel-br-table-boundary.md
  - ../../../raw/research/0847-2026-06-25-code-pushing-all-post-boundary-refresh.md
  - ../../../raw/research/0846-2026-06-25-code-pushing-br-on-null-prefix-boundary.md
  - ../../../raw/research/0845-2026-06-25-code-pushing-regular-100000-current.md
  - ../../../raw/research/0844-2026-06-25-code-pushing-br-on-cast-prefix-boundaries.md
  - ../../../raw/research/0843-2026-06-25-code-pushing-value-br-table-boundary.md
  - ../../../raw/research/0842-2026-06-25-code-pushing-all-10000-current.md
  - ../../../raw/research/0841-2026-06-25-code-pushing-br-if-value-aggregate-inclusion.md
  - ../../../raw/research/0840-2026-06-25-code-pushing-br-if-value-local-cleanup-normalizer.md
  - ../../../raw/research/0839-2026-06-25-code-pushing-prefix-aggregate-inclusion.md
  - ../../../raw/research/0838-2026-06-25-code-pushing-prefix-local-cleanup-normalizer.md
  - ../../../raw/research/0837-2026-06-25-code-pushing-br-on-non-null-prefix-exact-hot.md
  - ../../../raw/research/0836-2026-06-25-code-pushing-br-on-non-null-prefix-lowered-followup.md
  - ../../../raw/research/0835-2026-06-25-code-pushing-br-on-non-null-prefix-multiset.md
  - ../../../raw/research/0834-2026-06-25-code-pushing-br-on-non-null-prefix-payload.md
  - ../../../raw/research/0833-2026-06-25-code-pushing-br-if-value-lowering-blocker.md
  - ../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md
  - ../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md
  - ../../../raw/research/0827-2026-06-24-code-pushing-br-on-non-null-inventory.md
  - ../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md
  - ../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md
  - ../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md
  - ../../../raw/research/0823-2026-06-21-code-pushing-atomics-gc-boundary.md
  - ../../../raw/research/0821-2026-06-21-code-pushing-global-get-window-multi-set-movement.md
  - ../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md
  - ../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md
  - ../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/0817-2026-06-20-code-pushing-nop-window-multi-set-movement.md
  - ../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md
  - ../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md
  - ../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
  - ../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `code-pushing` Fuzzing Profile

Recommended ordinary mixed-generator smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --out-dir .tmp/pass-fuzz-code-pushing --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Native-path note for this checkout: after `moon build --target native --release src/cmd`, the working native command binary is `_build/native/release/build/cmd/cmd.exe`. The older documented `target/native/release/build/cmd/cmd.exe` path remains absent here.

## Dedicated GenValid profile

Use `code-pushing-all` for the pass-specific lane. It is a deterministic composite over nineteen currently aggregate-safe positive families:

| Leaf profile | Shape |
| --- | --- |
| `code-pushing-if-arm` | A pure `local.set` before a void `if`, where only one arm reads the local. |
| `code-pushing-after-if` | A pure computed `local.set` before an ordinary void `if` that does not read the local, followed by same-region suffix reads after the `if`. |
| `code-pushing-dropped-if` | A pure `local.set` before a dropped value `if` that does not read the local, followed by same-region suffix reads after the dropped wrapper. |
| `code-pushing-br-if` | A pure `local.set` before a no-branch-value void-block-target `br_if` that does not read the local, followed by same-block suffix reads after the branch. |
| `code-pushing-br-on-null` | Two adjacent local-independent pure `local.set` roots before a dropped zero-arity-label `br_on_null`, followed by same-block suffix reads after the branch, preserving source order. |
| `code-pushing-br-on-non-null` | Two adjacent local-independent pure `local.set` roots before a one-result-block-label `br_on_non_null`, followed by same-block suffix reads after the branch fallthrough, preserving source order. |
| `code-pushing-br-on-non-null-prefix` | Two adjacent local-independent pure `local.set` roots before a two-result block-label `br_on_non_null` with an explicit prefix payload plus implicit non-null reference payload. Included in `code-pushing-all` after the exact-HOT movement fix and narrow `local-cleanup-debris` normalization for generated local-copy/drop and tuple-local allocation debris. |
| `code-pushing-br-on-cast` | Two adjacent local-independent pure `local.set` roots before a dropped one-result-block-label `br_on_cast`, followed by same-block suffix reads after the branch fallthrough, preserving source order. |
| `code-pushing-br-on-cast-fail` | Two adjacent local-independent pure `local.set` roots before a dropped one-result-block-label `br_on_cast_fail`, followed by same-block suffix reads after the branch fallthrough, preserving source order. |
| `code-pushing-br-if-value` | Adjacent local-independent pure `local.set` roots before a value-block-target `br_if` with one branch payload, followed by same-block suffix reads after the branch, preserving source order. Included in `code-pushing-all` after the movement fix and narrow `local-cleanup-debris` normalization for `local.set tmp (br_if ...); drop tmp` lowering debris. |
| `code-pushing-multi-set` | Two local-independent pure `local.set` roots before an ordinary void `if`, followed by same-region suffix reads after the `if`, preserving source order. |
| `code-pushing-multi-set-dropped-if` | Two local-independent pure `local.set` roots before a dropped value `if`, followed by same-region suffix reads after the dropped wrapper, preserving source order. |
| `code-pushing-multi-set-br-if` | Two local-independent pure `local.set` roots before a void-block-target `br_if`, followed by same-block suffix reads after the branch, preserving source order. |
| `code-pushing-multi-set-local-copy` | Two adjacent direct local-copy SFA sets before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order and refusing source-local writes. |
| `code-pushing-multi-set-nop-window` | Two local-independent pure SFA sets separated by a `nop` before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order while leaving the `nop` before the push point. |
| `code-pushing-loop-br-if` | Two adjacent pure SFA sets before a no-branch-value `br_if` to a void loop label, followed by same-loop-body suffix reads after the branch, preserving source order. |
| `code-pushing-multi-set-drop-window` | Two local-independent pure SFA sets separated by `drop (i32.const ...)` before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order while leaving the drop before the push point. |
| `code-pushing-multi-set-local-get-window` | Two local-independent pure SFA sets separated by `drop (local.get ...)` before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order while leaving the drop before the push point. |
| `code-pushing-multi-set-global-get-window` | Two local-independent pure SFA sets separated by `drop (global.get ...)` before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order while leaving the drop before the push point. This leaf covers the positive ordinary-`if` family; focused pass tests also cover the dropped-`if` positive and `br_if` boundary. |

The profile intentionally does **not** cover remaining audit gaps such as call ordered barriers before later push points, broader EH forms beyond the focused pure-value `throw_ref` / later-`br_if` movement in [`0855`](../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md), switch/`br_table` beyond the protected no-branch-value, first value-carrying, and first multi-label stationary boundaries, broader `br_on_*` forms beyond the narrow dropped zero-arity-label `br_on_null`, one-result-block-label `br_on_non_null`, two-result block-label `br_on_non_null` prefix-payload movement, dropped one-result-block-label `br_on_cast`, and dropped one-result-block-label `br_on_cast_fail` leaves, broader prefix-payload/reference-carrying variants including the current Binaryen-stationary prefix-payload `br_on_null` / `br_on_cast` / `br_on_cast_fail` boundaries, broader branch-value conditional branches beyond the current adjacent `br_if` family, ordered multi-set movement outside the first ordinary-void-`if`, dropped-value-`if`, narrow no-branch-value block-/loop-target `br_if`, dropped `br_on_null`, value-block-target `br_if`, local-copy, `nop`-window, `drop(const)`-window, `drop(local.get)`-window, and bounded ordinary-/dropped-`if` `drop(global.get)`-window slices, broader atomics/GC, or trap-option widening. The 2026-06-21 and 2026-06-25 `br_table` work added focused no-mutation boundary tests only, including the multi-label nested-block boundary in [`0848`](../../../raw/research/0848-2026-06-25-code-pushing-multilabel-br-table-boundary.md), so no GenValid leaf was added for it. The 2026-06-25 prefix-payload `br_on_null` / `br_on_cast` / `br_on_cast_fail` work also added or recorded no-mutation boundaries only. The 2026-06-21 atomics/GC slice added focused HOT tests for the narrow non-null `struct.get` atomic-load/store family, also without a GenValid leaf. Add aggregate leaves when future positive generated movement families are aggregate-safe.

Current bounded dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-profile-200-local-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Current post-`throw_ref` 10000-case dedicated lane: [`0856`](../../../raw/research/0856-2026-06-25-code-pushing-all-post-throw-ref-refresh.md) refreshed the 19-leaf `code-pushing-all` profile after the behavior refinement in [`0855`](../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md). `.tmp/pass-fuzz-code-pushing-all-10000-20260625-post-throw-ref` compared `10000/10000`, normalized `4769`, cleanup-normalized `5231`, raw mismatches/failures `0`, command failures `0`, Binaryen cache `10000 hits/0 misses`, and selected all 19 aggregate leaves. This supersedes the post-call-barrier dedicated lane in [`0851`](../../../raw/research/0851-2026-06-25-code-pushing-all-post-call-barrier-refresh.md) for current dedicated-profile closeout-progress evidence.

2026-06-20 initial profile result before the dropped-if leaf: compared `200/200`, cleanup-normalized matches `200`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-if-arm: 100` and `code-pushing-after-if: 100`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 200 hits/0 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 dropped-if refresh after adding `code-pushing-dropped-if`:

```sh
bun scripts/pass-fuzz-compare.ts --count 300 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-dropped-if-profile-300 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `300/300`, normalized matches `90`, cleanup-normalized matches `210`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-dropped-if: 90`, `code-pushing-if-arm: 98`, `code-pushing-after-if: 112`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 295 hits/5 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 `br_if` refresh after adding `code-pushing-br-if`:

```sh
bun scripts/pass-fuzz-compare.ts --count 400 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-profile-400 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `400/400`, normalized matches `200`, cleanup-normalized matches `200`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-if-arm: 100`, `code-pushing-br-if: 100`, `code-pushing-dropped-if: 100`, `code-pushing-after-if: 100`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 396 hits/4 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 ordered multi-set refresh after adding `code-pushing-multi-set`:

```sh
bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-profile-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `500/500`, normalized matches `227`, cleanup-normalized matches `273`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-after-if: 91`, `code-pushing-multi-set: 85`, `code-pushing-if-arm: 97`, `code-pushing-dropped-if: 121`, `code-pushing-br-if: 106`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 498 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 dropped-`if` ordered multi-set refresh after adding `code-pushing-multi-set-dropped-if`:

```sh
bun scripts/pass-fuzz-compare.ts --count 600 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-dropped-if-profile-600 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `600/600`, normalized matches `292`, cleanup-normalized matches `308`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-dropped-if: 101`, `code-pushing-multi-set-dropped-if: 103`, `code-pushing-if-arm: 89`, `code-pushing-after-if: 109`, `code-pushing-multi-set: 110`, `code-pushing-br-if: 88`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 597 hits/3 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 `br_if` ordered multi-set refresh after adding `code-pushing-multi-set-br-if`:

```sh
bun scripts/pass-fuzz-compare.ts --count 700 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-br-if-profile-700 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `700/700`, normalized matches `403`, cleanup-normalized matches `297`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-dropped-if: 91`, `code-pushing-multi-set: 97`, `code-pushing-after-if: 95`, `code-pushing-multi-set-br-if: 111`, `code-pushing-if-arm: 105`, `code-pushing-multi-set-dropped-if: 101`, `code-pushing-br-if: 100`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 697 hits/3 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 local-copy ordered multi-set refresh after adding `code-pushing-multi-set-local-copy`:

```sh
bun scripts/pass-fuzz-compare.ts --count 800 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-local-copy-profile-800 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `800/800`, normalized matches `400`, cleanup-normalized matches `400`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-if-arm: 100`, `code-pushing-multi-set-local-copy: 100`, `code-pushing-dropped-if: 100`, `code-pushing-after-if: 100`, `code-pushing-multi-set: 100`, `code-pushing-br-if: 100`, `code-pushing-multi-set-br-if: 100`, `code-pushing-multi-set-dropped-if: 100`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 798 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 `nop`-window ordered multi-set refresh after adding `code-pushing-multi-set-nop-window`:

```sh
bun scripts/pass-fuzz-compare.ts --count 900 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-nop-window-profile-900 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `900/900`, normalized matches `402`, cleanup-normalized matches `498`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-after-if: 122`, `code-pushing-multi-set-dropped-if: 113`, `code-pushing-dropped-if: 103`, `code-pushing-multi-set: 102`, `code-pushing-if-arm: 97`, `code-pushing-br-if: 94`, `code-pushing-multi-set-br-if: 92`, `code-pushing-multi-set-nop-window: 92`, `code-pushing-multi-set-local-copy: 85`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 899 hits/1 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-20 loop-target `br_if` refresh after adding `code-pushing-loop-br-if`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-loop-br-if-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `516`, cleanup-normalized matches `484`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-multi-set-br-if: 110`, `code-pushing-loop-br-if: 98`, `code-pushing-if-arm: 108`, `code-pushing-multi-set-local-copy: 103`, `code-pushing-dropped-if: 102`, `code-pushing-multi-set-dropped-if: 103`, `code-pushing-after-if: 93`, `code-pushing-multi-set: 79`, `code-pushing-br-if: 103`, `code-pushing-multi-set-nop-window: 101`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 998 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-21 `drop(const)`-window ordered multi-set refresh after adding `code-pushing-multi-set-drop-window`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-drop-window-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `472`, cleanup-normalized matches `528`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-dropped-if: 87`, `code-pushing-multi-set-nop-window: 96`, `code-pushing-br-if: 100`, `code-pushing-after-if: 83`, `code-pushing-multi-set: 102`, `code-pushing-multi-set-local-copy: 83`, `code-pushing-loop-br-if: 83`, `code-pushing-multi-set-br-if: 108`, `code-pushing-multi-set-drop-window: 81`, `code-pushing-if-arm: 83`, `code-pushing-multi-set-dropped-if: 94`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 998 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-21 `drop(local.get)`-window ordered multi-set refresh after adding `code-pushing-multi-set-local-get-window`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-local-get-window-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `412`, cleanup-normalized matches `588`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-multi-set-nop-window: 81`, `code-pushing-multi-set-local-get-window: 86`, `code-pushing-multi-set-br-if: 81`, `code-pushing-multi-set-dropped-if: 89`, `code-pushing-multi-set-local-copy: 83`, `code-pushing-multi-set-drop-window: 87`, `code-pushing-loop-br-if: 79`, `code-pushing-multi-set: 91`, `code-pushing-dropped-if: 82`, `code-pushing-after-if: 82`, `code-pushing-br-if: 81`, `code-pushing-if-arm: 78`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 998 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-21 `drop(global.get)`-window bounded ordered multi-set refresh after adding `code-pushing-multi-set-global-get-window`:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-global-get-window-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `375`, cleanup-normalized matches `625`, raw mismatches `0`, validation/generator/property/command failures `0`, selected subprofiles `code-pushing-after-if: 82`, `code-pushing-br-if: 83`, `code-pushing-dropped-if: 83`, `code-pushing-if-arm: 90`, `code-pushing-loop-br-if: 76`, `code-pushing-multi-set: 77`, `code-pushing-multi-set-br-if: 69`, `code-pushing-multi-set-drop-window: 73`, `code-pushing-multi-set-dropped-if: 64`, `code-pushing-multi-set-global-get-window: 67`, `code-pushing-multi-set-local-copy: 75`, `code-pushing-multi-set-local-get-window: 89`, `code-pushing-multi-set-nop-window: 72`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 999 hits/1 misses`, `Binaryen failures 0 hits/0 misses`.

2026-06-24 post-branch-value slice aggregate refresh, with targeted `code-pushing-br-if-value` kept out of `code-pushing-all` because it exposes the value-`br_if` lowering temp-local representation gap:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-post-br-if-value-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `375`, cleanup-normalized matches `625`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, selected subprofiles `code-pushing-multi-set-local-copy: 75`, `code-pushing-multi-set: 77`, `code-pushing-multi-set-local-get-window: 89`, `code-pushing-multi-set-global-get-window: 67`, `code-pushing-multi-set-br-if: 69`, `code-pushing-if-arm: 90`, `code-pushing-br-if: 83`, `code-pushing-dropped-if: 83`, `code-pushing-multi-set-dropped-if: 64`, `code-pushing-multi-set-nop-window: 72`, `code-pushing-multi-set-drop-window: 73`, `code-pushing-after-if: 82`, `code-pushing-loop-br-if: 76`, cache `Binaryen 1000 hits/0 misses`.

2026-06-24 branch-value multi-set slice: the targeted `code-pushing-br-if-value` leaf now emits the adjacent ordered multi-set branch-value shape and focused GenValid tests passed. The aggregate-safe profile was rerun with the branch-value leaf still excluded: `.tmp/pass-fuzz-code-pushing-branch-value-multiset-aggregate-1000` compared `1000/1000`, normalized `375`, cleanup-normalized `625`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, and Binaryen cache `1000 hits/0 misses`.

2026-06-24 `br_on_null` slice: aggregate-safe leaf `code-pushing-br-on-null` was added to `code-pushing-all`. The refreshed profile compare `.tmp/pass-fuzz-code-pushing-br-on-null-aggregate-1000` compared `1000/1000`, normalized `424`, cleanup-normalized `576`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `998 hits/2 misses`, Binaryen failures `0 hits/0 misses`; selected subprofiles included `code-pushing-br-on-null: 74` and every other aggregate-safe leaf.

2026-06-24 `br_on_non_null` slice: aggregate-safe leaf `code-pushing-br-on-non-null` was added to `code-pushing-all`, growing the aggregate to 15 leaves. The refreshed profile compare `.tmp/pass-fuzz-code-pushing-br-on-non-null-aggregate-1000` compared `1000/1000`, normalized `473`, cleanup-normalized `527`, raw mismatches `0`, validation/generator/property/command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `999 hits/1 misses`, Binaryen failures `0 hits/0 misses`; selected subprofiles included `code-pushing-br-on-non-null: 59` and every other aggregate-safe leaf.

2026-06-24 `br_on_cast` slice: aggregate-safe leaf `code-pushing-br-on-cast` was added to `code-pushing-all`, growing the aggregate to 16 leaves. The refreshed profile compare `.tmp/pass-fuzz-code-pushing-br-on-cast-aggregate-1000` compared `1000/1000`, normalized `502`, cleanup-normalized `498`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `999 hits/1 misses`, Binaryen failures `0 hits/0 misses`; selected subprofiles included `code-pushing-br-on-cast: 62` and every other aggregate-safe leaf.

2026-06-24 `br_on_cast_fail` slice: aggregate-safe leaf `code-pushing-br-on-cast-fail` was added to `code-pushing-all`, growing the aggregate to 17 leaves. The refreshed profile compare `.tmp/pass-fuzz-code-pushing-br-on-cast-fail-aggregate-1000` compared `1000/1000`, normalized `544`, cleanup-normalized `456`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `999 hits/1 misses`, Binaryen failures `0 hits/0 misses`; selected subprofiles included `code-pushing-br-on-cast-fail: 49` and every other aggregate-safe leaf.

2026-06-24 dedicated-profile refresh: `.tmp/pass-fuzz-code-pushing-all-10000-20260624` compared `10000/10000` with `5377` normalized matches, `4623` cleanup-normalized matches, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `10000 hits/0 misses`, Binaryen failures `0 hits/0 misses`. All 17 aggregate-safe leaves were selected, including `code-pushing-br-on-cast-fail: 559`, `code-pushing-br-on-cast: 602`, `code-pushing-br-on-non-null: 601`, and `code-pushing-br-on-null: 589`.

2026-06-25 regular GenValid refresh: `.tmp/pass-fuzz-code-pushing-regular-10000-20260625` used the current native binary with `--normalize local-cleanup-debris` and no dedicated profile. It compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `102 hits/9898 misses`, Binaryen failures `0 hits/0 misses`, and selected ordinary `binaryen-oracle-portable: 10000` GenValid inputs. This was superseded for the regular GenValid closeout-progress lane by the same-day 100000-case refresh.

2026-06-25 regular GenValid 100000 refresh: [`0845`](../../../raw/research/0845-2026-06-25-code-pushing-regular-100000-current.md) used the then-current native binary with `--normalize local-cleanup-debris` and no dedicated profile. `.tmp/pass-fuzz-code-pushing-regular-100000-20260625` compared `100000/100000`, normalized `100000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, jobs `16`, seed `0x5eed`, cache `wasm-smith 0 hits/0 misses`, Binaryen `10356 hits/89644 misses`, Binaryen failures `0 hits/0 misses`, and selected ordinary `binaryen-oracle-portable: 100000` GenValid inputs. This was superseded for current closeout-progress evidence by the post-call-barrier refresh in [`0854`](../../../raw/research/0854-2026-06-25-code-pushing-regular-100000-post-call-barrier-refresh.md).

2026-06-25 post-call-barrier regular GenValid 100000 refresh: [`0854`](../../../raw/research/0854-2026-06-25-code-pushing-regular-100000-post-call-barrier-refresh.md) used the rebuilt native binary with `--normalize local-cleanup-debris` and no dedicated profile after the call-barrier fix. `.tmp/pass-fuzz-code-pushing-regular-100000-20260625-post-bbb` compared `100000/100000`, normalized `100000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, jobs `16`, seed `0x5eed`, cache `wasm-smith 0 hits/0 misses`, Binaryen `100000 hits/0 misses`, Binaryen failures `0 hits/0 misses`, and selected ordinary `binaryen-oracle-portable: 100000` GenValid inputs. This is current closeout-progress evidence for the required large regular lane, not final closeout by itself; final closeout still requires then-current source-backed gap resolution or accepted boundaries plus a final stop condition.

2026-06-25 explicit wasm-smith refresh: `.tmp/pass-fuzz-code-pushing-wasm-smith-10000-20260625` used the current native binary with `--wasm-smith`, seed `0x5eed`, and `--normalize local-cleanup-debris`. It compared `9956/10000`, normalized `9956`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property failures `0`, command failures `44`, command-failure classes `binaryen-rec-group-zero: 39`, `binaryen-invalid-tag-index: 1`, `binaryen-table-index-out-of-range: 1`, and `binaryen-bad-section-size: 3`, cache `wasm-smith 10000 hits/0 misses`, Binaryen `106 hits/9850 misses`, Binaryen failures `0 hits/44 misses`, and generator counts `wasmSmith: 9956`. This is closeout-progress evidence for the explicit external-generator lane, not final closeout by itself.

2026-06-25 broad named-profile refresh: `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625` used the current native binary with `--gen-valid-profile pass-fuzz-stress`, seed `0x5555`, and `--normalize local-cleanup-debris`. It compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `14 hits/9986 misses`, Binaryen failures `0 hits/0 misses`, and selected profile counts `pass-fuzz-stress: 10000`.

2026-06-25 post-boundary broad named-profile refresh: [`0849`](../../../raw/research/0849-2026-06-25-code-pushing-pass-fuzz-stress-post-boundary-refresh.md) reran the broad named lane after the multi-label `br_table` boundary slice. `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-ww` compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, jobs `16`, cache `wasm-smith 0 hits/0 misses`, Binaryen `10000 hits/0 misses`, Binaryen failures `0 hits/0 misses`, and selected profile counts `pass-fuzz-stress: 10000`. This superseded the earlier same-day broad named lane before the call-barrier behavior fix.

2026-06-25 post-call-barrier broad named-profile refresh: [`0853`](../../../raw/research/0853-2026-06-25-code-pushing-pass-fuzz-stress-post-call-barrier-refresh.md) reran the broad named lane after the call-barrier fix in [`0850`](../../../raw/research/0850-2026-06-25-code-pushing-call-barrier.md). `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-aaa` compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, jobs `16`, cache `wasm-smith 0 hits/0 misses`, Binaryen `10000 hits/0 misses`, Binaryen failures `0 hits/0 misses`, and selected profile counts `pass-fuzz-stress: 10000`. This supersedes [`0849`](../../../raw/research/0849-2026-06-25-code-pushing-pass-fuzz-stress-post-boundary-refresh.md) as broad named-profile closeout-progress evidence, but final closeout still needs source gap resolution or accepted boundaries and a then-current stop condition.

2026-06-25 targeted value-`br_if` blocker refresh: `.tmp/pass-fuzz-code-pushing-br-if-value-refresh-100-20260625` used the current native binary with `--gen-valid-profile code-pushing-br-if-value`, seed `0x5eed`, and `--normalize local-cleanup-debris`. It compared `35/100` before hitting `--max-failures 20`, with `0` normalized, `0` cleanup-normalized, `35` raw mismatches, and `0` validation/generator/property/command failures. Agent classification at that point was size-losing lowering/normalization blocker, not a missing code-pushing movement proof: Binaryen emits `drop (br_if ...)` for the value-branch fallthrough result; Starshine sinks the same local sets after the branch but materializes the fallthrough value through an extra temporary local and drops that temporary.

2026-06-25 value-`br_if` local-cleanup normalizer follow-up: [`0840`](../../../raw/research/0840-2026-06-25-code-pushing-br-if-value-local-cleanup-normalizer.md) added red-first normalizer coverage for single-use `local.set tmp (br_if ...); drop tmp` carriers. The targeted refresh `.tmp/pass-fuzz-code-pushing-br-if-value-copydrop-normalized-200-20260625` compared `200/200`, normalized `0`, cleanup-normalized `200`, raw mismatches/failures `0`, cache `Binaryen 200 hits/0 misses`.

2026-06-25 value-`br_if` aggregate inclusion follow-up: [`0841`](../../../raw/research/0841-2026-06-25-code-pushing-br-if-value-aggregate-inclusion.md) reran the targeted value-branch lane at 1000 requested cases, `.tmp/pass-fuzz-code-pushing-br-if-value-copydrop-normalized-1000-20260625`, and it compared `1000/1000` with `1000` cleanup-normalized matches and `0` raw mismatches/failures. `code-pushing-all` now includes `code-pushing-br-if-value` as its nineteenth leaf. The post-change aggregate smoke `.tmp/pass-fuzz-code-pushing-all-br-if-value-aggregated-1000-20260625` compared `1000/1000`, normalized `466`, cleanup-normalized `534`, raw mismatches/failures `0`, cache `Binaryen 1000 hits/0 misses`.

2026-06-25 current 19-leaf dedicated-profile refresh: [`0842`](../../../raw/research/0842-2026-06-25-code-pushing-all-10000-current.md) reran the then-current `code-pushing-all` lane at 10000 requested cases with `--normalize local-cleanup-debris`: `.tmp/pass-fuzz-code-pushing-all-10000-20260625-current` compared `10000/10000`, normalized `4769`, cleanup-normalized `5231`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, cache `Binaryen 10000 hits/0 misses`. All 19 aggregate leaves were selected, including `code-pushing-br-on-non-null-prefix: 513` and `code-pushing-br-if-value: 516`. After the docs-only `br_on_null` prefix-payload boundary probe, [`0847`](../../../raw/research/0847-2026-06-25-code-pushing-all-post-boundary-refresh.md) repeated the 10000-case dedicated lane at `.tmp/pass-fuzz-code-pushing-all-10000-20260625-post-uu` with the same compared/normalized/cleanup-normalized counts, no raw mismatches/failures, and all 19 leaves selected. This supersedes the older 17-leaf 10000-case aggregate evidence and the 19-leaf 1000-case smokes for dedicated-profile closeout-progress, but final closeout still needs source-backed gap resolution or accepted boundaries and the remaining then-current matrix lanes.

2026-06-25 post-prefix-payload focused implementation aggregate smoke: `.tmp/pass-fuzz-code-pushing-all-prefix-refresh-1000-20260625` used the current native binary after the focused two-result block-label `br_on_non_null` prefix-payload movement change, seed `0x5eed`, `--gen-valid-profile code-pushing-all`, and `--normalize local-cleanup-debris`. It compared `1000/1000`, normalized `544`, cleanup-normalized `456`, raw mismatches `0`, validation/generator/property/command failures `0`, cache `wasm-smith 0 hits/0 misses`, Binaryen `1000 hits/0 misses`, Binaryen failures `0 hits/0 misses`, and all 17 aggregate-safe leaves selected. The focused prefix-payload shape is still not an aggregate leaf.

2026-06-25 targeted prefix-payload GenValid blocker: `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-200-20260625` used the current native binary with `--gen-valid-profile code-pushing-br-on-non-null-prefix`, seed `0x5eed`, and `--normalize local-cleanup-debris`. It compared `65/200` before hitting the mismatch cap, with `0` normalized, `0` cleanup-normalized, `65` raw mismatches, `0` validation/generator/property/command failures, cache `wasm-smith 0 hits/0 misses`, Binaryen `49 hits/16 misses`, Binaryen failures `0 hits/0 misses`, and selected `code-pushing-br-on-non-null-prefix: 65`. Agent classification: targeted lowering/HOT-representation blocker for generated multivalue-prefix shapes; Binaryen sinks the local sets after the rewritten `br_on_non_null`, while Starshine currently leaves the generated WAT-lowered local sets before the branch. Keep this targeted leaf out of `code-pushing-all` until fixed or narrowly normalized.

2026-06-25 lowered-prefix follow-up: [`0836`](../../../raw/research/0836-2026-06-25-code-pushing-br-on-non-null-prefix-lowered-followup.md) added a focused nested-HOT regression for generated-like `br_on_non_null` prefix movement and a narrow recursive/control-child scan. The focused test now passes, but the real targeted generated lane was still blocked: `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-fix-200-20260625` compared `65/200` before the cap with `65` raw mismatches, and `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-fix2-20-20260625` compared `20/20` with `20` raw mismatches, both with no validation/generator/property/command failures.

2026-06-25 exact-HOT prefix follow-up: [`0837`](../../../raw/research/0837-2026-06-25-code-pushing-br-on-non-null-prefix-exact-hot.md) dumped the real replayed HOT and found a two-child `BrOnNonNull` root plus duplicated/shared block references that over-counted local writes. Starshine added red-first exact-HOT coverage, allowed generated-prefix movement across prefix-payload `BrOnNonNull`, and switched this helper to unique-node whole-function local accounting. Focused `*exact generated br_on_non_null*` now passes, and `*br_on_non_null*` passes `6/6`. The immediate post-fix targeted lane remained blocked by a lowerer/local-cleanup temp family: `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-20-20260625` compared `20/20` with `20` raw mismatches; `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-200-20260625` compared `65/200` before the mismatch cap with `65` raw mismatches.

2026-06-25 prefix local-cleanup normalizer follow-up: [`0838`](../../../raw/research/0838-2026-06-25-code-pushing-prefix-local-cleanup-normalizer.md) added red-first compare-normalizer coverage for single-use local copy drops and local-tee copy drops, plus tuple local declaration canonicalization. This normalizes the representative prefix-payload cleanup/allocation debris without hiding branch/control movement. The targeted refresh `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-copydrop-normalized2-200-20260625` compared `200/200`, normalized `0`, cleanup-normalized `200`, raw mismatches/failures `0`, cache `Binaryen 200 hits/0 misses`.

2026-06-25 prefix aggregate inclusion follow-up: [`0839`](../../../raw/research/0839-2026-06-25-code-pushing-prefix-aggregate-inclusion.md) reran the targeted prefix lane at 1000 requested cases, `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-copydrop-normalized-1000-20260625`, and it compared `1000/1000` with `1000` cleanup-normalized matches and `0` raw mismatches/failures. `code-pushing-all` now includes `code-pushing-br-on-non-null-prefix` as its eighteenth leaf. The post-change aggregate smoke `.tmp/pass-fuzz-code-pushing-all-prefix-aggregated-1000-20260625` compared `1000/1000`, normalized `507`, cleanup-normalized `493`, raw mismatches/failures `0`, cache `Binaryen 1000 hits/0 misses`.

A raw lane without `--normalize local-cleanup-debris` stopped after `65` raw mismatches in `65` compared cases before the dropped-if slice. Inspected artifacts showed a bounded local-cleanup drift: Starshine removes standalone `nop`/empty-else debris around the movement while Binaryen leaves it. Treat the normalized lane as bounded slice evidence, not final raw-output parity or pass closeout.

## Final closeout lane

Before final `[O4Z-AUDIT-CP]` closeout, run the repo-standard four-lane pass matrix. The current broad named lane is `pass-fuzz-stress` unless a literal random all-profiles profile is added later. The dedicated lane should use:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-genvalid-code-pushing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Report `selected_profile` counts from the GenValid manifest separately from the ordinary GenValid, explicit wasm-smith, and random all-profiles lanes.
