---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lexer.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./low-memory-threshold-overflow-and-offset-merge-rules.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/index.md
  - ../precompute/index.md
  - ../tracker.md
---

# Starshine `optimize-added-constants` strategy

## Current status

Starshine does **not** currently implement `optimize-added-constants`.

The exact local status is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) preserves `optimize-added-constants` in `pass_registry_removed_names()`.
- The same file rejects removed names in `expand_passes(...)` with `pass flag ... is removed from the active hot pipeline registry`.
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md) still lists `optimize-added-constants` and `optimize-added-constants-propagate` as removed Batch 1 candidates.
- [`agent-todo.md`](../../../../../agent-todo.md) has no active dedicated `OAC` / `optimize-added-constants` implementation slice today.

So the current Starshine strategy is a **status and port map**, not an implementation description. The implementation-readiness and validation ladder now lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code map

The current repo already has the precise infrastructure a first direct-address slice would need:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) `#L143-L147`, `#L310-L313`, `#L521-L525`: removed-name registration and honest rejection.
- [`src/cli/cli.mbt`](../../../../../src/cli/cli.mbt) `#L255-L277`, `#L1033-L1043`, `#L1138-L1147`, `#L1346-L1351`: option parsing and environment plumbing for `low_memory_unused` / `low_memory_bound`.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) `#L122-L155`, `#L250-L287`, `#L494-L497`, `#L1504-L1509`: default values and config merge for the same options.
- [`src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt) `#L47-L48`, [`src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt) `#L247-L248`: `Load` / `Store` plus `MemArgTable` payload ownership.
- [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt) `#L533-L550`, [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt) `#L741-L754`, `#L1369-L1379`, [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt) `#L1077-L1079`: lift/build/lower surfaces for rewritten memory offsets.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) `#L475-L475`, `#L8192-L8193`: `MemArg` payload structure and constructor.
- [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt), [`src/wast/lexer.mbt`](../../../../../src/wast/lexer.mbt), [`src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt), [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt): roundtrip and validation surfaces.

These are the exact local surfaces a direct first slice should connect; none of them currently define a pass-owned implementation.

## What a faithful port would need to preserve

A future Starshine pass should start with the plain variant, not the propagate sibling:

1. require `low_memory_unused`,
2. use `low_memory_bound` for the strict small-offset gate,
3. visit only load/store pointer operands,
4. fold direct `base + const` and commuted `const + base` shapes into `MemArg.offset`,
5. preserve existing-offset accumulation rules,
6. normalize constant pointer plus offset only when unsigned overflow is impossible,
7. leave local-pair propagation to the sibling [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md).

The last point matters: Starshine should not silently implement the propagate variant under the plain name. The new 2026-05-05 source-anchor digest now makes the exact local implementation surfaces easy to chase from this page.

## Existing local option plumbing

Starshine already carries the Binaryen-style safety switch through the CLI and optimize options:

- [`src/cli/cli.mbt`](../../../../../src/cli/cli.mbt) parses `--low-memory-unused`, `--no-low-memory-unused`, and `--low-memory-bound`.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) stores `low_memory_unused` and `low_memory_bound` in `CmdRunSummary` and `OptimizeOptions`.
- `CmdRunSummary::new(...)` and `OptimizeOptions::new(...)` default to `low_memory_unused=false` and `low_memory_bound=1024`.
- `make_optimize_options(...)` passes both values into `OptimizeOptions`.

That means the future port does not need to invent a public option surface. It does need to decide whether parity mode always uses Binaryen's fixed `1024` contract or honors Starshine's already-configurable `low_memory_bound` field.

## HOT-IR surfaces a future direct pass would use

The direct plain pass is a plausible HOT pass once memory op mutation helpers are added or centralized.

Relevant current code surfaces:

- [`src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt) defines `HotOp::Load` and `HotOp::Store`.
- [`src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt) maps `HotOp::Load`, `HotOp::Store`, and `HotOp::Atomic` to the `MemArgTable` side table.
- [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt) has `hot_build_load(...)` and `hot_build_store(...)`, both allocating a `HotMemArg` from a `MemArg`.
- [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt) and [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt) are the roundtrip surfaces that must preserve rewritten memory offsets.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) owns the `MemArg` payload and the scalar / SIMD load-store instruction variants used outside HOT.

A minimal port can stay away from `use_def` and local SSA if it only implements direct `base + const` folding. Those analyses become important for the propagate sibling.

## Binary and WAT surfaces to keep in sync

Offset rewrites are visible in both binary and text formats, so future tests should cover both:

- [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt) decodes `MemArg` align / memory-index / offset fields.
- [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt) encodes `MemArg` and all scalar/SIMD load-store opcodes.
- [`src/wast/lexer.mbt`](../../../../../src/wast/lexer.mbt) tokenizes `align=` and `offset=`.
- [`src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt) maps scalar and SIMD load/store WAT spellings.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt) remains the post-rewrite validation guard for memory access typing and stack behavior.

## Propagate sibling boundary

Do not implement these under the plain pass name:

- `LazyLocalGraph`-equivalent local-pair discovery,
- address-carrier `local.set` / `local.get` propagation,
- helper-local insertion to snapshot an old base,
- dead-set cleanup unlocked by propagation,
- repeated propagation iterations.

Those belong to the separate [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md) contract.

## Validation plan for a future port

A future implementation should start with focused WAT fixtures before fuzzing:

1. direct load fold,
2. commuted add fold,
3. existing-offset accumulation,
4. `1023` fold and `1024` no-fold,
5. negative-constant no-fold,
6. constant-pointer normalization,
7. memory64 overflow no-fold,
8. no-memory module no-op,
9. local-carrier no-op for the plain variant.

Then validate parity with Binaryen using `--pass optimize-added-constants` and a `--low-memory-unused` configuration. The ordinary no-DWARF path does not currently make this pass a default parity blocker because the documented path does not run with low-memory-unused enabled. The detailed validation ladder, including analyzer/no-op sequencing and threshold negatives, is now in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Current local gap summary

Starshine has useful infrastructure for this pass, but no actual pass:

- registry name: present as removed,
- request behavior: honest rejection,
- option plumbing: present,
- memory-op IR payloads: present,
- direct rewrite helpers: not yet pass-owned,
- local-propagation analysis: not chosen for this pass and should stay in the sibling,
- active backlog slice: none found.

## Sources

- [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md)
- [`../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md`](../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md)
- [`../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md`](../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt)
- [`../../../../../src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
