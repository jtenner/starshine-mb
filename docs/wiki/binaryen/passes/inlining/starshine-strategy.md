---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../inlining-optimizing/index.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../inline-main/index.md
  - ../duplicate-function-elimination/index.md
  - ../monomorphize/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ../inlining-optimizing/index.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../inline-main/index.md
  - ../monomorphize/index.md
---

# Starshine Strategy For `inlining`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-inlining-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`inlining` is still **unimplemented** in Starshine.
There is no `src/passes/inlining.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus a concrete port map:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs whole-module function summaries, function-boundary rewrites, and dead-helper cleanup rather than HOT-region local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the shared-engine relation to `inlining-optimizing` explicit
- keep the neighboring `inline-main`, `monomorphize`, and late-tail cleanup dossiers linked so future work has an exact landing zone
- keep the current planning gap explicit: unlike `inlining-optimizing`, plain `inlining` still has **no dedicated backlog slice** in `agent-todo.md`

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
    - `pass_registry_boundary_only_names()` includes `"inlining"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L458-L463`](../../../../../src/passes/optimize.mbt#L458-L463)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- boundary-only portfolio planning
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60)
    - `inlining` is grouped under whole-module or layout transforms, not HOT-local cleanup
- current backlog reality
  - [`agent-todo.md#L501-L509`](../../../../../agent-todo.md#L501-L509)
    - the repo has an `INL` slice for `inlining-optimizing`, but no separate plain-`inlining` slice today
- neighboring living dossiers a future port must line up with
  - [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md)
  - [`../inlining-optimizing/starshine-strategy.md`](../inlining-optimizing/starshine-strategy.md)
  - [`../inline-main/index.md`](../inline-main/index.md)
  - [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)
  - [`../monomorphize/index.md`](../monomorphize/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `inlining` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `inlining` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `inlining` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and planning work instead of silently falling out of scope
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline

That is the right current behavior for an unimplemented whole-module pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `inlining`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The current local planning story is intentionally thinner than the optimizing sibling's

Unlike `inlining-optimizing`, plain `inlining` does **not** currently have a dedicated backlog slice in `agent-todo.md`.
That absence is worth teaching explicitly because it prevents two common mistakes:

- assuming the optimizing `INL` slice already covers the plain pass contract exactly
- assuming the repo has already committed to shipping both siblings separately rather than landing shared machinery first

The honest status is:

- boundary-only name tracked
- request guard tracked
- planning bucket tracked
- neighboring shared-engine dossiers tracked
- dedicated plain-pass backlog slice still absent

That gap should stay explicit until the repo chooses a concrete local landing sequence.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `inlining` port should be taught as a **boundary/module pass**, not as a HOT peephole and not as a scheduler wrapper only.

Why:

- Binaryen runs it as a whole-module planner and rewriter
- correctness depends on module-wide function summaries and whole-function call-boundary rewrites
- the public contract includes dead-helper cleanup, not just caller-body mutation
- the same upstream engine also underlies `inlining-optimizing` and the smaller `inline-main` helper path
- the pass sits conceptually beside `monomorphize` and `duplicate-function-elimination`, where declaration survival and helper removal matter as much as local instruction rewrites

So the local strategy should be thought of as:

1. build whole-module callee summaries
2. choose only the reviewed `version_129` direct-call planner surface first
3. rewrite chosen callsites with the same return/local/label/type repair discipline as upstream plain `inlining`
4. remove now-dead private helpers only when roots and surviving uses permit it
5. validate that the pass stops there, without accidentally inheriting the optimizing sibling's nested useful-pass rerun

That is a much tighter and safer future plan than the vague mental model “add an inliner later.”

## The most important local dependency map

### Plain `inlining` is the shared-engine sibling of `inlining-optimizing`, but the public contract is smaller

See:

- [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md)
- [`../inlining-optimizing/starshine-strategy.md`](../inlining-optimizing/starshine-strategy.md)

Why it matters locally:

- both public passes come from the same upstream `Inlining.cpp` engine
- a future Starshine port should likely share most low-level rewrite machinery between the siblings
- the most important semantic difference to preserve is the stop point: plain `inlining` stops after inline rewrite, repair, and dead-helper cleanup, while `inlining-optimizing` continues into the nested useful-pass rerun
- the current repo already has planning coverage only for the optimizing sibling, so a future contributor must decide whether to land shared primitives first or expose only the optimizing wrapper initially

### `inline-main` proves the shared low-level inline helper boundary matters

See:

- [`../inline-main/index.md`](../inline-main/index.md)

Why it matters locally:

- `inline-main` is a much smaller public pass, but it reuses the same upstream low-level inline-body repair machinery
- this is a strong design hint for Starshine: keep the future callsite-rewrite primitive separable from the larger whole-module planner
- if the repo ever ports `inline-main` before plain `inlining`, that should still point back to the same shared rewrite layer rather than growing a disconnected special case

### `monomorphize` is a useful neighboring contrast, not a substitute

See:

- [`../monomorphize/index.md`](../monomorphize/index.md)

Why it matters locally:

- both passes are whole-module call-boundary transforms
- both can clone or remove helper boundaries and then require later cleanup to keep the module coherent
- but `monomorphize` is contextual specialization, not ordinary inlining, so a future local `inlining` port should share infrastructure only where the semantics actually match

### `duplicate-function-elimination` is a natural downstream consumer of a future local inliner

See:

- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)

Why it matters locally:

- inlining changes which helpers survive and which wrappers become redundant
- a future local boundary/module scheduler should validate not only plain `--inlining`, but also the neighborhood that consumes the rewritten function graph afterward
- this is another reason the port belongs in boundary/module scheduling rather than the HOT-only pipeline

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit owner file for `inlining`
- whole-module function-summary or call-graph planning code for inlining
- a local inline rewrite primitive with callee-local remapping, label repair, and `return_call*` repair
- dead-helper removal logic tied to a plain-`inlining` boundary transform
- reduced plain-`inlining` regression tests or artifact replay coverage
- a dedicated plain-`inlining` backlog slice distinct from the optimizing sibling's `INL` work

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- planning bucket tracked
- neighboring shared-engine story documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing dossier plus the local status surfaces imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced rewrite tests for the reviewed upstream plain-pass families
   - tiny and one-use direct-call positives
   - root-surviving inline positives
   - tail-call and recursion bailouts
   - Pattern A / Pattern B partial-inlining shapes
   - copied-return and nondefaultable-local repair cases
2. boundary-cleanup tests
   - dead private helper removal only when roots and surviving refs allow it
   - preserved declarations for exported, start, and `ref.func`-used callees
3. sibling-boundary tests
   - plain `inlining` stops without the optimizing sibling's nested rerun
   - any shared rewrite helper still composes with future `inline-main` / `inlining-optimizing` work
4. oracle comparison
   - compare `--inlining` output against Binaryen rather than only `--inlining-optimizing`

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the exact families the repo will need to prove.

## Bottom line

Current Starshine `inlining` strategy is honest boundary-only tracking plus a concrete port map:

- the pass name is intentionally preserved in [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
- the same file keeps the active pipeline honest by rejecting boundary-only requests at [`#L458-L463`](../../../../../src/passes/optimize.mbt#L458-L463)
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60) already places it in the boundary/module planning bucket
- [`agent-todo.md#L501-L509`](../../../../../agent-todo.md#L501-L509) usefully exposes the current planning gap by covering only the optimizing sibling today
- the surrounding [`inlining-optimizing`](../inlining-optimizing/index.md), [`inline-main`](../inline-main/index.md), [`duplicate-function-elimination`](../duplicate-function-elimination/index.md), and [`monomorphize`](../monomorphize/index.md) dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked boundary status**
- **clear shared-engine neighborhood**
- **clear future boundary/module landing zone**
- **clear current planning gap around a dedicated plain-`inlining` backlog slice**
