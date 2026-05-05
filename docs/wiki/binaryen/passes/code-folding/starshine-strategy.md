---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../merge-blocks/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../rse/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../merge-blocks/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../rse/index.md
---

# Starshine Strategy For `code-folding`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md), the 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md), the focused port-readiness source manifest in [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md), the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the implementation-readiness ladder in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`code-folding` is still **unimplemented** in Starshine.
There is no `src/passes/code_folding.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary and port planning:

- keep the public pass spelling tracked in the registry surface
- keep the CLI spelling stable
- keep the pass in the canonical no-DWARF parity/backlog documents
- teach the surrounding late-cluster Starshine passes a future port would need to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page. For concrete first-slice scope, HOT prerequisites, source-backed negative gates, and validation ordering, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt:144-151`
    - `pass_registry_removed_names()` includes `"code-folding"`
  - `src/passes/optimize.mbt:469-471`
    - removed pass requests fail with the active-registry removed-pass diagnostic
- preset omission
  - `src/passes/optimize.mbt:385-410`
    - public `optimize` / `shrink` preset expansion does not include `code-folding` yet
- CLI spelling and pass-flag preservation proof
  - `src/cli/cli_test.mbt:159-165`
    - `parse_cli_args parses long-form kebab-case pass flags`
  - `src/cli/cli_test.mbt:297-309`
    - `resolve_pass_flags preserves cli token order for presets and explicit passes`
    - `resolve_pass_flags keeps explicit pass order when no presets are set`
- dispatcher absence
  - `src/passes/pass_manager.mbt`
    - no `code-folding` match or owner branch today
- backlog and delivery plan
  - `agent-todo.md`
    - `CF` slice under the Binaryen no-DWARF default optimize pathway parity section
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the late-cluster slot where `code-folding` belongs before `merge-blocks`
- surrounding implemented Starshine cleanup consumers
  - `docs/wiki/binaryen/passes/merge-blocks/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-names/index.md`
  - `docs/wiki/binaryen/passes/rse/index.md`

That code-and-doc map, plus [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), lets readers jump directly from the upstream algorithm to exact local status, official test families, and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `code-folding` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `code-folding` in `pass_registry_removed_names()`.
That means:

- the project still treats `code-folding` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The CLI spelling is intentionally stable

`src/cli/cli_test.mbt` proves the spelling `--code-folding` is still accepted and preserved in pass-flag order tests.

That matters for two reasons:

- docs and future user-facing parity commands can keep using the upstream pass spelling consistently
- once a real implementation lands, the public spelling does not need a second documentation migration first

### 3. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives `code-folding` a real backlog slice under `CF`.
The current deliverables are framed around the right upstream concerns:

- motion-safety rules
- rewrite coverage
- artifact validation against Binaryen

That backlog framing already matches the upstream dossier better than a vague “tail dedup” summary would.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `code-folding` port should be taught as a **late-cluster HOT rewrite family**, not as an isolated generic optimizer.

Why:

- Binaryen runs it late
- the pass can add helper structure
- later cleanup passes are expected to simplify that helper structure again
- Starshine already has active late-cluster cleanup passes in exactly that neighborhood

So the local strategy should be thought of as:

1. identify a HOT-level representation of the two upstream families
   - expression-exit tail sharing
   - function-terminating tail sharing
2. prove the same movement-safety boundaries locally
   - branch-target scope
   - EH-sensitive movement
   - no silent broadening to unsupported branch forms
3. rely on existing late-cluster Starshine neighbors to consume the helper structure
   - `merge-blocks`
   - `remove-unused-brs`
   - `remove-unused-names`
   - later `rse`

In other words, the future port should slot into a local cleanup ecosystem that already exists.

## The most important local dependency map

### Upstream `code-folding` output would feed directly into local `merge-blocks`

See [`../merge-blocks/index.md`](../merge-blocks/index.md).

Why it matters locally:

- Binaryen `code-folding` may add helper blocks
- Starshine already has an active late `merge-blocks` pass that exists to flatten branch-free wrappers and expose simpler shapes downstream

So a future Starshine `code-folding` port should preserve that cleanup handoff instead of trying to do every structural simplification itself.

### It would also create work for local `remove-unused-brs`

See [`../remove-unused-brs/index.md`](../remove-unused-brs/index.md).

Why:

- upstream `code-folding` often rewrites duplicate tails into branch traffic toward a shared suffix
- late branch cleanup is therefore part of the intended payoff, not an accidental afterthought

A future local implementation should keep that relationship explicit.

### It also interacts with local `remove-unused-names`

See [`../remove-unused-names/index.md`](../remove-unused-names/index.md).

Why:

- helper labels and old labels can become redundant after tail sharing
- Binaryen already relies on late name cleanup in the same neighborhood
- Starshine's implemented local label-cleanup pass is therefore part of the practical port boundary

### Late `rse` is part of the payoff story too

See [`../rse/index.md`](../rse/index.md).

Why:

- once a single shared tail exists, later local redundancy cleanup has a clearer single-copy shape to analyze
- that makes `code-folding` more than a standalone size transform in the scheduler story

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `code-folding` MoonBit implementation file
- HOT or module-level candidate collection for duplicate tails
- local branch-scope movement analysis specifically for this pass
- a function-ending helper-label tail-sharing rewriter
- pass-specific tests or CLI execution coverage beyond the tracked spelling
- a `pass_manager` dispatcher branch for `code-folding`

So the current repo status is best summarized as:

- name tracked
- backlog tracked
- scheduler slot documented
- neighboring consumers implemented
- transform itself not yet landed

## Validation plan for the eventual port

The dedicated port-readiness page now owns the detailed test-first ladder: [`./starshine-port-readiness-and-validation.md#validation-ladder`](./starshine-port-readiness-and-validation.md#validation-ladder).
The short version is still:

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the two upstream families
   - named block-exit tails
   - unnamed foldable `if`-arm tails
   - terminating `return` / `return_call*` / `unreachable` tails
2. negative movement-safety tests
   - outer break-target scope hazards
   - unsupported branch-form poison cases
   - EH-sensitive movement barriers
3. late-cluster interaction tests
   - `code-folding -> merge-blocks`
   - `code-folding -> remove-unused-brs`
   - `code-folding -> remove-unused-names`
4. artifact and oracle comparison
   - the `CF` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow.

## Bottom line

Current Starshine `code-folding` strategy is honest boundary tracking plus port planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- CLI spelling is intentionally preserved in `src/cli/cli_test.mbt`
- the backlog already treats it as a real late-parity slice under `CF`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding implemented cleanup passes already exist and define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot in the pipeline**
- **clear neighboring implementation map for the eventual port**

## Sources

- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
