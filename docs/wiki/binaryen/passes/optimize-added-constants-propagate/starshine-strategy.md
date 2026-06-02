---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0330-2026-04-25-optimize-added-constants-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/passes/remove_unused_names.mbt
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
  - ./wat-shapes.md
  - ../optimize-added-constants/index.md
  - ../optimize-added-constants/starshine-strategy.md
  - ../precompute-propagate/index.md
  - ../tracker.md
---

# Starshine `optimize-added-constants-propagate` strategy

## Current status

Starshine does **not** currently implement `optimize-added-constants-propagate`.

The exact local status is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps `optimize-added-constants-propagate` in `pass_registry_removed_names()` next to the plain sibling.
- The same file's `expand_passes(...)` path rejects removed names with `pass flag ... is removed from the active hot pipeline registry`.
- [`optimize_preset_passes(...)`](../../../../../src/passes/optimize.mbt) and [`shrink_preset_passes(...)`](../../../../../src/passes/optimize.mbt) do not schedule this pass.
- No `src/passes/optimize_added_constants_propagate.mbt` owner file exists today.
- No dispatcher case or active `agent-todo.md` implementation slice was found in this run.

So the current Starshine strategy is a **status and port map**, not an implementation description.

## What the future pass must preserve

A faithful port must preserve the plain sibling's direct load/store-address contract and then add the propagate-only behavior.

Required behavior:

1. require `low_memory_unused`,
2. use the strict low-memory cutoff for both the candidate constant and the final merged offset,
3. rewrite direct `Load` / `Store` pointer operands shaped like `base + small_const` into `MemArg.offset`,
4. keep negative constants, too-large constants, and overflow-sensitive memory64 constant-pointer cases out of the fold,
5. build a conservative local-pair proof for `local.set(add(base, const))` feeding `local.get` address uses,
6. remove now-dead address `local.set`s only when all influenced uses were safely rewritten,
7. insert helper locals when direct base reuse would observe a later mutation,
8. iterate because one local cleanup can unlock the next propagation,
9. preserve visible `nop` / helper-local shapes where they carry Binaryen-compatible semantics.

The final four items are the reason this is a separate pass page. They must not be silently folded into the plain [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md) contract.

## Existing local option plumbing

Starshine already carries the Binaryen-style safety option through the CLI and command layer:

- [`src/cli/cli.mbt`](../../../../../src/cli/cli.mbt) parses `--low-memory-unused`, `--no-low-memory-unused`, and `--low-memory-bound`.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) stores `low_memory_unused` and `low_memory_bound` in both `CmdRunSummary` and `OptimizeOptions`.
- `CmdRunSummary::new(...)` and `OptimizeOptions::new(...)` default to `low_memory_unused=false` and `low_memory_bound=1024UL`.
- `make_optimize_options(...)` passes both values into the optimizer.
- `cmd_post_encode_repro_note(...)` includes the low-memory flags when constructing repro text.

Open design question: Binaryen's reviewed source uses the fixed public `PassOptions::LowMemoryBound = 1024`, while Starshine exposes `low_memory_bound` as configurable. A parity port should make that choice explicit instead of accidentally mixing the two policies.

## HOT-IR and memory-offset landing zones

The direct address rewrite side would reuse the same local surfaces as the plain pass:

- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) defines `MemArg` and the scalar / SIMD / atomic memory instruction payloads.
- [`src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt) defines `HotMemArg` and HOT-side side-table arrays.
- [`src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt) maps `HotOp::Load`, `HotOp::Store`, and `HotOp::Atomic` to `MemArgTable`, and provides `hot_memarg_get(...)` / `hot_alloc_memarg(...)`.
- [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt) provides `hot_build_load(...)` and `hot_build_store(...)` helpers that allocate `HotMemArg` payloads.
- [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt) lifts scalar loads/stores into `HotOp::Load` / `HotOp::Store` with memory-argument payloads.
- [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt) is the writeback surface that must preserve rewritten memory offsets.

A future implementation needs a small, explicit helper for replacing a load/store node's memory argument and address child. The current surfaces make the representation possible, but there is no pass-owned address-fold helper yet.

## Local-pair propagation landing zone

The propagate sibling needs more than direct memory-op mutation.
It needs a conservative local-pair proof comparable to Binaryen's `LazyLocalGraph` use.

Relevant Starshine surfaces:

- [`src/passes/remove_unused_names.mbt`](../../../../../src/passes/remove_unused_names.mbt) shows a pass descriptor requesting `@ir.HotAnalysis::use_def()`.
- [`src/ir/hot_flags.mbt`](../../../../../src/ir/hot_flags.mbt) marks `HotOp::LocalSet` and `HotOp::LocalTee` as side-effecting, and marks memory loads/stores with load/store/trap flags.
- [`src/ir/effects.mbt`](../../../../../src/ir/effects.mbt) classifies `HotOp::Load` as memory-read and `HotOp::Store` as memory-write.

Those surfaces are only prerequisites. A faithful port still needs pass-local logic for:

- identifying address-carrier `local.set`s,
- proving all affected `local.get` uses are memory addresses eligible for offset folding,
- detecting later writes to the base local,
- deciding whether direct base reuse is safe,
- inserting helper locals when it is not,
- and removing dead address sets without breaking stack order.

## Binary, WAT, and validation surfaces

Offset rewrites are observable in both text and binary output:

- [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt) decodes `MemArg` alignment, memory-index, and offset fields.
- [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt) encodes `MemArg` payloads for memory operations.
- [`src/wast/lexer.mbt`](../../../../../src/wast/lexer.mbt) tokenizes `align=` and `offset=`.
- [`src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt) maps scalar and SIMD load/store WAT spellings.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt) remains the post-rewrite guard for address/result typing and stack behavior.

Future tests should include both WAT-visible offset changes and binary roundtrip cases so the helper-local / `nop` artifacts are not hidden by pretty-print expectations alone.

## Minimal future validation plan

Start by porting the plain direct sibling first, then add propagate-only fixtures.

Propagate-specific tests should cover:

1. dead address-local propagation into one load,
2. address-local propagation into one store,
3. commuted `const + base` address locals,
4. repeated stack-pointer style locals that require iteration,
5. helper-local salvage when the base local is mutated before the load/store,
6. extra-use bailout where the address local is used outside memory addresses,
7. too-large constant and negative-constant no-fold cases,
8. memory64 overflow-sensitive constant-pointer preservation,
9. no-memory module no-op when `low_memory_unused` is present,
10. explicit rejection or no-op when `low_memory_unused` is absent, depending on the final Starshine API policy.

Parity fuzzing should use Binaryen with `--pass optimize-added-constants-propagate --low-memory-unused`; the ordinary documented no-DWARF path does not currently schedule this pass because that path is not a low-memory-unused configuration.

## Current local gap summary

Starshine has useful infrastructure for the pass but no actual implementation:

- registry name: present as removed,
- request behavior: honest removed-pass rejection,
- preset role: none,
- owner file: none,
- option plumbing: present,
- memory-op IR payloads: present,
- direct memory-arg rewrite helper: not yet pass-owned,
- local-pair propagation proof: not yet implemented,
- helper-local insertion policy: not yet implemented,
- active backlog slice: none found.

## Sources

- [`../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md)
- [`../../../raw/research/0330-2026-04-25-optimize-added-constants-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0330-2026-04-25-optimize-added-constants-propagate-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md`](../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt)
- [`../../../../../src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- [`../../../../../src/ir/hot_flags.mbt`](../../../../../src/ir/hot_flags.mbt)
- [`../../../../../src/ir/effects.mbt`](../../../../../src/ir/effects.mbt)
- [`../../../../../src/passes/remove_unused_names.mbt`](../../../../../src/passes/remove_unused_names.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
