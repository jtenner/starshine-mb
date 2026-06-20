---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md
  - ../../../../../src/validate/gen_valid.mbt
---

# `precompute` Fuzzing Profile

## Current release-gating status

`precompute` is still missing a dedicated pass-specific GenValid profile. Under the modern pass closeout standard, that means `[O4Z-AUDIT-PC]` cannot be closed yet even though the older branch-heavy direct compare evidence remains useful.

The 2026-06-20 refresh in [`../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md`](../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md) found:

- `bun scripts/pass-fuzz-compare.ts --list-passes | grep precompute` prints `precompute`;
- no `precompute` profile constructors are present in `src/validate/gen_valid.mbt`;
- the broad named GenValid lane currently available for the fourth closeout slot is `pass-fuzz-stress`;
- no prebuilt `target/native/release/build/cmd/cmd.exe` was present in that checkout, so no fresh compare lane was run during the docs-only refresh.

## Recommended smoke lane

For ordinary direct-pass development after rebuilding the native CLI, start with:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --out-dir .tmp/pass-fuzz-precompute --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

When replaying the known branch-heavy cleanup family, preserve the normalizers used by the latest recorded evidence:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-branch-heavy-refresh-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Missing dedicated profile

Dedicated GenValid profile: none yet.

The intended profile should be a composite/aggregate, tentatively `precompute-all`, with selected-profile metadata for at least these families:

- exact i32/i64 scalar arithmetic, comparisons, and shifts;
- constant `if` and branch-free control cleanup;
- immutable defined-global constants, including scalar and `ref.null` positives;
- raw drop/block cleanup and preserved dropped effect/trap boundaries;
- deliberate non-fold boundaries for division/remainder, loads, calls, mutable globals, GC/array atomics, and other effectful or trapping expressions;
- a watchpoint family for public direct `precompute` versus the private nested `precompute-propagate-prefix` helper, so the profile does not silently assert public `precompute-propagate` parity.

Add focused generator tests proving the profile resolves, emits validating modules, records the chosen subprofile/family, and actually creates direct `precompute` optimization opportunities or intentional boundaries.

## Required final closeout lanes

After a dedicated profile exists, final direct closeout should report these lanes separately:

1. regular GenValid: `--count 100000 --seed 0x5eed --pass precompute`;
2. explicit wasm-smith: `--wasm-smith --count 10000 --seed 0x5eed --pass precompute`;
3. dedicated precompute GenValid: `--count 10000 --seed 0x5eed --pass precompute --gen-valid-profile <precompute-profile>`;
4. broad named GenValid: `--count 10000 --seed 0x5555 --pass precompute --gen-valid-profile pass-fuzz-stress` unless a literal random all-profiles profile exists by then.

Report requested count, compared count, normalized and cleanup-normalized matches, raw mismatches, generator/validation/property failures, command-failure classes, cache counters, selected-profile counts, and pass-local timings separately for each lane.
