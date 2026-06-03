---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ../monomorphize/starshine-strategy.md
  - ../inlining/starshine-strategy.md
  - ../inline-main/index.md
  - ../tracker.md
---

# Starshine strategy for `monomorphize-always`

## Current status

Starshine does **not** implement `monomorphize-always` today.

The exact local status is:

- `src/passes/optimize.mbt` lists `monomorphize-always` in `pass_registry_boundary_only_names()`.
- `pass_registry_entry_boundary_only(...)` gives boundary-only entries no descriptor and no expanded pass list.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only entries with `pass flag <name> is boundary-only and is not implemented in the hot pipeline`.
- `src/passes/registry_test.mbt` proves the registry distinguishes active, module, boundary-only, removed, and preset names; the sibling is part of the same boundary-only name set as ordinary `monomorphize`.
- `agent-todo.md` has no dedicated `monomorphize-always` backlog slice on 2026-04-24.

So the current implementation strategy is honestly: **track the public upstream name, reject active execution, and preserve enough planning context for a later shared `monomorphize` / `monomorphize-always` module pass.**

## Why this is boundary-only rather than removed

This pass is not a small local HOT peephole waiting for an IR2 rewrite.
It is a whole-module specialization pass that needs:

- a call graph over defined functions
- callsite-context extraction
- effect-safe movement of operand expressions into the callee clone
- function cloning
- function-type and local-index repair
- callsite retargeting
- nested optimization of the new clone
- a public policy split from ordinary `monomorphize`

That puts it beside the other module/boundary passes in `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`, where `monomorphize` and `monomorphize-always` are both listed under whole-module or layout transforms.

## Current Starshine code map

### Registry and request rejection

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `HotPassRegistryCategory::BoundaryOnly` defines the category used for the sibling.
  - `pass_registry_boundary_only_names()` contains both `monomorphize` and `monomorphize-always`.
  - `run_hot_pipeline_expand_passes(...)` is the active guard that rejects explicit requests before any HOT or module pass can run.

### Test coverage for local classification

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - Proves the registry category model used by active, module, boundary-only, removed, and preset names.
  - Future work should add explicit assertions for `monomorphize` and `monomorphize-always` when the classification test is next broadened.

### CLI and config surfaces that are related but not sufficient

- [`src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
  - Parses arbitrary long pass flags into `parsed.pass_flags`, which is why a `--monomorphize-always` request can reach the optimizer registry instead of failing in the CLI parser.
  - Also parses `--monomorphize-min-benefit`, but that option is only policy plumbing; it does not implement ordinary `monomorphize` or the always sibling.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - Carries `monomorphize_min_benefit` through command/config/environment resolution.
  - This is useful future infrastructure for ordinary `monomorphize`, but `monomorphize-always` must still be modeled as a separate pass identity.
- [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
  - Covers command/config behavior around `monomorphizeMinBenefit` / `--monomorphize-min-benefit`.
  - This is adjacent option coverage, not a sibling-pass execution proof.

### Planning and backlog surfaces

- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
  - Places `monomorphize` and `monomorphize-always` in the whole-module / layout-transform family.
- [`agent-todo.md`](../../../../../agent-todo.md)
  - No current dedicated `monomorphize-always` slice was found in this run.

## What a faithful future Starshine port must share with `monomorphize`

A Starshine implementation should not create an independent rewrite engine for the sibling.
Binaryen's source-backed model is one shared specialization engine with two public policies.

The shared engine needs to preserve:

1. candidate direct-call discovery over original defined functions
2. imported / recursive / unreachable call bailouts
3. effect-safe operand movement into a `CallContext`-like representation
4. trivial-context rejection
5. signature rebuilding from surviving dynamic `local.get` inputs
6. local-index and local-name repair in cloned functions
7. dropped-result clone support when return-call-sensitive forms make it safe
8. `MaxParams`-style guardrails for huge specialized signatures
9. nested optimization of the cloned function before final policy acceptance
10. callsite retargeting and module insertion of the accepted clone

The sibling-specific Starshine behavior should be tiny:

- `monomorphize` keeps only clones that pass the configured benefit policy.
- `monomorphize-always` keeps legal nontrivial clones without that final usefulness rejection.

## Why `--monomorphize-min-benefit=0` is not enough as a local strategy

Starshine already has `monomorphize_min_benefit` option plumbing.
That does not make `monomorphize-always` implemented.

The wiki should keep three facts separate:

1. upstream exposes a separate public pass named `monomorphize-always`
2. upstream also exposes threshold policy tuning for ordinary `monomorphize`
3. current Starshine has option storage but no clone-building engine for either public pass

The exact overlap between upstream always mode and a zero threshold remains a close relationship, not a Starshine implementation shortcut.

## Validation plan for a future port

A future implementation should validate in layers:

1. Registry tests: `monomorphize` and `monomorphize-always` become active module-pass names together, with separate public identity.
2. Parser/CLI tests: explicit `--monomorphize-always` succeeds once the module pass exists, while `--monomorphize-min-benefit` still configures ordinary `monomorphize`.
3. Unit fixtures: start from refined-type and weak-benefit call shapes from [`./wat-shapes.md`](./wat-shapes.md).
4. Parent parity: share all safety and clone-construction tests with [`../monomorphize/index.md`](../monomorphize/index.md).
5. Sibling parity: compare against Binaryen on `monomorphize-types.wast`, because that is the direct upstream lit file that runs `--monomorphize-always`.
6. Fuzz signoff: after `moon build --target native --release src/cmd`, add a pass-targeted `bun scripts/pass-fuzz-compare.ts --pass monomorphize-always ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` lane only after ordinary `monomorphize` has a green shared engine.

## Current non-goals

- Do not pretend the existing `monomorphize_min_benefit` option is a pass implementation.
- Do not model `monomorphize-always` as a HOT pass; its core rewrite is whole-module function cloning and callsite retargeting.
- Do not flatten the sibling into ordinary `monomorphize` documentation; upstream publishes a separate public pass name, and Starshine's registry already tracks it separately.
- Do not schedule it into the canonical no-DWARF path without separate evidence; the current no-DWARF page does not make this sibling part of the required parity sequence.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
