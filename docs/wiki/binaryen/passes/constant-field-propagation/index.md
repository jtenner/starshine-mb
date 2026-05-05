---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/research/0474-2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md
  - ../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../global-type-optimization/binaryen-strategy.md
  - ../type-refining/binaryen-strategy.md
  - ../signature-refining/binaryen-strategy.md
  - ../global-struct-inference/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./copies-subtypes-ref-tests-and-atomics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../index.md
  - ../global-type-optimization/index.md
  - ../remove-unused-types/index.md
  - ../global-struct-inference/index.md
---

# `constant-field-propagation`

## Role

- `constant-field-propagation` is an upstream Binaryen **module pass family**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); see the exact local code map in [`./starshine-strategy.md`](./starshine-strategy.md).
- Upstream Binaryen `pass.cpp` registers the public CLI aliases:
  - `cfp`
  - `cfp-reftest`
- The local registry uses the fuller descriptive name:
  - `constant-field-propagation`
- In Binaryen `version_129`, the public summaries in `pass.cpp` are:
  - `propagate constant struct field values`
  - `propagate constant struct field values, using ref.test`

Those summaries are true, but too small.

A better beginner summary is:

- Binaryen scans struct-field writes across the whole module,
- tracks whether each readable field effectively always contains one literal or one immutable global,
- propagates those facts across subtype relationships and field-copy chains,
- then replaces later `struct.get` / `ref.get_desc` reads with explicit constants or `global.get`s,
- while preserving null traps, subtype validity, packed-field semantics, and atomic-synchronization boundaries.

So this is not generic constant propagation.
It is **closed-world struct-field read replacement driven by module-wide write facts**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is already dossier-covered, so this campaign needed another source-backed eligible pass.
- `constant-field-propagation` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- Existing living docs already record it as a real closed-world scheduler neighbor:
  - `global-type-optimization`
  - `type-refining`
  - `signature-refining`
- `agent-todo.md` still has **no dedicated `constant-field-propagation` or `cfp` slice**, so a stable wiki home matters even more here.
- The official implementation hides several beginner traps worth documenting explicitly:
  - the local name is `constant-field-propagation`, but upstream users type `cfp`
  - there is a real sibling variant, `cfp-reftest`, not just a hidden flag
  - the pass is **closed-world-only** and throws a fatal error without `--closed-world`
  - it is deliberately **type-level and escape-insensitive**
  - exact versus inexact references matter throughout the analysis
  - packed fields, atomics, and subtype-refined child fields create subtle rewrite boundaries

## Most important durable takeaways

- `constant-field-propagation` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `remove-unused-types` and before `gsi`.
- The pass body itself checks:
  - GC features enabled
  - `--closed-world` enabled, or else it throws a fatal error
- The pass only optimizes **struct field reads** today.
- Plain `cfp` tracks only:
  - one literal constant
  - one immutable global
  - or unknown
- `cfp-reftest` is the more aggressive sibling that can replace a read with a `select(..., ref.test(...))` when exactly two subtype-separated constants are provable.
- The real algorithm is:
  - collect writes and copies
  - propagate facts across subtypes/supertypes
  - iterate a copy fixed point
  - rewrite reads
- Ordered atomic reads are a deliberate bailout, but known-trapping reads can still collapse to `drop(ref); unreachable`.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen propagates constants in struct code.

The safer mental model is:

- Binaryen records what values each struct field can have at the **type** level,
- separates exact and inexact reference views,
- propagates those facts through subtype relationships and field-copy edges,
- and then rewrites later field reads only when all reachable dynamic instances that matter still agree.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a little constant folder for struct operations

What it actually is in `version_129`:

- a closed-world, GC-only module pass family with:
  - whole-module write scanning
  - immutable-global as well as literal tracking
  - exact-vs-inexact subtype reasoning
  - copy-propagation fixed points
  - optional two-value `ref.test` splitting
  - packed-field masking/sign-extension repair
  - atomic synchronization bailouts
  - final function refinalization after rewrites

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, and the main algorithmic phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `ConstantFieldPropagation.cpp`, `pass.cpp`, `possible-constant.h`, `struct-utils.h`, `subtypes.h`, and the official lit tests, plus the narrow current-`main` freshness note.
- [`./copies-subtypes-ref-tests-and-atomics.md`](./copies-subtypes-ref-tests-and-atomics.md)
  - Focused guide to the hardest half of the pass: exact versus inexact references, copy fixed points, why `cfp-reftest` is narrow, and why atomics split into “ordered-read bailout” versus “known-trap rewrite” cases.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering impossible reads, default/literal/global positives, subtype positives and bailouts, packed-field repairs, array-of-struct realistic shapes, atomic boundaries, and the main non-goals.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: boundary-only registry entries for the parent `constant-field-propagation` name and the `constant-field-null-test-folding` sibling, active request rejection, preset omission, missing owner file/backlog slice, and the exact local GC/type/struct/descriptor code surfaces a future closed-world module pass would need to reuse.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Implementation-readiness bridge for a future port: exact first-slice gates, validation ordering, and sibling layering rules.

## Current maintenance rule

- Treat this folder as the canonical home for future `constant-field-propagation` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the naming split explicit:
  - `constant-field-propagation` in the local registry and tracker
  - `cfp` / `cfp-reftest` upstream
- Keep the scheduler scope explicit:
  - this belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md)
- [`../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md`](../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md`](../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../global-type-optimization/binaryen-strategy.md`](../global-type-optimization/binaryen-strategy.md)
- [`../type-refining/binaryen-strategy.md`](../type-refining/binaryen-strategy.md)
- [`../signature-refining/binaryen-strategy.md`](../signature-refining/binaryen-strategy.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp.wast>
