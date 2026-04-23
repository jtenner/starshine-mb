---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0273-2026-04-23-alignment-lowering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dealign/index.md
  - ../avoid-reinterprets/index.md
  - ../i64-to-i32-lowering/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./chunk-selection-and-unreachable-semantics.md
  - ./wat-shapes.md
  - ../dealign/index.md
  - ../avoid-reinterprets/index.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine Strategy For `alignment-lowering`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main uncertainties a future parity port still has to resolve honestly.

## The honest current status

`alignment-lowering` is still **unimplemented** in Starshine.
There is no `src/passes/alignment_lowering.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus explicit non-availability:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass is not available in the active HOT pipeline today
- keep active requests honest by rejecting the pass name instead of pretending it already exists
- keep its broader planning bucket visible in the pass-port map
- keep its absence from the canonical no-DWARF path explicit
- keep the missing dedicated backlog slice explicit instead of inventing a false implementation plan
- keep the conceptual boundary from neighboring memory/legalization passes explicit

So this page is intentionally a **status-and-port-planning** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes `"alignment-lowering"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- broader pass-port planning bucket
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61)
    - `alignment-lowering` sits under the `Whole-module or layout transforms` planning group
- canonical scheduler context by omission
  - [`../no-dwarf-default-optimize-path.md`](../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `alignment-lowering` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `alignment-lowering` slice
- neighboring living dossiers a future port must keep distinct from this pass
  - [`../dealign/index.md`](../dealign/index.md)
  - [`../avoid-reinterprets/index.md`](../avoid-reinterprets/index.md)
  - [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status, the current planning gaps, and the nearby dossier boundaries that matter for future work.

## What Starshine currently does for this pass name

Today Starshine's behavior for `alignment-lowering` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `alignment-lowering` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `alignment-lowering` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and planning work instead of silently disappearing
- the current local classification already teaches an important fact: this pass is not available in the existing HOT optimizer today

That is the right current behavior for an unimplemented pass with a real upstream contract.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `alignment-lowering`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The repo keeps only a broad planning bucket, not a committed landing zone

The current pass-port map still includes `alignment-lowering`, but only in a broad bucket alongside other whole-module or layout transforms.
That is useful, but it is intentionally weaker than a dedicated backlog slice.

The durable fact to preserve is:

- the repo knows this pass matters
- but the repo has not yet committed to an exact Starshine implementation slot or delivery sequence for it

That is why this page records the missing-slice status explicitly instead of pretending a more concrete plan already exists.

## The most important local uncertainty

This is the hardest and most useful thing to keep explicit:

> the missing local question is not what `alignment-lowering` does, but where Starshine should implement that contract honestly.

Binaryen makes the upstream shape clear:

- a small per-function AST walker
- ordinary scalar `Load` / `Store` scope only
- fresh locals for single evaluation
- explicit chunk-rebuild logic

Starshine's current optimizer architecture makes the local landing zone less obvious:

- active optimization work is centered on HOT-IR rewrites plus a smaller set of module passes
- `alignment-lowering` is currently tracked only as boundary-only metadata
- there is no dedicated owner file, scheduler slot, or backlog slice naming the eventual port shape

So the most honest current Starshine strategy is:

- preserve the pass name and rejection path now
- keep the exact correctness contract documented in the Binaryen pages
- defer the exact local landing choice until future work decides whether this belongs in a HOT-side rewrite family, a post-writeback legalization pass, or some later emit/lowering boundary

That uncertainty is durable knowledge and should stay visible in the docs until the repo resolves it.

## What the future port must preserve regardless of landing zone

Even without a chosen local implementation slot, the future correctness contract is already clear from the existing dossier.
A faithful Starshine port must preserve all of these source-backed properties:

- ordinary scalar `Load` / `Store` scope only unless an intentional extension is documented
- natural-alignment no-op behavior
- single evaluation of pointer and value expressions via fresh temporaries
- explicit signed narrow-load repair
- float reinterpret staging instead of numeric conversion
- full-width 64-bit split/rebuild through 32-bit halves
- operand-preserving unreachable rewrites
- explicit offset-preserving chunk emission

For the full source-backed explanation of those invariants, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./chunk-selection-and-unreachable-semantics.md`](./chunk-selection-and-unreachable-semantics.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## The most important neighboring boundaries

### `dealign` is a sibling, not a precursor implementation plan

See:

- [`../dealign/index.md`](../dealign/index.md)

Why it matters locally:

- `dealign` weakens alignment metadata to `1`
- `alignment-lowering` legalizes weakly aligned scalar accesses by replacing them with smaller aligned accesses
- a future Starshine port should keep those jobs separate instead of treating `dealign` as a partial implementation of `alignment-lowering`

### `avoid-reinterprets` is nearby, but solves a different memory problem

See:

- [`../avoid-reinterprets/index.md`](../avoid-reinterprets/index.md)

Why it matters locally:

- both passes touch load-side shapes
- but `avoid-reinterprets` is about eliminating load-plus-reinterpret chains
- `alignment-lowering` is about memarg-alignment legality via chunked scalar accesses

That boundary helps future work avoid a vague “memory cleanup” bucket.

### `i64-to-i32-lowering` is another lowering family, not the same one

See:

- [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)

Why it matters locally:

- both passes can sound like scalar-lowering work
- but `i64-to-i32-lowering` is ABI and opcode-surface lowering
- `alignment-lowering` is memarg-alignment legalization for ordinary scalar accesses

Keeping that split explicit makes future planning cleaner.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit `alignment-lowering` implementation file
- an agreed HOT-pass or module-pass landing slot
- a dedicated backlog slice in `agent-todo.md`
- reduced local regressions specific to this pass
- artifact replay coverage specific to the pass

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- broad planning bucket tracked
- no-DWARF absence tracked
- neighboring boundaries documented
- transform itself not yet landed
- eventual landing shape still open

## Validation plan for the eventual port

The existing dossier already implies the right validation ladder.
A future real implementation should validate in roughly this order:

1. reduced shape tests for the main upstream families
   - `align=1` and `align=2` integer chunking
   - signed `load16_s` repair
   - float reinterpret staging
   - 64-bit split/rebuild families
   - unreachable operand-preserving cases
2. landing-zone honesty tests
   - explicit requested-pass rejection should stay until the real transform exists
   - once implemented, registry category and help/dispatch behavior should be updated in the same change
3. scheduler placement proof
   - document where the port actually lands in Starshine and why
   - keep the no-DWARF-absence story explicit unless that scheduler fact truly changes
4. artifact and oracle comparison
   - compare the local pass against Binaryen directly once the landing zone exists

That is more useful locally than a vague “compare with Binaryen later” note because it preserves the most important current reality: the algorithm is well-understood, but the repo still owes an honest local placement decision.

## Bottom line

Current Starshine `alignment-lowering` strategy is honest boundary-only tracking plus explicit placement uncertainty:

- the pass name is intentionally preserved in [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
- the same file keeps the active pipeline honest by rejecting boundary-only requests at [`#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61) still keeps the pass only in a broad planning bucket
- [`agent-todo.md`](../../../../../agent-todo.md) still has no dedicated slice for it
- [`../no-dwarf-default-optimize-path.md`](../no-dwarf-default-optimize-path.md) still omits it from the active canonical default route
- the neighboring [`dealign`](../dealign/index.md), [`avoid-reinterprets`](../avoid-reinterprets/index.md), and [`i64-to-i32-lowering`](../i64-to-i32-lowering/index.md) dossiers now define the practical boundary map future work should preserve

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear correctness contract from the Binaryen dossier**
- **clear neighboring memory/lowering boundaries**
- **clear missing-slice / missing-landing-zone uncertainty that future port work must resolve explicitly**
