---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
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

Use `code-pushing-all` for the pass-specific lane. It is a deterministic composite over three currently implemented positive families:

| Leaf profile | Shape |
| --- | --- |
| `code-pushing-if-arm` | A pure `local.set` before a void `if`, where only one arm reads the local. |
| `code-pushing-after-if` | A pure computed `local.set` before an ordinary void `if` that does not read the local, followed by same-region suffix reads after the `if`. |
| `code-pushing-dropped-if` | A pure `local.set` before a dropped value `if` that does not read the local, followed by same-region suffix reads after the dropped wrapper. |

The profile intentionally does **not** cover remaining audit gaps such as conditional branches, switch/`br_table`, ordered multi-set movement, atomics/GC/EH, or trap-option widening. Add new leaves when those families land.

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

A raw lane without `--normalize local-cleanup-debris` stopped after `65` raw mismatches in `65` compared cases before the dropped-if slice. Inspected artifacts showed a bounded local-cleanup drift: Starshine removes standalone `nop`/empty-else debris around the movement while Binaryen leaves it. Treat the normalized lane as bounded slice evidence, not final raw-output parity or pass closeout.

## Final closeout lane

Before final `[O4Z-AUDIT-CP]` closeout, run the repo-standard four-lane pass matrix. The dedicated lane should use:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-genvalid-code-pushing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Report `selected_profile` counts from the GenValid manifest separately from the ordinary GenValid, explicit wasm-smith, and random all-profiles lanes.
