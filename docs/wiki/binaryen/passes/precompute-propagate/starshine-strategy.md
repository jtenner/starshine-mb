---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_propagate_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_precompute_propagate_tests.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../precompute/index.md
  - ../precompute/starshine-hot-ir-strategy.md
  - ../dae-optimizing/starshine-strategy.md
  - ../inlining-optimizing/starshine-strategy.md
---

# Starshine `precompute-propagate` strategy

## Current status

`precompute-propagate` is an active public Starshine hot/function pass.

It is not an alias of plain `precompute`. The public runner performs:

1. one SSA-backed local-fact solve;
2. replacement of only concrete, type-matching local reads whose reaching facts agree;
3. one bounded plain-precompute evaluator/cleanup run.

This preserves Binaryen's mode split and stopping rule while reusing Starshine's accepted plain-precompute base.

## Public code map

### Descriptor and implementation

[`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt) owns:

- `precompute_propagate_descriptor()` with an SSA requirement and conservative analysis invalidation;
- `precompute_propagate_summary()`;
- literal/default-local payload handling;
- recursive evaluation of set fallthrough values, direct tees, unbranched value blocks, constant-selected `if` values, and exact unary/binary expressions;
- phi/reaching-value consensus;
- the one-solve/one-rerun public runner.

The same file retains plain `precompute` as a separate descriptor and runner.

### Registry, presets, and dispatch

[`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):

- removes `precompute-propagate` from removed-name handling;
- registers the exact public name;
- uses it in both aggressive optimize/shrink PC slots.

[`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):

- dispatches the exact public name;
- gives it the same lowering, empty-function, escape-carrier, and per-function writeback validation treatment as plain precompute;
- uses conservative raw propagation before retained load/call/set and large-lowered no-op gates when the raw evaluator proves a changed result; selected structured `memory.grow` functions also use this path, while unsupported SIMD/parser/`br_table` hazards remain fail-closed;
- uses the public pass in DAE's touched-function nested prefix.

[`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt) uses the public descriptor for its optimizing nested prefix as well. The former private `precompute-propagate-prefix` descriptor/runner no longer exists.

### Harness and generator

[`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) accepts `--pass precompute-propagate` and maps it to Binaryen's `--precompute-propagate`.

[`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) exposes `precompute-propagate-local-facts`, with compatibility aliases `precompute-propagate` and `precompute-propagate-closeout`.

The profile emits:

- agreeing branch definitions;
- differing-definition bailouts;
- defaultable-local entry reads;
- direct and block-fallthrough tees;
- a bounded chained propagation/evaluation opportunity;
- a parameter boundary.

## Safety boundaries

### Result-producing `if` writes

The artifact closeout exposed a HOT SSA limitation: branch-local writes nested inside a result-producing `if` can be absent from the post-expression merge. Propagating a stale default or prior fact is unsound.

Starshine therefore fails closed for every local written in a result-`if` arm. It also refuses a direct default-init origin when that local has any write in the function. Focused tests cover both stale-default and stale-prior-fact forms.

This is a conservative local representation boundary, not a Binaryen semantic difference. Reopen it when HOT SSA proves complete post-expression merges for result-producing control.

### Large lowered functions and known lowering hazards

Public propagation inherits plain precompute's raw safety gates:

- load/call/set ownership hazards;
- more than `64` locals together with more than `500` lowered instructions;
- the SIMD/parser/`br_table` stack hazard.

These guards prevented an invalid self-optimized output in function `2641`. They remain correctness gates, not optimization claims.

### Shared plain-precompute scope

The propagating member reuses Starshine's plain-precompute evaluator. The July 18 follow-up closes the reduced returned-scalar, repeated partial-`select`, fresh-GC array/struct/default/packed-read, single-`local.tee` effect-retention, result-`if`, large-function, and self-hosted tee gaps. Broader string, general `Flow`, alias-aware heap-cache/nested-aggregate, multi-effect retention, emitability, and type-refinalization work remains shared evaluator architecture rather than propagation-specific local consensus.

## Tests

[`src/passes/precompute_propagate_test.mbt`](../../../../../src/passes/precompute_propagate_test.mbt) covers fifteen behavior and safety families:

- plain-versus-propagating distinction;
- agreeing and differing reaching definitions;
- default-entry zero;
- tee/block fallthrough;
- stale and agreeing result-`if` behavior;
- direct condition-tee facts;
- high-local large-function positive propagation;
- reachable atomic-fence preservation with surrounding cleanup;
- raw loop invariants and loop-carried-local invalidation;
- bounded one-solve/one-rerun behavior.

Registry, preset, and nested scheduler expectations are covered in:

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt);
- [`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt);
- [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt).

Generator name, limits, validation, and trigger floors are covered by [`src/validate/gen_valid_precompute_propagate_tests.mbt`](../../../../../src/validate/gen_valid_precompute_propagate_tests.mbt).

## Signoff summary

The retained closeout is [`../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md`](../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md).

Key results against Binaryen `version_130`:

- regular GenValid: `100000/100000`, zero mismatches/failures;
- dedicated local-facts profile: `10000/10000`, zero mismatches/failures;
- broad `pass-fuzz-stress`: `10000/10000`, zero mismatches/failures;
- wasm-smith: `9956/10000` compared, two classified inherited/size-winning differences and `44` Binaryen parser/tool failures;
- completed random-all profiles: `10000/10000`, `2973` raw differences, all `2973` canonically smaller for Starshine and none larger;
- repeated self-optimization benchmark: valid output, Starshine canonical output `80,049` bytes (`1.716%`) smaller; across 15 measured processes after one warmup, pass-local medians are `694.444 ms` versus Binaryen `505.591 ms` (Starshine `1.374x` slower but within the maintained `2x` ceiling), while whole-command medians are `7,330.096 ms` versus `1,110.672 ms` (`6.600x` slower end to end due to non-pass infrastructure overhead).

The former first difference at defined `4`, absolute `31` is closed. The first difference is now defined `24`, absolute `51`, where Starshine's valid result-typed shape is smaller than Binaryen's refinalized unreachable form.

## Maintenance rule

- Keep plain and propagating descriptors separate.
- Preserve the one-solve/one-rerun bound.
- Keep stale result-`if` facts rejected unless a real phi or direct condition proof exists; keep raw branch/loop facts conservative and invalidate loop-written locals before body evaluation.
- Use the public descriptor in all top-level and nested propagating slots; do not recreate a private prefix fork.
- Use Binaryen `version_130` as the released oracle and keep inherited plain-precompute boundaries explicit.
