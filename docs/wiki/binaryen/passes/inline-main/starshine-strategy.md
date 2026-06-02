---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md
  - ../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./special-case-contract-and-boundaries.md
  - ./wat-shapes.md
  - ../inlining/index.md
  - ../inlining-optimizing/index.md
  - ../monomorphize/index.md
  - ../tracker.md
---

# Starshine strategy for `inline-main`

## Current status

Starshine currently treats `inline-main` as a **boundary-only compatibility name**, not as an executable pass.

That means:

- the pass is known to the registry,
- it is not listed in pass help as an active hot/preset pass,
- explicit requests are rejected before any hot or module pass body runs,
- there is no local owner file equivalent to Binaryen's `InlineMainPass`,
- and the default `optimize` / `shrink` presets do not schedule it.

This is intentionally different from an unknown pass. The name is preserved so future work can keep the public Binaryen vocabulary, but the implementation is not present today.

## Exact local code locations

| Local surface | Exact file | Current meaning |
| --- | --- | --- |
| Registry category | [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) `pass_registry_boundary_only_names()` | Contains `inline-main` among boundary-only names. |
| Registry materialization | [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) `pass_registry_entries()` | Converts the boundary-only name into a `HotPassRegistryEntry` with no descriptor and no expanded passes. |
| Active-pass rejection | [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) `run_hot_pipeline_expand_passes(...)` | Returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline` for `inline-main`. |
| Default presets | [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) `optimize_preset_passes(...)` and `shrink_preset_passes(...)` | Neither preset includes `inline-main`. |
| Option surface | [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) `InliningOptions` and `OptimizeOptions` | `InliningOptions` is currently a placeholder; no dedicated `inline-main` implementation hook exists. |
| Compatibility map | [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md) | Lists `inline-main` in Batch 4 compatibility / boundary pass names. |
| Backlog | [`../../../../../agent-todo.md`](../../../../../agent-todo.md) | No active `inline-main` slice was found during the 2026-04-24 review. |

## How this maps to the Binaryen strategy

Binaryen's [`./binaryen-strategy.md`](./binaryen-strategy.md) says the upstream pass has two layers:

1. a tiny `main` / `__original_main` chooser, and
2. the ordinary inline-body rewriter.

Starshine currently has neither layer for this pass:

- there is no module-level chooser that looks up `main` and `__original_main`,
- there is no direct-call-only scan in `main`,
- there is no exact-one-call acceptance rule,
- and there is no shared inlining helper wired for copied-body insertion, return lowering, label repair, refinalization, or nondefaultable-local fixes.

So the local strategy today is **honest rejection**, not partial emulation.

## Future implementation shape

A faithful local port should be a module pass, not a HOT peephole.

The minimum module pass would need to:

1. find defined functions named exactly `main` and `__original_main`,
2. reject if either endpoint is absent or imported,
3. scan only direct call expressions inside `main`,
4. accept only if exactly one direct call targets `__original_main`,
5. inline the callee body into the caller with a reusable helper,
6. repair local indices/types and copied locals,
7. lower returns in the copied body to a safe caller-local control shape,
8. avoid label capture and preserve or intentionally drop metadata,
9. refinalize/revalidate the resulting module,
10. leave dead helper-function deletion to neighboring passes such as remove-unused module-element work.

The most important local design warning is that step 5 cannot be a raw AST/text substitution. The upstream pass's small chooser still delegates to the same heavy inline repair machinery used by ordinary inlining.

## How to validate a future port

A future Starshine port should start with exact upstream acceptance families from [`./wat-shapes.md`](./wat-shapes.md):

- defined one-call `main` wrapper should inline,
- already-inlined `main` should stay unchanged,
- missing `main` should stay unchanged,
- missing `__original_main` should stay unchanged,
- imported `main` should stay unchanged,
- imported `__original_main` should stay unchanged,
- two direct calls from `main` to `__original_main` should stay unchanged.

Then add helper-inheritance tests that go beyond the tiny official lit file:

- callee with `return`,
- callee with labels that could collide with labels in `main`,
- callee with locals that require remapping,
- nondefaultable local cases once the local type surface can express them,
- follow-up `remove-unused-module-elements` composition for deleting now-dead `__original_main` only when that separate pass is requested.

Final parity should use the pass-targeted compare harness with the canonical upstream spelling:

```text
bun fuzz compare-pass --pass inline-main ...
```

Use the living pass implementation rules in [`../../../../../AGENTS.md`](../../../../../AGENTS.md) and keep any future active backlog slice in `agent-todo.md` until implemented.

## Cross-links for readers

- Start with the pass overview: [`./index.md`](./index.md)
- Read the Binaryen source strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Check the upstream file/test map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Classify exact transformed and preserved module shapes: [`./wat-shapes.md`](./wat-shapes.md)
- Understand the special-case boundary: [`./special-case-contract-and-boundaries.md`](./special-case-contract-and-boundaries.md)
- Compare with general inlining: [`../inlining/index.md`](../inlining/index.md)
- Compare with optimizing inlining: [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md)
- Compare with callsite specialization: [`../monomorphize/index.md`](../monomorphize/index.md)

## Open questions

- Whether a future local port should share infrastructure with a broader `inlining` port or land a smaller purpose-built helper first is undecided.
- The local metadata policy for copied instructions is not designed yet. Binaryen copies metadata through the shared helper, but Starshine should document the exact local choice before implementation.
- The pass should remain out of default presets unless a later scheduler policy explicitly adds a frontend-wrapper cleanup phase.

## Sources

- [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md)
- [`../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
