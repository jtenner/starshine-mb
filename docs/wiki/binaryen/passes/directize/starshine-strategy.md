---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-directize-primary-sources.md
  - ../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../duplicate-import-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ../duplicate-import-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
---

# Starshine Strategy For `directize`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-directize-primary-sources.md`](../../../raw/binaryen/2026-04-22-directize-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`directize` is still **unimplemented** in Starshine.
There is no `src/passes/directize.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status and landing-zone planning:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs whole-module table facts before function-local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the canonical no-DWARF tail slot documented
- keep the backlog slice focused on table eligibility, rewrite safety, and artifact proof
- teach the surrounding late-tail dossiers a future port would have to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_boundary_only_names()` includes `"directize"`
- active request guard for not-yet-ported boundary passes
  - `src/passes/optimize.mbt`
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- backlog and delivery plan
  - `agent-todo.md`
    - `DIR` slice under the Binaryen no-DWARF default optimize pathway parity section
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the final late-tail slot where `directize` follows `reorder-globals`
- neighboring living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
  - `docs/wiki/binaryen/passes/string-gathering/index.md`
  - `docs/wiki/binaryen/passes/reorder-globals/index.md`

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `directize` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `directize` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `directize` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline without added module/table analysis

That is the right current behavior for an unimplemented late boundary pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `directize`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The work is planned as a real parity slice, not an orphan idea

`agent-todo.md` already gives `directize` a real backlog slice under `DIR`.
The current deliverables are framed around the right upstream concerns:

- call-target eligibility
- preserving table semantics, imports, and dynamic behavior
- rewriting eligible callsites without breaking dependent signatures
- boundary regressions over mixed direct/indirect table shapes
- artifact comparison against Binaryen's final-tail output

That backlog framing already matches the upstream dossier better than a vague “turn indirect calls into direct calls” summary would.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `directize` port should be taught as a **late boundary/module pass**, not as an isolated HOT peephole.

Why:

- Binaryen runs it after `reorder-globals`
- it is the last top-level pass in the canonical no-DWARF tail
- its correctness depends on module-wide table facts before function-local rewriting starts
- its rewrites can refine call result types and convert known traps into `unreachable`, so the eventual local implementation will need explicit rewrite plus repair logic instead of a cheap local pattern match

So the local strategy should be thought of as:

1. collect whole-module table and element knowledge first
2. classify target expressions with the same `Known` / `Trap` / `Unknown` boundary the Binaryen dossier teaches
3. apply function-local call rewrites only after that proof exists
4. preserve late-tail scheduler placement after the neighboring global/string/module cleanup passes
5. keep validation and artifact proof focused on mixed known/unknown/trap table surfaces

In other words, the future port should slot into a local late optimization ecosystem that is already documented.

## The most important local dependency map

### `directize` is downstream of the whole late cleanup tail

See:

- [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md)
- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- [`../string-gathering/index.md`](../string-gathering/index.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `directize` after all of those passes
- the Binaryen strategy page says the pass wants table/global shape mostly settled before it reasons about table entries
- a future Starshine port should therefore validate not only `--directize` in isolation, but also the real tail neighborhood that feeds it

### `directize` is late boundary work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `heap-store-optimization`
- `precompute`
- `merge-blocks`

Those are valuable neighboring dossiers for style and validation habits, but `directize` does not naturally belong in that early/mid function-local cluster.
Its current boundary-only classification is not arbitrary bookkeeping.
It reflects the same architectural fact the Binaryen dossier teaches: module-wide table facts come first.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `directize` MoonBit implementation file
- local whole-module table flattening or immutable-initial-contents analysis for this pass
- call-target classification logic equivalent to Binaryen's `Known` / `Trap` / `Unknown` split
- `select`-to-branch call lowering for this pass
- directize-specific reduced tests or CLI replay coverage beyond the tracked boundary-only status and backlog slice

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- backlog tracked
- scheduler slot documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the main upstream families
   - direct-call positives
   - trap-to-`unreachable` rewrites with side effects preserved
   - mixed known-vs-unknown table entries
   - narrow `select` lowering
2. table-facts and legality negatives
   - imported/exported/mutated table boundaries
   - immutable-initial-contents mode
   - non-flat element-layout bailouts
   - wasm64 width correctness
   - GC subtype compatibility versus trap cases
3. scheduler-neighborhood interaction tests
   - the full no-DWARF late tail ending in `reorder-globals -> directize`
4. artifact and oracle comparison
   - the `DIR` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `directize` strategy is honest boundary-only tracking and landing-zone planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- the same file keeps the active pipeline honest by rejecting boundary-only requests
- `agent-todo.md` already treats it as a real late parity slice under `DIR`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `duplicate-import-elimination`, `simplify-globals-optimizing`, `remove-unused-module-elements`, `string-gathering`, and `reorder-globals` dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear late-tail dependency story**
- **clear neighboring implementation map for the eventual port**
