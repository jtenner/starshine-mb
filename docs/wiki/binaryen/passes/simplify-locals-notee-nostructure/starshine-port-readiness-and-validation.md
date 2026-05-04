---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../tracker.md
---

# Starshine `simplify-locals-notee-nostructure` port readiness and validation

## Why this page exists

The main dossier already explains what Binaryen does.
The Starshine strategy page already explains the current removed-name status.
This page fills the remaining implementation-readiness gap:

- what is the smallest honest local slice?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- what tests and oracle lanes prove the no-tee / no-structure contract?

## Current hold point

Starshine still treats `simplify-locals-notee-nostructure` as a removed compatibility name, not an active pass.
The state to preserve until implementation starts is:

- upstream Binaryen spelling: `simplify-locals-notee-nostructure`
- current local spelling: `simplify-locals-no-tee-no-structure`
- current local category: removed
- current CLI behavior: rejected as an unknown executable pass flag by the command-layer category gate
- current lower-level pipeline behavior: rejected as removed if it reaches the hot-pass expander
- current owner: none
- current preset role: none

## Exact local code map today

| Surface | Code location | Why it matters |
| --- | --- | --- |
| Removed-name registry | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `pass_registry_removed_names()` | Keeps only the local alias spelling tracked today and shows the exact upstream spelling is still absent. |
| CLI pass gate | [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt), `cmd_resolve_pipeline_steps(...)` | Keeps removed names from becoming executable CLI flags by accident. |
| Hot dispatcher | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), `hot_pass_run(...)` | A new descriptor would need a real no-tee / no-structure dispatch case. |
| Full locals implementation | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), `simplify_locals_descriptor()` / `simplify_locals_run(...)` | Best landing zone, but currently owns the full pass, including behavior this sibling must disable. |
| Registry proof surface | [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Current category proofs cover active vs boundary-only vs removed entries, but not this sibling alias by itself. |
| Backlog truth | [`agent-todo.md`](../../../../../agent-todo.md) | Has `SLNS` for `simplify-locals-nostructure`, not for this stricter sibling. |
| Neighbor scheduler context | [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) | Documents the sibling’s aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot, but not a local implementation. |

## Recommended first slice

### Slice 0: registry honesty

Before any rewrite:

- decide the spelling policy:
  - add upstream `simplify-locals-notee-nostructure`,
  - keep local `simplify-locals-no-tee-no-structure`, or
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

- `allowTee = false`
- `allowStructure = false`
- `allowNesting = true`

This skeleton should be able to run and report no changes before mutating logic is enabled.

Exit criteria:

- the pass can be requested in focused tests if the registry policy makes it active;
- it does not change output;
- validation after the pass remains green.

### Slice 2: direct no-tee / no-structure cleanup only

Implement the minimum useful Binaryen-positive families:

1. direct single-use local sinking into an already-existing consumer;
2. dead-overwrite cleanup on the current linear trace;
3. late equivalent-get canonicalization once the direct sink path is green;
4. final dead-set cleanup after the no-tee / no-structure policy is proven.

Exit criteria:

- dedicated positive tests cover direct sink families;
- dedicated positive tests cover dead-overwrite cleanup;
- no `local.tee` is introduced;
- no block / `if` / loop result carrier is introduced;
- no non-copy expression is moved under `drop`, call operands, arithmetic operands, branch payloads, or control conditions unless the source contract already allows it.

### Slice 3: late cleanup reuse

Only after Slice 2 is stable, reuse the late equivalent-local and dead-set cleanup families from the full pass.

Exit criteria:

- equivalent-copy cleanup works on flat local-copy classes;
- dead-set cleanup removes only now-dead local shells;
- the same negative fixtures still prove no fresh teeing or structure synthesis.

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

1. Run the official dedicated `test/passes/simplify-locals-notee-nostructure.wast` shape family through Binaryen `--simplify-locals-notee-nostructure` and a local focused fixture set.
2. Compare local hand-written fixtures against Binaryen after normalizing nops and local names where the harness already supports that.
3. Add a small `flatten -> simplify-locals-notee-nostructure -> local-cse` chain only after the local pass itself is green.
4. Keep `--simplify-locals`, `--simplify-locals-nostructure`, and local active `simplify-locals` as contrast lanes, not as the oracle for this sibling.

## What not to do

Do not start by routing this name to the active full `simplify-locals` implementation.
That would immediately violate the Binaryen contract because the active pass has structure rewrites and ordinary nested sinks that the no-tee / no-structure variant must reject.

Do not add the pass to `optimize` or `shrink` presets during the first port.
The source-backed role is a flatten-neighbor / explicit-pipeline sibling, not part of the current Starshine no-DWARF preset.

Do not hide the local spelling mismatch.
The current repo says `simplify-locals-no-tee-no-structure`; the upstream pass says `simplify-locals-notee-nostructure`.
A faithful port should make that choice visible in tests.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- Binaryen `version_129` sources are enumerated in the raw primary-source manifest above.
