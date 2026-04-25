---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../heap2local/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# `optimize-casts` Implementation Structure And Tests

This page is the source-location map for the `optimize-casts` dossier. Read it after the overview in [`./index.md`](./index.md) and the algorithm explanation in [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Short version

Binaryen `optimize-casts` is small enough to summarize as one owner file plus helper contracts:

| Surface | What it proves |
| --- | --- |
| `src/passes/OptimizeCasts.cpp` | The pass is GC-gated, function-parallel, and split into earlier-motion plus later-reuse halves over `ref.cast` / `ref.as_non_null`. |
| `src/passes/pass.cpp` | Public pass registration and default-pipeline placement after `heap2local` and before later local cleanup. |
| `src/passes/opt-utils.h` | `optimize-casts` also participates in nested default-function-pipeline reruns after inlining-oriented passes. |
| `src/passes/passes.h` | Public pass constructor declaration surface. |
| `src/ir/linear-execution.h` | The pass reasons in linear windows, not arbitrary CFG dominance. |
| `src/ir/properties.h` | Fallthrough discovery through local gets/tees/wrappers and the explicit extern-conversion boundary. |
| `src/ir/effects.h` | Trap/side-effect barriers for the earlier-motion half. |
| `src/ir/utils.h` | `ReFinalize` helper used after both rewrite halves. |
| `test/lit/passes/optimize-casts.wast` | Official examples for positive rewrites, same-index barriers, side-effect/call barriers, and unsupported nearby families. |

The 2026-04-25 current-main source bridge found no teaching-relevant drift from the 2026-04-22 `version_129` dossier. See [`../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md).

## Upstream owner file

The core owner file is Binaryen's `src/passes/OptimizeCasts.cpp`:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>

The important internal owners are:

### `OptimizeCasts`

The public pass class owns the outer contract:

- function-parallel pass
- GC feature gate
- run earlier-motion phase
- `ReFinalize`
- run later-reuse phase
- `ReFinalize` again

This file is the source of truth for the dossier's main warning: the pass name is broader than the implementation. The reviewed pass handles `ref.cast` and `ref.as_non_null`, not `ref.test`, `br_on_cast`, descriptor casts, or extern conversions.

### `EarlyCastFinder` plus `EarlyCastApplier`

This pair owns the strict half:

- find the earliest safe `local.get` target in a linear window
- remember the most refined later `ref.cast` or useful `ref.as_non_null`
- flush pending candidates at effect/control/local-write barriers
- duplicate casts onto the earlier target get when safe

Correctness hinge: this half may move a trapping cast earlier, so it must preserve trap timing around calls, side effects, local writes, and non-linear control.

### `BestCastFinder` plus `FindingApplier`

This pair owns the looser later-reuse half:

- remember the best already-computed casted value for each local
- record later less-refined gets that can read that value
- add a fresh local of the refined type
- replace the cast site with a `local.tee` into the fresh local
- redirect the later gets to the fresh local

Correctness hinge: this half does not move the original cast site, so it can use a wider adjacent-block window than earlier motion.

## Scheduler and registration surface

### `pass.cpp`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>

What it proves:

- `optimize-casts` is a public pass name.
- The default function pipeline places it in the GC/local cleanup cluster.
- The order is meaningful: `heap2local` feeds it, then `local-subtyping`, `coalesce-locals`, and `local-cse` consume the cleaner refined-local flow.

### `opt-utils.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

What it proves:

- `optimize-casts` is not only a single top-level no-DWARF slot.
- It can reappear inside nested default-function-pipeline cleanup after inlining-oriented changes.

### `passes.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>

What it proves:

- Binaryen exposes the pass constructor through its ordinary pass declaration surface.

## Helper surfaces

### `linear-execution.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>

This is the reason the pass should be taught as local-window reasoning rather than CFG-wide cast propagation.

Important split:

- earlier-motion uses the stricter non-adjacent-window mode
- later-reuse enables adjacent-block connection

### `properties.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>

This helper surface explains why the pass can see through fallthrough wrappers and local tees, and why extern conversions are not treated as ordinary cast fallthroughs here.

### `effects.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>

This is the source-backed reason `global.set`, calls, and other effect/control surfaces block earlier cast movement.

### `utils.h`

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>

This provides the `ReFinalize` machinery that makes the inserted casts, fresh locals, and redirected gets type-correct after each phase.

## Official lit-test surface

Primary source:

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast>
- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>

The lit file proves these families directly enough for wiki teaching:

| Family | What to look for in the living shape catalog |
| --- | --- |
| Later refined-local reuse | A cast result is stored in a fresh local and later gets use that local. |
| Earlier motion | A later cast is duplicated onto an earlier get when no barrier intervenes. |
| Most-refined subtype preference | Narrower compatible casts beat wider compatible casts. |
| `ref.as_non_null` | Nullable locals can get useful non-null refinements; already-non-null locals do not need pointless duplication. |
| Same-index local write | `local.set $x` kills remembered facts about `$x`. |
| Effects and calls | Earlier movement is blocked when trap timing could change. |
| Separate locals | A write to `$x` does not kill facts about `$y`. |
| Unsupported neighbors | `ref.test`, `br_on_cast`, and extern conversions are not this pass's rewrite surface. |

See [`./wat-shapes.md`](./wat-shapes.md) for beginner-friendly before/after examples.

## Current Starshine implementation map

Starshine does **not** have an `optimize-casts` implementation file yet. The exact current local status is:

- `src/passes/optimize.mbt:145-152`
  - `pass_registry_removed_names()` includes `"optimize-casts"`
  - active requests are therefore rejected as a known removed pass rather than dispatched to a transform
- `src/passes/pass_manager.mbt`
  - there is no `optimize-casts` dispatcher case today
- `agent-todo.md:355-364`
  - backlog slice `OC` tracks the eventual port and the current broader-than-upstream `ref.test` planning caveat

The reusable local primitives a future port would build on are:

| Local file | Current relevant surface |
| --- | --- |
| `src/lib/types.mbt:723-764` | Instruction variants for `RefAsNonNull`, `RefTest`, `RefCast`, descriptor casts, `BrOnCast`, and extern conversions. |
| `src/lib/types.mbt:3995-3996` | `Instruction::ref_as_non_null()` constructor. |
| `src/lib/types.mbt:4170-4171` | `Instruction::ref_cast(...)` constructor. |
| `src/wast/lower_to_lib.mbt:1297-1298` | WAT lowering for `ref.as_non_null`. |
| `src/binary/encode.mbt:2580` | Binary opcode emission for `ref.as_non_null`. |
| `src/binary/encode.mbt:2897-2912` | Binary opcode emission for nullable and non-nullable `ref.cast`. |
| `src/binary/decode.mbt:3116-3124` | Binary decode surface for `ref.cast`. |
| `src/validate/typecheck.mbt:3228` | Validation dispatch for `ref.as_non_null`. |
| `src/validate/typecheck.mbt:3265` | Validation dispatch for `ref.cast`. |
| `src/ir/hot_core.mbt:70-73` | HOT op variants for cast/test families. |
| `src/ir/hot_flags.mbt:81` | HOT trap flag for `RefCast` / descriptor cast. |
| `src/ir/hot_lift.mbt:612-625` | HOT arity/classification surface for unary/ref cast/test families. |
| `src/ir/hot_lift.mbt:764-818` | Instruction-to-HOT classification for ref test/cast and unary `ref.as_non_null`. |
| `src/ir/hot_lower.mbt:1080-1084` | HOT-to-lib lowering family for ref test/cast operations. |

## What this means for a future port

A future Starshine implementation should be scoped as a GC/local HOT pass unless a deliberate design chooses otherwise. The minimum parity-shaped plan is:

1. keep the upstream scope to `ref.cast` and `ref.as_non_null`
2. implement strict earlier-motion windows with effect/control/local-write barriers
3. implement later reuse through fresh refined carrier locals
4. refinalize or locally repair types after each phase
5. prove same-index local writes and trap-timing barriers before adding broader cluster tests
6. validate in the real scheduler neighborhood with [`../heap2local/index.md`](../heap2local/index.md), [`../local-subtyping/index.md`](../local-subtyping/index.md), [`../coalesce-locals/index.md`](../coalesce-locals/index.md), and [`../local-cse/index.md`](../local-cse/index.md)

## Non-goals to preserve

Do not use this pass folder as evidence that Starshine should implement a generic cast optimizer. The current upstream primary sources do not make `optimize-casts` responsible for:

- `ref.test`
- `br_on_cast` / `br_on_cast_fail`
- descriptor-cast rewrites
- extern-conversion simplification
- whole-CFG cast propagation
- deleting all casts made redundant by the fresh-local rewrite

Those may be useful future work, but they are not the reviewed `optimize-casts` contract.

## Sources

- [`../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md)
- [`../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md)
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast>
