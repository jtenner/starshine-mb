---
kind: entity
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
  - ../../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md
  - ../../../raw/research/0232-2026-04-21-optimize-added-constants-safety-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./low-memory-threshold-overflow-and-offset-merge-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/index.md
  - ../precompute/index.md
  - ../tracker.md
---

# `optimize-added-constants`

## Role

- `optimize-added-constants` is an upstream Binaryen function pass.
- It is currently **unimplemented** in Starshine and still lives in the removed-name registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The refreshed provenance chain is captured in [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md); the 2026-05-05 current-main source-anchor digest is [`../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md) with the follow-up research note at [`../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md), the 2026-04-27 current-main / local-readiness recheck remains [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md), and the Starshine status bridge is [`./starshine-strategy.md`](./starshine-strategy.md).
- Binaryen `version_129` also exposes a public sibling name, [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md), backed by the same implementation file.
- The real pass is a **memory-address to load/store-offset** canonicalizer, not a generic arithmetic-tree optimizer.

## Why this pass matters

- The original campaign queues are closed, so this dossier remains an explicit tracker expansion rather than a leftover parity stub.
- `optimize-added-constants` and `optimize-added-constants-propagate` are both still real local removed-name registry entries.
- `agent-todo.md` currently has **no dedicated slice** for plain `optimize-added-constants`.
- The pass name is extremely easy to misread, so keeping the plain-vs-propagate split explicit is valuable for future port work.
- The public Binaryen release horizon has since advanced to `version_125`, but this folder still anchors its detailed pass reading to the reviewed `version_129` implementation baseline until a later reread says otherwise.
- The local code already carries `low_memory_unused` / `low_memory_bound` options, and the 2026-05-05 source-anchor digest now makes the exact upstream owner / registration / threshold / test lines easy to trace, but there is still no owner file or active rewrite path for this pass.

## Correction note

A previous revision of this folder treated the pass family as integer add/sub reassociation.
That was incorrect.
The reviewed official `version_129` sources show the actual contract is about **moving small added constants in memory addresses into explicit load/store offsets**, with the sibling pass adding propagation across address-carrying locals.

## Beginner summary

A good beginner mental model is:

- find a memory access like `load(base + 8)`,
- rewrite it as `load offset=8 (base)`,
- and stop there.

So the plain pass is best read as:

- **direct memory-address offset folding**, without the extra local-pair propagation step.

## Current durable takeaways

- The pass only targets `Load` / `Store` pointer expressions.
- It requires `--low-memory-unused`; otherwise Binaryen aborts the pass.
- The reviewed `version_129` threshold comes from `PassOptions::LowMemoryBound = 1024`.
- The real direct-fold rule is stricter than “small constant”: both the new constant and the merged total offset must stay **strictly below** that bound.
- Constant-pointer normalization is a separate path with unsigned-overflow checks, and memory64 changes the width of that proof rather than the low-memory bound itself.
- It does **not** use the extra `LazyLocalGraph` propagation mode that the sibling pass enables.
- Starshine currently preserves both pass spellings as removed names; the available local implementation surfaces are option plumbing plus general load/store `MemArg` infrastructure, not a hidden partial port.
- The new readiness bridge [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) defines the safe future ladder: analyzer/no-op first, direct `Load` / `Store` fold, threshold negatives, constant-pointer overflow checks, then Binaryen-oracle compare with `--low-memory-unused`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: what the plain pass owns, what it shares with the propagate sibling, and what it deliberately does not do.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./low-memory-threshold-overflow-and-offset-merge-rules.md`](./low-memory-threshold-overflow-and-offset-merge-rules.md)
  Focused guide to the exact safety matrix: the hard `--low-memory-unused` gate, strict `1023`-yes / `1024`-no threshold, merged-offset rule, and memory32-vs-memory64 constant-pointer overflow checks.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misread direct-address families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: removed registry entry, low-memory option plumbing, HOT `Load` / `Store` + `MemArg` surfaces, binary/WAT roundtrip files, validation hooks, and the explicit propagate-sibling boundary.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for a future Starshine port: exact local code surfaces, first mutating slice, required negative tests, validation ladder, and the open `low_memory_bound` parity-vs-extension decision.

## Current maintenance rule

- Treat this folder as the canonical home for plain `optimize-added-constants` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the relationship to the public sibling explicit instead of silently teaching the shared implementation file as if it only exposed one public behavior.
- Keep the exact safety matrix explicit too: the real contract is not just “small constants go into offsets,” but “strictly-low-memory merged offsets plus separate unsigned-overflow-safe constant-pointer normalization.”
- Future port-readiness or implementation work should cite [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) before moving the pass out of the removed registry.

## Sources

- [`../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md)
- [`../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md)
- [`../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md`](../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md)
- [`../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md`](../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md`](../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md)
- [`../../../raw/research/0232-2026-04-21-optimize-added-constants-safety-followup.md`](../../../raw/research/0232-2026-04-21-optimize-added-constants-safety-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
