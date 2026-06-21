---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
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

Use `code-pushing-all` for the pass-specific lane. It is a deterministic composite over eight currently implemented positive families:

| Leaf profile | Shape |
| --- | --- |
| `code-pushing-if-arm` | A pure `local.set` before a void `if`, where only one arm reads the local. |
| `code-pushing-after-if` | A pure computed `local.set` before an ordinary void `if` that does not read the local, followed by same-region suffix reads after the `if`. |
| `code-pushing-dropped-if` | A pure `local.set` before a dropped value `if` that does not read the local, followed by same-region suffix reads after the dropped wrapper. |
| `code-pushing-br-if` | A pure `local.set` before a void-block-target `br_if` that does not read the local, followed by same-block suffix reads after the branch. |
| `code-pushing-multi-set` | Two local-independent pure `local.set` roots before an ordinary void `if`, followed by same-region suffix reads after the `if`, preserving source order. |
| `code-pushing-multi-set-dropped-if` | Two local-independent pure `local.set` roots before a dropped value `if`, followed by same-region suffix reads after the dropped wrapper, preserving source order. |
| `code-pushing-multi-set-br-if` | Two local-independent pure `local.set` roots before a void-block-target `br_if`, followed by same-block suffix reads after the branch, preserving source order. |
| `code-pushing-multi-set-local-copy` | Two adjacent direct local-copy SFA sets before an ordinary void `if`, followed by suffix reads after the `if`, preserving source order and refusing source-local writes. |

The profile intentionally does **not** cover remaining audit gaps such as switch/`br_table`, `br_on_*`, branch-value or loop-target conditional branches, ordered multi-set movement outside the first ordinary-void-`if`, dropped-value-`if`, narrow `br_if`, and local-copy slices, atomics/GC/EH, or trap-option widening. Add new leaves when those families land.

Current bounded dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-profile-200-local-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

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

A raw lane without `--normalize local-cleanup-debris` stopped after `65` raw mismatches in `65` compared cases before the dropped-if slice. Inspected artifacts showed a bounded local-cleanup drift: Starshine removes standalone `nop`/empty-else debris around the movement while Binaryen leaves it. Treat the normalized lane as bounded slice evidence, not final raw-output parity or pass closeout.

## Final closeout lane

Before final `[O4Z-AUDIT-CP]` closeout, run the repo-standard four-lane pass matrix. The dedicated lane should use:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-genvalid-code-pushing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Report `selected_profile` counts from the GenValid manifest separately from the ordinary GenValid, explicit wasm-smith, and random all-profiles lanes.
