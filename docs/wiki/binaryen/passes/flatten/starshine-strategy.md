---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
---

# Starshine Strategy For `flatten`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md), the 2026-04-25 current-main owner/test-map bridge in [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md), and the local owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`flatten` is still **unimplemented** in Starshine.
There is no `src/passes/flatten.mbt` or `src/passes/flatten_hot.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry tracking plus batch planning:

- keep the upstream pass spelling tracked in the removed-name registry
- keep the public CLI spelling stable
- keep the pass in the IR2 execution-order documents as a deliberate next-wave port target
- keep the downstream dossier cluster honest about which later passes depend on a flattened world
- record explicitly that the active backlog still lacks a dedicated `flatten` slice today

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt:144-151`
    - `pass_registry_removed_names()` includes `"flatten"`
- public CLI spelling stability
  - `src/cli/cli_test.mbt:280-285`
    - `resolve_pass_flags omits trap-mode toggles from scheduled pass list`
    - this still preserves the explicit `--flatten` spelling even though trap-mode toggles are omitted
  - `src/cli/cli_test.mbt:313-316`
    - `resolve_pass_flags ignores -O level flags for preset pass expansion`
    - this still preserves explicit `--flatten` alongside an `-O` flag
- dispatcher gap
  - `src/passes/pass_manager.mbt`
    - no active `flatten` match exists today
- current batch intent
  - `docs/0065-2026-03-24-ir2-execution-plan.md:39`
    - `flatten` still leads the preferred Batch 2 implementation order
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47`
    - `flatten` still sits in Batch 2 removed-until-implemented planning
- active backlog truth
  - `agent-todo.md`
    - there is still **no dedicated `flatten` slice** today; shape mentions such as “flattened” in hot-lower or merge-blocks text are not a pass implementation plan
- exact neighboring living dossiers that define the future landing zone
  - [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md)
  - [`../local-cse/index.md`](../local-cse/index.md)
  - [`../rereloop/index.md`](../rereloop/index.md)
  - [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)
  - [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)
  - [`../souperify/index.md`](../souperify/index.md)

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `flatten` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt:144-151` keeps the upstream spelling `flatten` in `pass_registry_removed_names()`.
That means:

- the project still treats `flatten` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and batch-planning work instead of silently falling out of scope

That is the right current behavior for an unimplemented parity pass.

### 2. The CLI spelling is intentionally stable

`src/cli/cli_test.mbt:280-285` and `src/cli/cli_test.mbt:313-316` still exercise the explicit `--flatten` spelling in pass-flag resolution tests.
That matters for two reasons:

- docs and future parity commands can keep using the upstream pass spelling consistently
- once a real implementation lands, the public spelling does not need a second documentation migration first

### 3. The repo has planning intent, but not yet an active slice

The repo still has real planning intent for `flatten`:

- `docs/0065-2026-03-24-ir2-execution-plan.md` still puts it first in the next-wave Batch 2 order
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records it as a Batch 2 removed pass

But the active backlog surface is intentionally less mature:

- `agent-todo.md` still has no dedicated `flatten` section with deliverables and exit criteria

That mismatch is worth keeping explicit.
It means the local story today is real planning, but not yet an active execution slice.

## The right future Starshine implementation shape

The current docs strongly suggest that a future local `flatten` port should be taught as a **cluster-root structural normalizer**, not as just another cleanup pass.

Why:

- upstream Binaryen `flatten` defines a formal Flat IR contract rather than a vague simplification pass
- several later upstream passes depend on that flattened world rather than replacing it
- the neighboring Starshine dossiers already rely on explaining those downstream relationships precisely

So the local strategy should be thought of as:

1. decide how Starshine will represent the equivalent of Binaryen's flattened world
   - either a dedicated HOT/IR2 normalization layer that captures the same contract
   - or an explicitly documented divergence if Starshine chooses a different structural representation
2. preserve the real upstream responsibilities
   - temp-local routing for value-producing children
   - elimination of value-carrying control flow
   - elimination of `local.tee`
   - explicit carried-branch payload channels
   - a documented policy for unsupported `BrOn*` / `TryTable` families
3. wire the port into the right downstream cluster rather than landing it as an isolated pass
   - `simplify-locals-notee-nostructure`
   - `local-cse`
   - `rereloop`
   - other flatness-sensitive downstream consumers

In other words, the future port needs to create a structural world that later passes can rely on, not merely remove some nesting opportunistically.

## The most important local dependency map

### `flatten` is the structural root for the aggressive local-cleanup cluster

See [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md) and [`../local-cse/index.md`](../local-cse/index.md).

Why it matters locally:

- the upstream aggressive cluster is `flatten -> simplify-locals-notee-nostructure -> local-cse`
- `flatten` creates the world those later passes expect
- the later passes are not substitutes for `flatten`

A future Starshine port should preserve that relationship instead of treating the cluster as three unrelated ideas.

### `rereloop` depends on flattened input rather than replacing flattening

See [`../rereloop/index.md`](../rereloop/index.md).

Why:

- `rereloop` operates on the already-flattened/control-explicit world
- the relationship is “flatten first, then rebuild structure where useful,” not “rereloop instead of flatten”

That is an important planning boundary for future local design.

### `i64-to-i32-lowering` is another downstream consumer of the flattened world

See [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md).

Why:

- the upstream dossier already records flattened input as a real prerequisite
- that makes `flatten` part of a larger aggressive structural pipeline story, not just a locals-cleanup curiosity

### The broader flatness-sensitive family already exists in the wiki

See [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md) and [`../souperify/index.md`](../souperify/index.md).

Why:

- both dossiers already depend on teaching what the flattened world means
- a future Starshine `flatten` port would therefore affect more than one immediate neighbor folder

That is another reason to document the pass as a structural root rather than a one-off cleanup.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `flatten`
- a committed local equivalent of Binaryen's formal `flat.h` verifier contract
- a dedicated active backlog slice in `agent-todo.md`; current “flattened” wording there describes lowered/control-flow shapes, not a `flatten` pass slice
- pass-specific tests or replay lanes beyond the preserved CLI spelling and the broader batch-planning docs

So the current repo status is best summarized as:

- name tracked
- CLI spelling tracked
- batch intent tracked
- active slice still missing
- transform itself not yet landed

## Validation plan for the eventual port

The current docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced structural tests for the core flatness contract
   - simple-child preservation
   - value-carrying `block` / `if` / `loop` / `try` rewrites
   - `local.tee` elimination
   - carried `br_if` / `br_table` payload routing
2. negative and boundary tests
   - unsupported `BrOn*` / `TryTable` policy
   - selective non-null families
   - EH nested-pop repair
3. cluster interaction tests
   - `flatten -> simplify-locals-notee-nostructure -> local-cse`
   - `flatten -> rereloop`
   - `flatten -> i64-to-i32-lowering`
4. artifact and oracle comparison
   - once the active backlog grows a real `flatten` slice and the exact local slot becomes executable

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the real downstream contracts already documented in this repo.

## Bottom line

Current Starshine `flatten` strategy is honest registry tracking plus batch planning:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the public `--flatten` spelling is intentionally preserved in `src/cli/cli_test.mbt`
- the IR2 execution-plan docs still place the pass at the front of the next removed-pass batch
- the active backlog still does **not** have a dedicated `flatten` slice, and the docs now keep that planning gap explicit
- the surrounding living dossiers already define the practical landing zone for a future port because they explain which later passes depend on the flattened world

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear public spelling**
- **clear future cluster**
- **clear warning that the active backlog still needs a real `flatten` slice before implementation work begins**
