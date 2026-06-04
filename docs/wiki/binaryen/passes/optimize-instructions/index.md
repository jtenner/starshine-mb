---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../heap-store-optimization/index.md
  - ../vacuum/index.md
---

# `optimize-instructions`

## Role

- `optimize-instructions` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `optimize-instructions` is a function-parallel post-walk peephole and canonicalization pass.
- The public summary in `pass.cpp` is only `optimizes instruction combinations`.

That summary is true, but it is far too small.

A better beginner summary is:

- Binaryen first canonicalizes many instruction spellings,
- then rewrites arithmetic, boolean, control, memory, `call_ref`, GC-cast, and tuple-adjacent shapes when helper analyses say the rewrite is safe,
- and finally repairs changed types and EH-pop structure before it finishes.

## Why this pass matters

- The canonical no-DWARF `-O` / `-Os` scheduler uses it **twice** in the default function pipeline:
  - once early
  - once late
- The saved generated-artifact `-O4z` audit also saw it at two real top-level Binaryen slots:
  - slot `16`
  - slot `44`
- The saved Binaryen debug log contains `36` `running pass: optimize-instructions` lines in total, so nested optimizing reruns make it much more common than the two visible top-level slots suggest.
- The pass sits directly beside other cleanup and simplification neighbors already tracked in the wiki:
  - `precompute`
  - `heap-store-optimization`
  - `vacuum`
  - `rse`

## Most important durable takeaways

- Binaryen `optimize-instructions` is **not** just constant folding.
- Binaryen `optimize-instructions` is **not** just integer arithmetic peepholes.
- The real `version_129` pass combines:
  1. local bit/sign-extension prescan
  2. canonicalization of compares and commutative shapes
  3. arithmetic, boolean, and ternary-shell cleanup
  4. memory and bulk-memory simplification
  5. `call_ref` target cleanup
  6. GC cast, null-trap, and constructor/default rewrites
  7. deferred `ReFinalize`, final cleanup, and EH-pop repair
- Current Starshine implements a real but narrower HOT subset centered on integer, boolean, control, and writeback-safety cleanup.
- The earlier generated-artifact failures in slots `16` and `44` are now retired.
  - The durable explanation is still that those failures were HOT-lowering / writeback issues, not a still-open pass-local corruption family.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `optimize-instructions` is just `eqz`, compare-to-zero, and a few arithmetic identities

The safer mental model is:

- Binaryen uses the pass as a broad instruction-shape canonicalizer,
- then exploits the canonical form across arithmetic, boolean, memory, `call_ref`, and GC/reference-typed surfaces,
- while preserving effect order, trap behavior, and type validity.

That difference matters a lot for future parity work.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small math peephole pass

What it actually is in `version_129`:

- a large function-parallel AST post-walk with local bit/sign-extension scanning, iterative canonicalization, arithmetic and ternary peepholes, memory and bulk-memory cleanup, `call_ref` directization, GC cast/trap logic, and deferred refinalization plus EH repair.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and why the public name undersells the pass.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner-file and lit-test map for the pass, including the exact split between `OptimizeInstructions.cpp`, registration files, helper headers, and the distributed dedicated lit surface.
- [`./gc-casts-call_ref-and-trap-sensitive-rewrites.md`](./gc-casts-call_ref-and-trap-sensitive-rewrites.md)
  - Focused guide to the easiest part of the pass to underestimate: null-trap reasoning, cast removal limits, descriptor/exactness handling, `call_ref` lowering, and unshared GC atomic rewrites.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive, negative, bailout, control, memory, GC, `call_ref`, tuple, and metadata-sensitive rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine strategy overview for the implemented HOT subset, with exact registry, dispatcher, owner-file, test, and CLI replay code locations.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit helper and code-map companion for the implemented HOT subset, plus the major upstream Binaryen behaviors the repo still does not model.
- [`../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md)
  - Immutable capture of the official Binaryen release, source, and lit-test URLs re-checked for this dossier on 2026-04-22.
- [`../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md)
  - Immutable capture of the 2026-05-05 current-main spot check for the same contract surfaces.

## Freshness and provenance note

Current durable answer:

- the official Binaryen GitHub `version_129` release page remains the tagged anchor for the dossier and still showed publish date **2026-04-01** on the reviewed 2026-04-22 capture
- the dossier now has an immutable raw primary-source manifest for the original release/source/test provenance and a second immutable current-main recheck manifest dated 2026-05-05
- the 2026-05-05 current-main spot check on `OptimizeInstructions.cpp`, `pass.cpp`, and representative default/sign-extension/bulk-memory/`call_ref`/GC/multivalue tests did not surface a new teaching-relevant contract drift beyond what this dossier already teaches

That is still a spot check, not a full current-`main` drift audit.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-instructions` parity and scheduler research.
- Use Binaryen `version_129` as the current source oracle.
- Keep the Binaryen strategy page and the Starshine strategy page in sync whenever the in-tree implementation grows beyond the current integer / boolean / control-focused HOT subset.
- Keep the landing page honest about the ordered-artifact story:
  - slot `16` is retired
  - slot `44` is retired
  - the remaining work is documentation depth, parity breadth, and runtime honesty, not an open hard-corruption witness

## Sources

- [`../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md)
- [`../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md`](../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md)
- [`../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md`](../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md)
- [`../../../../../src/passes/optimize_instructions.mbt`](../../../../../src/passes/optimize_instructions.mbt)
- [`../../../../../src/passes/optimize_instructions_test.mbt`](../../../../../src/passes/optimize_instructions_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
