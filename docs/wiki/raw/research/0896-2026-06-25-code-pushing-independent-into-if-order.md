# 0896 - code-pushing independent into-if source order

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-006]` by preserving source order when multiple independent `local.set` roots are sunk into the sole consuming `if` arm?

## Answer

Yes. Starshine now handles the reduced independent two-set into-if family by using the same ordered multi-set into-if path as the dependency-chain slice. This prevents the older fixed-point single-set behavior from sinking the first set, then sinking the second set at the beginning of the arm and reversing their source order.

This is a source-order / Binaryen-shape refinement for already-safe independent pure sets. It is not a broader arbitrary non-adjacent or two-arm duplication implementation.

## Source-backed shape

Replacement-oriented research for `[CP-BINREP-006]` found a reduced Binaryen v130 probe where independent pure sets keep source order inside the consuming arm:

```wat
(local.set $a (i32.const 7))
(local.set $b (i32.const 9))
(if (local.get $cond)
  (then
    (drop (local.get $a))
    (drop (local.get $b))))
```

Before this slice, Starshine moved the sets independently across fixed-point rounds and produced `$b` before `$a` in the arm. The result was semantically safe for pure independent constants, but the replacement follow-up asked Starshine to prefer Binaryen source order where feasible.

## Implementation

Changed `src/passes/code_pushing.mbt`:

- widened the existing consecutive into-if multi-set helper from dependency-required chains to all consecutive eligible multi-set windows;
- preserved the source-order insertion used by the dependency-chain implementation;
- retained the existing guards: at least two consecutive `local.set` roots immediately before a void `if`, one consuming arm, no two-arm use, SFA writes, no outside uses beyond the admitted proof, no source/moved-local writes in the arm, and movable values only.

Added focused red-first coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing preserves source order for independent sets sunk into if arm`.

The test failed before implementation with `2 != 1`, showing the reversed arm order.

## Validation

- Red confirmation: `moon test --target native src/passes/code_pushing_test.mbt` failed before implementation only in the new source-order test (`2 != 1`).
- Focused after implementation: `moon test --target native src/passes/code_pushing_test.mbt` passed `126/126` with pre-existing warnings.
- `moon fmt`: passed / no work to do.
- `moon test src/passes`: passed `2835/2835`.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings.
- Bounded dedicated compare smoke with the existing local-cleanup normalizer:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-all-1000-20260625-binrep006-order \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 hits/0 misses`.

## Remaining follow-up

`[CP-BINREP-006]` is complete for the reduced consecutive independent into-if source-order family. `[O4Z-AUDIT-CP-BINREP]` remains active for `[CP-BINREP-003]` `ignore-implicit-traps`, `[CP-BINREP-004]` no-effects intrinsic calls, `[CP-BINREP-005]` GC/ref surfaces, and `[CP-BINREP-007]` low-priority branch/switch probes.
