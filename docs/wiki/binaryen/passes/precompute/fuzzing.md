---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0795-2026-06-20-precompute-final-closeout.md
  - ../../../raw/research/0794-2026-06-20-precompute-final-evidence-refresh.md
  - ../../../raw/research/0793-2026-06-20-precompute-o4z-boundary-decision.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md
  - ../../../raw/research/0791-2026-06-20-precompute-true-loop-tail-reduction.md
  - ../../../raw/research/0790-2026-06-20-precompute-self-branch-reduction.md
  - ../../../raw/research/0789-2026-06-20-precompute-native-path-and-bounded-evidence.md
  - ../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md
  - ../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md
  - ../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `precompute` Fuzzing Profile

## Current release-gating status

`precompute` now has a dedicated pass-specific GenValid profile: `precompute-all`. Under the modern pass closeout standard, `[O4Z-AUDIT-PC]` is closed for v0.1.0. The 2026-06-20 final-evidence refresh has green current `10000`-case dedicated `precompute-all` and `10000`-case broad `pass-fuzz-stress` lanes with PC normalizers and `_build/native/release/build/cmd/cmd.exe`; the final closeout then adds the missing regular GenValid `100000` lane at `.tmp/pass-fuzz-precompute-final-regular-100000`, which compared `100000/100000` with `15491` normalized, `84509` cleanup-normalized, and `0` mismatches/failures. The explicit wasm-smith `10000` lane found one mismatch where Binaryen erases a reachable `atomic.fence` before a branch-to-end and Starshine preserves it as an ordering barrier; this is accepted as a narrow Starshine correctness boundary backed by local atomics docs and focused test coverage. The O4z no-op gate is decided as an accepted v0.1.0 fail-closed boundary, not as full O4z PC-slot parity.

The final closeout is recorded in [`../../../raw/research/0795-2026-06-20-precompute-final-closeout.md`](../../../raw/research/0795-2026-06-20-precompute-final-closeout.md). The 2026-06-20 refresh in [`../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md`](../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md) found the profile gap. The follow-up in [`../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md`](../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md) added `precompute-all` in `src/validate/gen_valid.mbt` plus focused `src/validate/gen_valid_tests.mbt` coverage. The O4z follow-up in [`../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md`](../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md) recovered only changed raw scalar folds under the O4z gate. The native-path follow-up in [`../../../raw/research/0789-2026-06-20-precompute-native-path-and-bounded-evidence.md`](../../../raw/research/0789-2026-06-20-precompute-native-path-and-bounded-evidence.md) makes `_build/native/release/build/cmd/cmd.exe` the accepted explicit native compare path for this checkout after native build, records a green `1000`-case `precompute-all` smoke, and records an open regular GenValid blocker. The first reduction in [`../../../raw/research/0790-2026-06-20-precompute-self-branch-reduction.md`](../../../raw/research/0790-2026-06-20-precompute-self-branch-reduction.md) fixes the sampled constant self-exiting `block br_if` subgap. The next reduction in [`../../../raw/research/0791-2026-06-20-precompute-true-loop-tail-reduction.md`](../../../raw/research/0791-2026-06-20-precompute-true-loop-tail-reduction.md) fixes the constant-true self-branching loop result-tail subgap. The closeout-normalizer follow-up in [`../../../raw/research/0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md`](../../../raw/research/0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md) classifies the remaining constant-false loop / mixed root-debris family as a Starshine no-op-control cleanup win and reruns the bounded regular lane with `0` mismatches. The O4z boundary follow-up in [`../../../raw/research/0793-2026-06-20-precompute-o4z-boundary-decision.md`](../../../raw/research/0793-2026-06-20-precompute-o4z-boundary-decision.md) accepts only changed `raw-scalar-folds` under O4z and documents that remaining `o4z-precompute-noop` reasons are release boundaries with reopening criteria. The broad named GenValid lane currently available for the fourth closeout slot remains `pass-fuzz-stress`.

## Recommended smoke lane

For ordinary direct-pass development after rebuilding the native CLI, use the repo-standard path only when it exists:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --out-dir .tmp/pass-fuzz-precompute --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

For this checkout, `moon build --target native --release src/cmd` currently emits `_build/native/release/build/cmd/cmd.exe` and leaves `target/native/release/build/cmd/cmd.exe` absent. Precompute signoff lanes in this checkout should therefore use `_build/native/release/build/cmd/cmd.exe` explicitly and record that path in the report.

When replaying the known branch-heavy cleanup family or the dedicated `precompute-all` profile, preserve the normalizers used by the latest recorded evidence so known dropped-constant/local-cleanup/unreachable-control debris reports as `cleanupNormalizedMatchCount` rather than raw mismatch noise:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-branch-heavy-refresh-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The first `precompute-all` smoke in [`../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md`](../../../raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md) compared `50/50` with those normalizers: `25` normalized matches, `25` cleanup-normalized matches, `0` mismatches, and selected-profile coverage across all seven leaves. The later explicit-native smoke in [`../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md`](../../../raw/research/0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md) used `_build/native/release/build/cmd/cmd.exe` with `--jobs auto` because `target/native/release/build/cmd/cmd.exe` was absent; it compared `100/100`, normalized `53`, cleanup-normalized `47`, and had `0` mismatches or failures. The bounded evidence refresh in [`../../../raw/research/0789-2026-06-20-precompute-native-path-and-bounded-evidence.md`](../../../raw/research/0789-2026-06-20-precompute-native-path-and-bounded-evidence.md) raised that dedicated-profile smoke to `1000/1000`, with `544` normalized matches, `456` cleanup-normalized matches, `0` mismatches/failures, and all seven leaves sampled.

The latest post-fix regular GenValid bounded lane in [`../../../raw/research/0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md`](../../../raw/research/0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md) is `.tmp/pass-fuzz-precompute-loop-nop-normalizer-direct-100`. It compared `100/100`, normalized `16`, cleanup-normalized `84`, and had `0` mismatches with no validation/generator/property/command failures. The prior `.tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100` lane still had `20` raw mismatches after PC normalizers; the follow-up classifies those as exact no-op control-wrapper debris (`loop (nop)` / empty wrapper and adjacent self-exiting block debris) where Starshine's smaller output is a focused-test-backed cleanup win. The later final-evidence refresh in [`../../../raw/research/0794-2026-06-20-precompute-final-evidence-refresh.md`](../../../raw/research/0794-2026-06-20-precompute-final-evidence-refresh.md) raises regular GenValid to `.tmp/pass-fuzz-precompute-final-refresh-direct-10000`, comparing `10000/10000` with `1547` normalized, `8453` cleanup-normalized, and `0` mismatches/failures. The final closeout in [`../../../raw/research/0795-2026-06-20-precompute-final-closeout.md`](../../../raw/research/0795-2026-06-20-precompute-final-closeout.md) then runs the required `100000` regular lane at `.tmp/pass-fuzz-precompute-final-regular-100000`, comparing `100000/100000` with `15491` normalized, `84509` cleanup-normalized, and `0` mismatches/failures.

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

The final direct closeout reports these lanes separately:

1. regular GenValid: `.tmp/pass-fuzz-precompute-final-regular-100000` (`--count 100000 --seed 0x5eed --pass precompute`) with the documented PC cleanup normalizers compared `100000/100000`, normalized `15491`, cleanup-normalized `84509`, and had `0` mismatches/failures.
2. explicit wasm-smith: `.tmp/pass-fuzz-precompute-final-refresh-wasm-smith-10000` (`--wasm-smith --count 10000 --seed 0x5eed --pass precompute`) compared `9956/10000`, normalized `9952`, cleanup-normalized `3`, command failures `44` in Binaryen/oracle classes, and one accepted reachable-`atomic.fence` Starshine correctness-boundary mismatch.
3. dedicated precompute GenValid: `.tmp/pass-fuzz-precompute-final-refresh-precompute-all-10000` (`--count 10000 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all`) compared `10000/10000`, normalized `5413`, cleanup-normalized `4587`, and had `0` mismatches/failures; all seven leaves were sampled.
4. broad named GenValid: `.tmp/pass-fuzz-precompute-final-refresh-pass-fuzz-stress-10000` (`--count 10000 --seed 0x5555 --pass precompute --gen-valid-profile pass-fuzz-stress`) compared `10000/10000`, normalized `1529`, cleanup-normalized `8471`, and had `0` mismatches/failures.

Report future reruns with requested count, compared count, normalized and cleanup-normalized matches, raw mismatches, generator/validation/property failures, command-failure classes, cache counters, selected-profile counts, and pass-local timings separately for each lane.
