---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/ir/hot.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
---

# Starshine Strategy For `reorder-globals`

Use this page together with the current-main source bridge in [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`reorder-globals` is still **unimplemented** in Starshine.
There is no `src/passes/reorder_globals.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus late-tail landing-zone planning:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs whole-module declaration and remap work rather than HOT-region local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the canonical no-DWARF late-tail slot documented
- keep the backlog slice focused on safe global-index remapping, section-boundary preservation, and artifact proof
- keep the split from the upstream/local sibling `reorder-globals-always` explicit
- teach the surrounding late-tail dossiers a future port would have to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes both `"reorder-globals"` and `"reorder-globals-always"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- numeric global-index and module-section surfaces a future port must remap
  - [`src/lib/types.mbt#L91`](../../../../../src/lib/types.mbt#L91)
    - `GlobalIdx` is a numeric index type, unlike Binaryen's name-keyed global references
  - [`src/lib/types.mbt#L351-L368`](../../../../../src/lib/types.mbt#L351-L368)
    - `Module` owns `import_sec`, `global_sec`, `export_sec`, `elem_sec`, `code_sec`, and `data_sec`
  - [`src/lib/types.mbt#L442`](../../../../../src/lib/types.mbt#L442)
    - `GlobalSec(Array[Global])` is the declaration vector a local module pass would reorder
  - [`src/binary/encode.mbt#L633-L636`](../../../../../src/binary/encode.mbt#L633-L636) and [`src/binary/decode.mbt#L731-L735`](../../../../../src/binary/decode.mbt#L731-L735)
    - binary roundtrip encodes/decodes numeric `GlobalIdx` values
  - [`src/validate/validate.mbt#L949-L965`](../../../../../src/validate/validate.mbt#L949-L965)
    - const-expression `global.get` validation depends on imported or previously defined immutable globals
  - [`src/ir/hot.mbt#L206-L218`](../../../../../src/ir/hot.mbt#L206-L218) and [`src/ir/hot.mbt#L285-L297`](../../../../../src/ir/hot.mbt#L285-L297)
    - HOT lift stores `GlobalGet` / `GlobalSet` operands as numeric global indices, confirming this is not a HOT-only peephole
- backlog and delivery plan
  - [`agent-todo.md#L672-L687`](../../../../../agent-todo.md#L672-L687)
    - `RG - Reorder Globals`
    - `[RG]001 - Global Cost Model and Reindexing`
    - `[RG]002 - Late-Postpass Validation and Artifact Compare`
- canonical scheduler context
  - [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
    - the canonical late-tail slot `string-gathering -> reorder-globals -> directize`
- neighboring living dossiers a future port must line up with
  - [`../string-gathering/index.md`](../string-gathering/index.md)
  - [`../reorder-globals-always/index.md`](../reorder-globals-always/index.md)
  - [`../directize/index.md`](../directize/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `reorder-globals` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `reorder-globals` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `reorder-globals` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline

That is the right current behavior for an unimplemented late boundary pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `reorder-globals`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The work is planned as a real parity slice, not an orphan idea

`agent-todo.md` already gives `reorder-globals` a real backlog slice under `RG`.
The current deliverables are framed around the right local concerns:

- port Binaryen's reordering criteria
- compute a safe remap after late global cleanup and string gathering
- preserve externally visible boundaries and section invariants
- add regressions for reordered globals with string users and exports
- compare local output against Binaryen on the debug artifact

That backlog framing already matches the upstream dossier better than a vague “sort globals by use count” summary would.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `reorder-globals` port should be taught as a **late module pass**, not as an isolated HOT peephole and not as a side effect of `string-gathering`.

Why:

- Binaryen runs it after `string-gathering`
- it is the second-to-last top-level pass in the canonical no-DWARF tail
- its correctness depends on whole-module declaration order, import-prefix preservation, initializer dependencies, and final global-index layout
- the local backlog already makes safe remapping a first-class deliverable

So the local strategy should be thought of as:

1. wait until late-tail cleanup has mostly stabilized the global surface
2. collect enough whole-module information to model index-sensitive global traffic and initializer dependencies
3. search or otherwise choose a dependency-safe final declaration order that matches the reviewed Binaryen contract closely enough for parity
4. apply a declaration reorder and whatever local remap/writeback work Starshine's representation requires
5. validate exports, string users, startup/global-initializer correctness, and final artifact parity in the real late-tail neighborhood

In other words, the future port should slot into a local late optimization ecosystem that is already documented.

## The most important local dependency map

### `reorder-globals` is downstream of `string-gathering`

See:

- [`../string-gathering/index.md`](../string-gathering/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `reorder-globals` immediately after `string-gathering`
- the `string-gathering` dossier already teaches that its own internal reorder is only a validity repair for defining globals
- a future Starshine port should therefore keep the same division of labor explicit: string gathering first for validity/canonicalization, final global layout second for size and declaration order

That boundary is easy to blur if readers only remember that both passes can move globals.

### `reorder-globals-always` is a real sibling, not just an implementation footnote

See:

- [`../reorder-globals-always/index.md`](../reorder-globals-always/index.md)

Why it matters locally:

- `src/passes/optimize.mbt` already preserves both spellings in the boundary-only registry
- the upstream dossier keeps the `< 128` public no-op rule and the smooth-scoring sibling distinct
- a future local port may need to decide whether exact parity also requires a separate internal/test-facing helper story, or whether the repo should keep only the production public policy initially

The current local strategy page therefore keeps the sibling boundary explicit instead of teaching `reorder-globals` as if it were the entire family.

### `reorder-globals` feeds the final `directize` tail slot

See:

- [`../directize/index.md`](../directize/index.md)

Why it matters locally:

- the canonical no-DWARF scheduler places `reorder-globals` immediately before `directize`
- even though the passes operate on different surfaces, the local late-tail contract is clearer if `reorder-globals` is validated in the real neighborhood rather than as an isolated declaration-order tweak
- a future Starshine port should therefore include scheduler-neighborhood proof, not only standalone reorder tests

### `reorder-globals` is boundary/module work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `precompute`
- `merge-blocks`

Those are valuable neighboring dossiers for style and validation habits, but `reorder-globals` does not naturally belong in that cluster.
Its current boundary-only classification is not arbitrary bookkeeping.
It reflects the same architectural fact the Binaryen dossier teaches: global declaration layout and representation-correct remapping come first.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `reorder-globals` MoonBit implementation file
- local global-traffic counting or dependency sorting code for this pass
- a local declaration-remap helper dedicated to this late-tail transformation
- reduced `reorder-globals` regression tests
- artifact replay coverage specific to the pass beyond the tracked backlog slice and scheduler docs

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- backlog tracked
- scheduler slot documented
- sibling split from `reorder-globals-always` documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the main upstream families
   - hotter independent globals
   - dependency-preserving chains
   - `global.set` heat
   - import-first ordering
   - string-user cases that must remain valid after the final reorder
2. policy-boundary tests
   - exact public `< 128` no-op behavior if parity is the target
   - explicit separate handling, deferral, or absence of `reorder-globals-always`
3. remap and section-boundary tests
   - exported globals
   - initializer/global-order validity
   - any local index-bearing surfaces that need remapping in Starshine's representation or emit path
4. scheduler-neighborhood interaction tests
   - the full late-tail `string-gathering -> reorder-globals -> directize`
5. artifact and oracle comparison
   - the `RG` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `reorder-globals` strategy is honest boundary-only tracking and late-tail landing-zone planning:

- the pass name is intentionally preserved in [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
- the same file keeps the active pipeline honest by rejecting boundary-only requests at [`#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
- [`agent-todo.md#L672-L687`](../../../../../agent-todo.md#L672-L687) already treats it as a real late parity slice under `RG`
- the canonical slot is already documented in [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
- the surrounding [`string-gathering`](../string-gathering/index.md), [`reorder-globals-always`](../reorder-globals-always/index.md), and [`directize`](../directize/index.md) dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear late-tail dependency story**
- **clear public-vs-`always` sibling boundary**
- **clear reindexing-and-validation plan for the eventual port**
