---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-simplify-locals-nonesting-port-readiness-primary-sources.md
  - ../../../raw/research/0407-2026-04-26-simplify-locals-nonesting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals/starshine-hot-ir-strategy.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
  - ../souperify/index.md
  - ../tracker.md
---

# Starshine `simplify-locals-nonesting` port readiness and validation

## Why this page exists

The main dossier already explains what Binaryen does.
The Starshine strategy page already says the pass is not implemented locally.
This page fills the remaining implementation-readiness gap:

- what is the smallest honest local slice?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- what tests and oracle lanes prove the flatness policy?

## Current hold point

Starshine currently treats this pass as a removed compatibility name, not an active pass.
The state to preserve until implementation starts is:

- upstream Binaryen spelling: `simplify-locals-nonesting`
- current local spelling: `simplify-locals-no-nesting`
- current local category: removed
- current CLI behavior: rejected as an unknown executable pass flag by the command-layer category gate
- current lower-level pipeline behavior: rejected as removed if it reaches `run_hot_pipeline_expand_passes(...)`
- current owner: none
- current preset role: none

## Code surfaces a future port must touch deliberately

| Surface | Code location | Why it matters |
| --- | --- | --- |
| Removed-name registry | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `pass_registry_removed_names()` | Proves the local alias exists only as `simplify-locals-no-nesting` today. |
| Active registry entry shape | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `pass_registry_entries()` | A real port would need a hot-pass entry, likely using the upstream spelling and/or alias tests. |
| Preset omission | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `optimize_preset_passes(...)` and `shrink_preset_passes(...)` | Prevents accidental scheduling before parity evidence exists. |
| Removed-pass rejection | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `run_hot_pipeline_expand_passes(...)` | Gives the current explicit lower-level error path. |
| CLI pass gate | [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt), `cmd_resolve_pipeline_steps(...)` | Keeps removed names from becoming executable CLI flags by accident. |
| Hot dispatcher | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), `hot_pass_run(...)` | A new descriptor must dispatch to the correct policy mode. |
| Full locals implementation | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), `simplify_locals_descriptor()` / `simplify_locals_run(...)` | Best landing zone, but currently owns the full pass, including behavior the nonesting sibling must disable. |
| Structure rewrite phase | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), `simplify_locals_run_structure_rewrites(...)` | Must be gated off for `allowStructure = false`. |
| Late equivalent/dead cleanup | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), late equivalent cleanup plus dead cleanup in `simplify_locals_run(...)` | Reusable later, but should follow after flatness-policy negatives are green. |

## Recommended first slice

### Slice 0: registry honesty

Before any rewrite:

- decide the spelling policy:
  - add upstream `simplify-locals-nonesting`,
  - keep local `simplify-locals-no-nesting`, or
  - support both with one canonical descriptor;
- add registry tests for the chosen names;
- keep presets unchanged;
- keep CLI behavior explicit while the pass is still removed or skeleton-only.

Exit criteria:

- tests show exactly which names are accepted, rejected, hidden, or aliased;
- docs and help do not imply the pass is active before it is.

### Slice 1: no-rewrite policy skeleton

Add a policy-mode entry point beside the active full `simplify-locals` implementation.
Model the Binaryen axes directly:

- `allow_tee = false`
- `allow_structure = false`
- `allow_nesting = false`

This skeleton should be able to run and report no changes before mutating logic is enabled.

Exit criteria:

- the pass can be requested in focused tests if the registry policy makes it active;
- it does not change output;
- validation after the pass remains green.

### Slice 2: flat copy cleanup only

Implement the minimum useful Binaryen-positive families:

1. `local.set $b (local.get $a)` followed by uses of `$b` can retarget to `$a` when that preserves flatness.
2. A value may move into another `local.set` value position when the move does not create an ordinary nested consumer.
3. Dead local writes exposed by those flat rewrites can be cleaned only if the cleanup does not require the disabled structure or tee families.

Exit criteria:

- dedicated positive tests cover flat copy-chain retargeting;
- dedicated positive tests cover direct set-value rewriting;
- no `local.tee` is introduced;
- no block / `if` / loop result carrier is introduced;
- no non-copy expression is moved under `drop`, call operands, arithmetic operands, branch payloads, or control conditions.

### Slice 3: late cleanup reuse

Only after Slice 2 is stable, reuse the late equivalent-local and dead-set cleanup families from the full pass.

Exit criteria:

- equivalent-copy cleanup works on flat local-copy classes;
- dead-set cleanup removes only now-dead local shells;
- the same negative fixtures still prove no fresh nesting, teeing, or structure synthesis.

## Negative tests that should exist before mutating code

Add these before enabling real rewrites:

- multi-use non-copy temp that full `simplify-locals` could tee;
- computed value consumed by `drop`;
- computed value consumed by `call`;
- computed value consumed by arithmetic;
- computed value used as an `if` condition;
- branch payload temp where inlining would create nested payload computation;
- block / `if` / loop local-set patterns that full `simplify-locals` might convert to result carriers;
- effectful producer followed by memory/global/table/atomic/EH barrier;
- dangling-pop or EH-sensitive value shape if the local HOT surface can represent it.

The core rule is simple: if the expected output contains a new non-copy expression under an ordinary consumer, the test should fail for this pass.

## Binaryen oracle ladder

Use Binaryen as an oracle in increasing scope:

1. Run the official dedicated `test/passes/simplify-locals-nonesting.wast` shape family through Binaryen `--simplify-locals-nonesting` and a local focused fixture set.
2. Compare local hand-written fixtures against Binaryen after normalizing nops and local names where the harness already supports that.
3. Add a small `flatten -> simplify-locals-nonesting -> dfo`-style chain only after the local pass itself is green.
4. Keep full `--simplify-locals`, `--simplify-locals-notee-nostructure`, and local active `simplify-locals` as contrast lanes, not as the oracle for this sibling.

## What not to do

Do not start by routing this name to the active full `simplify-locals` implementation.
That would immediately violate the Binaryen contract because the active pass has structure rewrites and ordinary nested sinks that the nonesting variant must reject.

Do not add the pass to `optimize` or `shrink` presets during the first port.
The source-backed role is a flatten-neighbor / explicit-pipeline sibling, not part of the current Starshine no-DWARF preset.

Do not hide the local spelling mismatch.
The current repo says `simplify-locals-no-nesting`; the upstream pass says `simplify-locals-nonesting`.
A faithful port should make that choice visible in tests.

## Sources

- [`../../../raw/binaryen/2026-04-26-simplify-locals-nonesting-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-simplify-locals-nonesting-port-readiness-primary-sources.md)
- [`../../../raw/research/0407-2026-04-26-simplify-locals-nonesting-port-readiness.md`](../../../raw/research/0407-2026-04-26-simplify-locals-nonesting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
