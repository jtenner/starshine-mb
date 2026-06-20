---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md
  - ../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md
  - ../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `precompute` Fuzzing Profile

## Current release-gating status

`precompute` now has a dedicated pass-specific GenValid profile: `precompute-all`. Under the modern pass closeout standard, `[O4Z-AUDIT-PC]` is still not closed because the profile has not yet been used in the required `10000`-case dedicated closeout lane, the regular `100000` and wasm-smith lanes still need a current rerun, and the current O4z no-op gate still needs a recovery/decision slice.

The 2026-06-20 refresh in [`../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md`](../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md) found the profile gap. The follow-up in [`../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md`](../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md) added `precompute-all` in `src/validate/gen_valid.mbt` plus focused `src/validate/gen_valid_tests.mbt` coverage. The O4z follow-up in [`../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md`](../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md) recovered only changed raw scalar folds under the O4z gate and found that this checkout's explicit native binary path is `_build/native/release/build/cmd/cmd.exe`, not the documented `target/native/release/build/cmd/cmd.exe`. The broad named GenValid lane currently available for the fourth closeout slot remains `pass-fuzz-stress`.

## Recommended smoke lane

For ordinary direct-pass development after rebuilding the native CLI, start with the repo-standard path when it exists:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --out-dir .tmp/pass-fuzz-precompute --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

If that `target/...` path is absent after `moon build --target native --release src/cmd`, this checkout currently emits `_build/native/release/build/cmd/cmd.exe`; use that explicit path only after recording the deviation in the signoff report.

When replaying the known branch-heavy cleanup family or the dedicated `precompute-all` profile, preserve the normalizers used by the latest recorded evidence so known dropped-constant/local-cleanup/unreachable-control debris reports as `cleanupNormalizedMatchCount` rather than raw mismatch noise:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-branch-heavy-refresh-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The first `precompute-all` smoke in [`../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md`](../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md) compared `50/50` with those normalizers: `25` normalized matches, `25` cleanup-normalized matches, `0` mismatches, and selected-profile coverage across all seven leaves. The later explicit-native smoke in [`../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md`](../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md) used `_build/native/release/build/cmd/cmd.exe` with `--jobs auto` because `target/native/release/build/cmd/cmd.exe` was absent; it compared `100/100`, normalized `53`, cleanup-normalized `47`, and had `0` mismatches or failures.

## Dedicated profile

Dedicated GenValid profile: `precompute-all`.

`precompute-all` is a composite/aggregate profile. Its manifest `selected_profile` values are deterministic leaves:

- `precompute-scalar`: exact i32/i64 scalar arithmetic, comparisons, unary `eqz`, and shifts;
- `precompute-control`: constant `if` and result/control cleanup shapes;
- `precompute-global`: immutable defined-global constants, including scalar and `ref.null` positives;
- `precompute-drop-cleanup`: raw/drop/block cleanup and typed `select` cleanup inputs;
- `precompute-effect-boundary`: deliberate non-fold boundaries for division, loads, calls, and mutable globals;
- `precompute-gc-atomic-boundary`: GC/array boundaries including struct atomic gets and mutable array gets;
- `precompute-direct-prefix-watch`: direct-vs-private-prefix watchpoints with local set/get/tee traffic so the profile does not silently assert public `precompute-propagate` parity.

Focused generator tests prove the profile resolves through `precompute` / `precompute-closeout` aliases, samples every current leaf, emits validating modules, records selected leaf metadata through composite sampling, and actually creates direct `precompute` optimization opportunities or intentional boundaries.

## Required final closeout lanes

After a dedicated profile exists, final direct closeout should report these lanes separately:

1. regular GenValid: `--count 100000 --seed 0x5eed --pass precompute`;
2. explicit wasm-smith: `--wasm-smith --count 10000 --seed 0x5eed --pass precompute`;
3. dedicated precompute GenValid: `--count 10000 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris`;
4. broad named GenValid: `--count 10000 --seed 0x5555 --pass precompute --gen-valid-profile pass-fuzz-stress` unless a literal random all-profiles profile exists by then.

Report requested count, compared count, normalized and cleanup-normalized matches, raw mismatches, generator/validation/property failures, command-failure classes, cache counters, selected-profile counts, and pass-local timings separately for each lane.
