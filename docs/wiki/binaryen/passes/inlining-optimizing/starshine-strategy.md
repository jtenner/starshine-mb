---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../precompute-propagate/index.md
  - ../inlining/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../precompute-propagate/index.md
  - ../inlining/index.md
---

# Starshine Strategy For `inlining-optimizing`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`inlining-optimizing` is still **unimplemented** in Starshine.
There is no `src/passes/inlining_optimizing.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus a concrete port map:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs whole-module call-graph planning and nested reruns rather than HOT-region local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the canonical no-DWARF late slot documented
- keep the backlog slice visible with both rewrite and nested-rerun deliverables
- keep the neighboring `dae-optimizing`, `precompute-propagate`, `duplicate-function-elimination`, and plain `inlining` dossiers linked so future work has an exact landing zone

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
    - `pass_registry_boundary_only_names()` includes `"inlining-optimizing"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L281-L291`](../../../../../src/passes/optimize.mbt#L281-L291)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- boundary-only portfolio planning
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60)
    - `inlining-optimizing` is grouped under whole-module or layout transforms, not HOT-local cleanup
- backlog and delivery plan
  - [`agent-todo.md#L501-L509`](../../../../../agent-todo.md#L501-L509)
    - `INL - Inlining Optimizing`
- canonical scheduler context
  - [`../../no-dwarf-default-optimize-path.md#L35-L40`](../../no-dwarf-default-optimize-path.md#L35-L40)
    - the canonical late-tail slot where `inlining-optimizing` follows `dae-optimizing`, precedes `duplicate-function-elimination`, and shares the nested post-inlining rerun rule
- archived planning detail behind the same slot
  - [`../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L289-L293`](../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L289-L293)
    - the older slot note already recorded the same future implementation shape: apply Binaryen-like inlining heuristics, rewrite callsites, delete dead functions, and rerun the nested post-inlining cleanup pipeline
- neighboring living dossiers a future port must line up with
  - [`../dae-optimizing/index.md`](../dae-optimizing/index.md)
  - [`../precompute-propagate/index.md`](../precompute-propagate/index.md)
  - [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)
  - [`../inlining/index.md`](../inlining/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `inlining-optimizing` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `inlining-optimizing` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `inlining-optimizing` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline

That is the right current behavior for an unimplemented late boundary pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `inlining-optimizing`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The backlog already models the real two-part contract

`agent-todo.md` already gives the pass a real backlog slice under `INL`.
That is important because the slice is not written as only “add inlining.”
It already splits the future work into the two real Binaryen-shaped halves:

- `[INL]001` for heuristics, rewrite, dead-helper removal, and touched-function tracking
- `[INL]002` for the nested useful-pass replay that prepends `precompute-propagate` and reruns the default function pipeline on touched functions

That is a stronger starting point than many other unimplemented passes already have.
The local docs should keep that two-part story visible instead of collapsing it into one vague “future inliner” item.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `inlining-optimizing` port should be taught as a **late boundary/module pass with one nested scheduler helper**, not as a HOT peephole and not as a plain inline primitive alone.

Why:

- Binaryen runs it late, after `dae-optimizing`
- its correctness depends on module-wide function summaries and call-boundary rewrites
- its public behavior includes dead-helper cleanup, not just caller-body mutation
- the optimizing part is a real contract: touched functions immediately rerun `precompute-propagate` plus the default function optimization pipeline
- the immediate downstream neighbor `duplicate-function-elimination` expects the function graph to have already settled somewhat

So the local strategy should be thought of as:

1. build whole-module callee summaries
2. choose only the reviewed `version_129` direct-call planner surface first
3. rewrite chosen callsites with the same return/local/label/type repair discipline as the plain `inlining` sibling
4. remove now-dead private helpers only when roots and surviving uses permit it
5. record the exact touched-function set
6. run a nested filtered pipeline equivalent to Binaryen's `optimizeAfterInlining(...)`
7. only then continue into the late-tail cleanup neighborhood

That is a much tighter and safer future plan than the older vague mental model “port the inliner somehow.”

## The most important local dependency map

### `inlining-optimizing` shares the post-inlining helper story with `dae-optimizing`

See:

- [`../dae-optimizing/index.md`](../dae-optimizing/index.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)

Why it matters locally:

- the no-DWARF scheduler docs already place both passes under the same nested post-inlining cleanup rule
- a future Starshine port should therefore avoid growing two separate local “cleanup after boundary rewrite” schedulers if one faithful shared helper can serve both passes
- this is the cleanest place to keep the `precompute-propagate` prepend rule honest

### `inlining-optimizing` depends on the nearby `precompute-propagate` contract

See:

- [`../precompute-propagate/index.md`](../precompute-propagate/index.md)

Why it matters locally:

- the optimizing variant is not complete without the extra prepended `precompute-propagate` rerun
- if Starshine eventually lands inline rewriting before `precompute-propagate`, the local pass should still stay clearly marked as an incomplete subset rather than silently claiming Binaryen parity
- this neighboring dossier already teaches what the nested helper must prepend and why it exists at all

### `inlining-optimizing` feeds later late-tail boundary cleanup

See:

- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)

Why it matters locally:

- the canonical no-DWARF scheduler places `duplicate-function-elimination` immediately after `inlining-optimizing`
- a future Starshine port should validate not just `--inlining-optimizing` in isolation, but also the late-tail neighborhood that consumes its rewritten function graph
- the port therefore belongs in the boundary/module scheduling layer, not only in a callsite-rewrite helper

### Plain `inlining` is the closest local read-along sibling, but it is not the same public contract

See:

- [`../inlining/index.md`](../inlining/index.md)

Why it matters locally:

- both passes share the same upstream `Inlining.cpp` engine
- the plain sibling dossier is now the cleanest source-confirmed home for the shared direct-call planner, no-inline controls, split Pattern A/B rules, and repair machinery
- the difference this Starshine page must keep centered is the optimizing wrapper: touched-function tracking plus the nested useful-pass rerun are part of this pass, not optional polish

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit owner file for `inlining-optimizing`
- whole-module function-summary or call-graph planning code for inlining
- a local inline rewrite primitive with callee-local remapping and return-call repair
- a local touched-function-set API for post-inlining nested reruns
- a local nested helper that prepends `precompute-propagate` and reruns the default function pass cluster only on touched functions
- reduced `inlining-optimizing` regression tests or artifact replay coverage beyond the tracked backlog slice and scheduler docs

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- backlog tracked
- scheduler slot documented
- neighboring dependency story documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced rewrite tests for the real upstream families
   - tiny and one-use direct-call positives
   - root-surviving inline positives
   - tail-call and recursion bailouts
   - Pattern A / Pattern B partial-inlining shapes
   - copied-return and nondefaultable-local repair cases
2. scheduler-helper tests
   - touched-function tracking
   - nested `precompute-propagate` prepend
   - rerun of the default function optimization pipeline on touched functions only
3. late-tail neighborhood tests
   - `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination`
4. artifact and oracle comparison
   - the `INL` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `inlining-optimizing` strategy is honest boundary-only tracking plus a concrete port map:

- the pass name is intentionally preserved in [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
- the same file keeps the active pipeline honest by rejecting boundary-only requests at [`#L281-L291`](../../../../../src/passes/optimize.mbt#L281-L291)
- [`agent-todo.md#L501-L509`](../../../../../agent-todo.md#L501-L509) already treats it as a real late parity slice under `INL`
- the canonical slot and shared nested-rerun rule are already documented in [`../../no-dwarf-default-optimize-path.md#L35-L40`](../../no-dwarf-default-optimize-path.md#L35-L40)
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60) already places it in the boundary/module planning bucket
- the surrounding [`dae-optimizing`](../dae-optimizing/index.md), [`precompute-propagate`](../precompute-propagate/index.md), [`duplicate-function-elimination`](../duplicate-function-elimination/index.md), and plain [`inlining`](../inlining/index.md) dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear boundary/module dependency story**
- **clear nested-rerun contract to preserve when the port lands**
