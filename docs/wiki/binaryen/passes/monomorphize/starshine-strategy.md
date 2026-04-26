---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md
  - ../../../raw/research/0416-2026-04-26-monomorphize-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0302-2026-04-24-monomorphize-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../monomorphize-always/index.md
  - ../inlining/index.md
  - ../inline-main/index.md
  - ../inlining-optimizing/index.md
  - ../duplicate-function-elimination/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
  - ./clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../monomorphize-always/index.md
  - ../inlining/index.md
  - ../inline-main/index.md
---

# Starshine strategy for `monomorphize`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and option surfaces that already mention the pass family, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`monomorphize` is still **unimplemented** in Starshine.
There is no `src/passes/monomorphize.mbt` owner file today.

That does **not** mean there is no local strategy surface.
The current Starshine strategy is boundary-only status plus compatibility/config plumbing:

- keep the `monomorphize` and `monomorphize-always` spellings tracked in the registry
- keep explicit pass requests honest by rejecting the boundary-only pass instead of pretending it already runs
- preserve the Binaryen-style `monomorphize_min_benefit` option through CLI/config/summary surfaces
- document that the option is currently inert for pass execution because the transform itself is not implemented
- keep the pass categorized as a whole-module or layout transform, not as a HOT-local peephole
- keep the current planning gap explicit: `agent-todo.md` still has no dedicated `monomorphize` slice

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.
For implementation sequencing and validation lanes, continue to [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L138`](../../../../../src/passes/optimize.mbt#L127-L138)
    - `pass_registry_boundary_only_names()` includes both `"monomorphize"` and `"monomorphize-always"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L456-L462`](../../../../../src/passes/optimize.mbt#L456-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- option storage and default value
  - [`src/cmd/cmd.mbt#L119-L152`](../../../../../src/cmd/cmd.mbt#L119-L152)
    - command config carries `monomorphize_min_benefit`, defaulting to `5`
  - [`src/cmd/cmd.mbt#L1666-L1678`](../../../../../src/cmd/cmd.mbt#L1666-L1678)
    - `make_optimize_options(...)` forwards `monomorphize_min_benefit` into `OptimizeOptions`
- CLI parsing and roundtrip display
  - [`src/cli/cli.mbt#L994-L1021`](../../../../../src/cli/cli.mbt#L994-L1021)
    - parses `--monomorphize-min-benefit`
  - [`src/cmd/cmd.mbt#L2776-L2780`](../../../../../src/cmd/cmd.mbt#L2776-L2780)
    - prints `--monomorphize-min-benefit` when it differs from the default
- option tests
  - [`src/cli/cli_test.mbt#L354-L360`](../../../../../src/cli/cli_test.mbt#L354-L360)
    - verifies CLI parsing for the named optimization option flags
  - [`src/cmd/cmd_wbtest.mbt#L4227-L4245`](../../../../../src/cmd/cmd_wbtest.mbt#L4227-L4245)
    - verifies command resolution carries `monomorphize_min_benefit` through config/CLI merging
- boundary-only portfolio planning
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L61`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L61)
    - `monomorphize` and `monomorphize-always` live in the whole-module/layout-transform bucket
- current backlog reality
  - [`agent-todo.md`](../../../../../agent-todo.md)
    - no dedicated `monomorphize` implementation slice exists today

That code map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and option plumbing.

## What Starshine currently does for this pass name

Today Starshine's behavior for `monomorphize` is deliberately limited.

### 1. The pass names are tracked, not forgotten

`src/passes/optimize.mbt` keeps both `monomorphize` and `monomorphize-always` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats both names as known Binaryen-adjacent pass names
- explicit future port work can anchor on stable local spellings
- the ordinary pass and the testing/debugging sibling stay linked without pretending they are active
- the current classification already teaches a semantic fact: this family is expected to cross function/module boundaries rather than fit into the current HOT-only function pipeline

### 2. Explicit pass requests fail honestly

The active expansion path returns the standard boundary-only error for `monomorphize`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI/API surface does not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

### 3. The benefit-threshold option exists today, but it is not pass execution

Starshine already parses and transports `monomorphize_min_benefit` through command config and `OptimizeOptions`.
This is useful compatibility surface, but it can be misread.

Current truth:

- `--monomorphize-min-benefit` is a real accepted option
- config/env/CLI merging preserve it
- summaries can report it
- no implemented pass consumes it today because no monomorphization transform exists

If a future port lands, this existing option should become the local equivalent of Binaryen's usefulness threshold input.
Until then, docs should describe it as **option plumbing for a boundary-only pass**, not as evidence that Starshine performs monomorphization.

## The right future Starshine implementation shape

A faithful local port should be a **boundary/module pass**, not a HOT peephole.

Why:

- Binaryen scans original defined functions and direct callsites across the module
- successful specialization adds new functions to the module
- clone naming, function-type changes, local-name repair, and dropped-result rewrites cross function boundaries
- usefulness measurement depends on running nested optimization on the specialized clone
- the sibling `monomorphize-always` must share safety gates while changing only usefulness rejection

So the local strategy should be thought of as:

1. gather candidate direct calls from the original defined-function set
2. reject imported, recursive, unreachable, and return-call-sensitive dropped-result cases the same way the upstream contract does
3. build executable call-context operands with effect-safe movement checks
4. reject trivial contexts before cloning
5. clone the callee, derive the new signature from surviving dynamic `local.get`-like inputs, and convert old params into locals
6. materialize reverse-inlined context with prelude assignments
7. repair local indexes, local names, result type, explicit returns, and caller-side `(drop (call ...))` wrappers
8. run the nested optimizer and compare cost using the configured benefit threshold
9. memoize both successful and failed `(target, context)` pairs
10. expose the sibling `monomorphize-always` as the same legality pipeline without default usefulness rejection

The readiness bridge now recommends splitting that target into a no-rewrite analyzer, a scalar-literal clone slice, a dropped-result slice, effect-safe context movement, and only then usefulness-gated parity work; see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

That shape is more precise than the vague plan “clone specialized callees later.”

## The most important local dependency map

### `monomorphize-always` is the sibling, not a separate engine

See:

- [`../monomorphize-always/index.md`](../monomorphize-always/index.md)

Why it matters locally:

- the future implementation should share context extraction, clone construction, local repair, and safety gates
- the visible split is policy: ordinary `monomorphize` is cost-gated, while `monomorphize-always` keeps legal nontrivial contexts even when benefit is weak
- tests for the ordinary pass should include sibling contrast cases so the shared-engine split remains honest

### `inlining` and `inline-main` are neighbors, not substitutes

See:

- [`../inlining/index.md`](../inlining/index.md)
- [`../inline-main/index.md`](../inline-main/index.md)

Why it matters locally:

- all three passes rewrite call boundaries and can clone/copy function bodies
- `inlining` moves callee code into the caller
- `inline-main` is a name-based wrapper inline
- `monomorphize` moves callsite context into a cloned callee

A future Starshine implementation may share some module-copy, local-remap, and validation utilities with the inlining family, but it must not collapse the semantic direction of the transform.

### `duplicate-function-elimination` is a natural downstream cleanup neighbor

See:

- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)

Why it matters locally:

- monomorphization can create specialized helper functions
- later cleanup may discover exact duplicates or dead helpers
- a future scheduler should validate not only `--monomorphize`, but also downstream cleanup interactions once the transform exists

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit owner file for `monomorphize`
- whole-module callsite-context collection for this pass family
- effect-order movement analysis for reverse-inlining call operands into callees
- specialized function cloning and signature rebuild for monomorphization
- dropped-result return removal tied to a caller-side `drop` rewrite
- cost measurement after nested optimization for specialized clones
- `monomorphize-always` sibling behavior beyond the registry spelling
- reduced `monomorphize` regression tests or Binaryen oracle comparisons
- a dedicated backlog slice in `agent-todo.md`

So the current repo status is best summarized as:

- names tracked
- boundary-only status tracked
- request guard tracked
- option plumbing tracked
- neighboring shared-module-pass story documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing dossier plus the local status surfaces imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced candidate/bailout tests
   - imported target
   - recursive self-call
   - unreachable call
   - trivial passthrough context
   - return-call-sensitive dropped-result bailout
2. reduced positive rewrite tests
   - constant-argument context
   - movable allocation/context operand
   - refined reference type context
   - dropped-call result specialization
   - multiple distinct contexts for the same target
3. clone-mechanics tests
   - signature derived from surviving dynamic context inputs
   - old params converted to locals
   - old vars shifted correctly
   - explicit returns removed when result becomes `none`
   - caller-side `drop` wrapper removed only when legal
4. usefulness-policy tests
   - ordinary `monomorphize` respects `monomorphize_min_benefit`
   - `monomorphize-always` shares safety gates but skips benefit rejection
5. oracle comparison
   - compare `--monomorphize` and `--monomorphize-always` output against Binaryen on reduced modules before broader artifact runs

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the families the repo will need to prove.

## Bottom line

Current Starshine `monomorphize` strategy is honest boundary-only tracking plus compatibility/config plumbing:

- the pass names are intentionally preserved in [`src/passes/optimize.mbt#L127-L138`](../../../../../src/passes/optimize.mbt#L127-L138)
- explicit requests are rejected at [`src/passes/optimize.mbt#L456-L462`](../../../../../src/passes/optimize.mbt#L456-L462)
- `--monomorphize-min-benefit` is real option surface in [`src/cli/cli.mbt#L994-L1021`](../../../../../src/cli/cli.mbt#L994-L1021) and [`src/cmd/cmd.mbt#L1666-L1678`](../../../../../src/cmd/cmd.mbt#L1666-L1678)
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L61`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L61) places the pass in the whole-module/layout bucket
- the surrounding [`monomorphize-always`](../monomorphize-always/index.md), [`inlining`](../inlining/index.md), [`inline-main`](../inline-main/index.md), and [`duplicate-function-elimination`](../duplicate-function-elimination/index.md) dossiers define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked boundary status**
- **clear option/config bridge**
- **clear sibling and neighbor map**
- **clear future boundary/module landing zone**
