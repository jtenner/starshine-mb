---
kind: workflow
status: working
last_reviewed: 2026-07-26
sources:
  - ../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `precompute` Fuzzing Profile

## Current release-gating status

`precompute` has the dedicated `precompute-all` profile and is closed at Binaryen-v131-or-better behavior parity after the 2026-07-26 correctness-repair renewal. The current matrix uses explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`, `_build/native/release/build/cmd/cmd.exe`, cache `.tmp/pass-fuzz-cache-precompute-v131-renewal`, and the reviewed local/unreachable cleanup normalizers. Regular `100000`, dedicated `10000`, random all-profiles `10000`, and wasm-smith `10000` request lanes are complete. The only Starshine-larger family is intentional preservation of reachable `atomic.fence`; every other raw difference is a source-inspected smaller dead-value/control cleanup.

The final closeout is recorded in [research note 0795](./index.md). The 2026-06-20 refresh in [research note 0785](./index.md) found the profile gap. The follow-up in [research note 0787](./index.md) added `precompute-all` in `src/validate/gen_valid.mbt` plus focused `src/validate/gen_valid_tests.mbt` coverage. The O4z follow-up in [research note 0788](./index.md) recovered only changed raw scalar folds under the O4z gate. The native-path follow-up in [research note 0789](./index.md) makes `_build/native/release/build/cmd/cmd.exe` the accepted explicit native compare path for this checkout after native build, records a green `1000`-case `precompute-all` smoke, and records an open regular GenValid blocker. The first reduction in [research note 0790](./index.md) fixes the sampled constant self-exiting `block br_if` subgap. The next reduction in [research note 0791](./index.md) fixes the constant-true self-branching loop result-tail subgap. The closeout-normalizer follow-up in [research note 0792](./index.md) classifies the remaining constant-false loop / mixed root-debris family as a Starshine no-op-control cleanup win and reruns the bounded regular lane with `0` mismatches. The O4z boundary follow-up in [research note 0793](./index.md) accepts only changed `raw-scalar-folds` under O4z and documents that remaining `o4z-precompute-noop` reasons are release boundaries with reopening criteria. The broad named GenValid lane currently available for the fourth closeout slot remains `pass-fuzz-stress`.

## Recommended smoke lane

For ordinary direct-pass development after rebuilding the native CLI, use the repo-standard path only when it exists:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --out-dir .tmp/pass-fuzz-precompute --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

For this checkout, use `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd`. A `target/native/...` artifact can coexist but is not signoff evidence unless freshness is verified against the current `_build/...` binary; see [`../../../AGENTS.md`](../../../AGENTS.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

When replaying the known branch-heavy cleanup family or the dedicated `precompute-all` profile, preserve the normalizers used by the latest recorded evidence so known dropped-constant/local-cleanup/unreachable-control debris reports as `cleanupNormalizedMatchCount` rather than raw mismatch noise:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-branch-heavy-refresh-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The first `precompute-all` smoke in [research note 0787](./index.md) compared `50/50` with those normalizers: `25` normalized matches, `25` cleanup-normalized matches, `0` mismatches, and selected-profile coverage across all seven leaves. The later explicit-native smoke in [research note 0788](./index.md) used `_build/native/release/build/cmd/cmd.exe` with `--jobs auto` because `target/native/release/build/cmd/cmd.exe` was absent; it compared `100/100`, normalized `53`, cleanup-normalized `47`, and had `0` mismatches or failures. The bounded evidence refresh in [research note 0789](./index.md) raised that dedicated-profile smoke to `1000/1000`, with `544` normalized matches, `456` cleanup-normalized matches, `0` mismatches/failures, and all seven leaves sampled.

The latest post-fix regular GenValid bounded lane in [research note 0792](./index.md) is `.tmp/pass-fuzz-precompute-loop-nop-normalizer-direct-100`. It compared `100/100`, normalized `16`, cleanup-normalized `84`, and had `0` mismatches with no validation/generator/property/command failures. The prior `.tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100` lane still had `20` raw mismatches after PC normalizers; the follow-up classifies those as exact no-op control-wrapper debris (`loop (nop)` / empty wrapper and adjacent self-exiting block debris) where Starshine's smaller output is a focused-test-backed cleanup win. The later final-evidence refresh in [research note 0794](./index.md) raises regular GenValid to `.tmp/pass-fuzz-precompute-final-refresh-direct-10000`, comparing `10000/10000` with `1547` normalized, `8453` cleanup-normalized, and `0` mismatches/failures. The final closeout in [research note 0795](./index.md) then runs the required `100000` regular lane at `.tmp/pass-fuzz-precompute-final-regular-100000`, comparing `100000/100000` with `15491` normalized, `84509` cleanup-normalized, and `0` mismatches/failures.

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

The current 2026-07-26 v131 direct closeout reports these lanes separately:

1. regular GenValid: `.tmp/pass-fuzz-precompute-v131-renewal-closeout-regular-100000`, `100000/100000`, `36953` direct plus `63047` cleanup-normalized, zero mismatches or failures;
2. explicit wasm-smith: `.tmp/pass-fuzz-precompute-v131-renewal-closeout-wasm-smith-10000`, `9956/10000` comparable, `9955` direct, one accepted reachable-`atomic.fence` Starshine correctness win at case `6523`, and `44` Binaryen-only tool failures;
3. dedicated `precompute-all`: `.tmp/pass-fuzz-precompute-v131-renewal-final-dedicated-10000`, `10000/10000`, `8249` direct plus `1751` cleanup-normalized, zero mismatches or failures. The manifest samples all eleven current leaves, including `precompute-control`'s type-indexed multivalue branch carrier;
4. random all-profiles: `.tmp/pass-fuzz-precompute-v131-renewal-closeout-random-all-10000`, `10000/10000`, `4314` direct, `1524` cleanup-normalized, and `4162` classified differences. `3834` remove only dropped local/global/ref-function reads, pure values, and redundant control wrappers and are smaller by `2..71` bytes. `328` `merge-blocks-eh-atomic` cases retain reachable `atomic.fence` and are each `2` bytes larger. The net canonical delta is `-74,307` bytes.

The wasm-smith command failures are unchanged Binaryen parser/tool families: `39` zero-length recursive groups, one invalid tag index, one table index out of range, and three bad section sizes. The random-all lane was interrupted by the command timeout after `8877` cases and completed with `--resume`; its final result records the remaining `1123` Binaryen cache hits, while the other one-shot GenValid lanes are full cache hits.

Fresh runtime/idempotence evidence lives at `.tmp/pass-fuzz-precompute-v131-renewal-closeout-runtime-idempotence-500`: `500/500` idempotence matches, `475` Node-supported executions, `25` unsupported GC/reference cases, and zero semantic/property/validation/command failures. Fresh debug-WASI evidence at `.tmp/self-opt-precompute-v131-renewal-closeout` validates both outputs: Starshine is `5,260,101` canonical bytes versus Binaryen `5,233,176` (`+26,925`, `+0.515%`), while seven timing-only samples give pass-local medians `39.462 ms` versus `185.419 ms` (`0.213x`). The first canonical difference is defined `23` / absolute `50`, where Starshine keeps valid result-typed return-dominated control and Binaryen emits void control plus trailing `unreachable`; the small size loss is retained with a material pass-local speed win. Report future reruns with requested and compared counts, direct and cleanup-normalized matches, agent-classified differences, validation/generator/property/command failures, cache counters, selected-profile counts, and pass-local timings.
