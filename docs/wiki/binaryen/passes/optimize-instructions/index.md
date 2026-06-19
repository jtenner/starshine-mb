---
kind: entity
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md
  - ../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md
  - ../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md
  - ../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md
  - ../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md
  - ../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md
  - ../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md
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
  - ../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md
  - ../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md
  - ../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md
  - ../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md
  - ../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md
  - ../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md
  - ../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
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
- [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md)
  - `[O4Z-AUDIT-OI-A]` `version_130` source/lit matrix mapping upstream visitor and lit families to current Starshine coverage, explicit boundaries, and follow-up slice owners.

## Freshness and provenance note

Current durable answer:

- the detailed prose still mostly teaches from the reviewed `version_129` dossier because that is where the original deep read was filed
- the release-gating O4z audit now uses the 2026-06-19 `version_130` source/lit matrix as the current local-oracle owner map for implementation slices
- the `version_130` matrix re-anchors `OptimizeInstructions.cpp`, registration, helper headers, and the dedicated `optimize-instructions*` lit roster, and it did not find a reason to collapse the existing OI backlog: Starshine remains an active HOT subset, not full upstream parity
- future implementation slices should cite the 2026-06-19 matrix for ownership and the older `version_129` pages for explanatory strategy until those pages are fully rewritten around `version_130`

That is a `version_130` release-oracle matrix, not a live current-`main` drift audit beyond the release tag.

## Current O4z audit inventory

The 2026-06-19 behavior inventory [`../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md`](../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md) keeps `[O4Z-AUDIT-OI]` open. The same-day `version_130` matrix [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) completes `[O4Z-AUDIT-OI-A]` by mapping upstream visitor and lit families to current Starshine coverage, explicit boundaries, or follow-up slice owners. The OI-B baseline [`../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md`](../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md) captured direct and saved O4z slot evidence: the direct 1000-case lane hit the default failure ceiling after `54/1000` compared cases with `27` raw mismatches classified as scalar/default canonicalization parity gaps and `1` Binaryen/tool command failure, while the targeted native slot16 and slot44 saved replay filters each passed `2` tests. The OI-C raw gate audit [`../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md`](../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md) added trace-reason coverage for every OI raw no-op gate family, fixed the structured/loop gate ordering so precise performance-boundary reasons are reachable before the broad call/local-write gate, and proved a simple public-pipeline neutral-add cleanup still runs outside the gates. The OI-D scalar audit [`../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md`](../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md) closed the recurring default scalar mismatch family by adding integer subtraction folding, float spelling rewrites, `i32.wrap_i64` constant folding, and guarded relational operand canonicalization. The OI-E sign-extension audit [`../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md`](../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md) adds the first local scanner-style sign facts: param-pessimistic and non-param-default facts, fallthrough `local.set` facts, signed-load and sign-extension recognition, redundant sign-extension removal, and shift-pair sign-extension idiom rewrites. The OI-F boolean/select shell audit [`../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md`](../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md) classifies the existing `if` / boolean tree subset, adds constant-condition `select` cleanup with effect/trap negatives, and records branch-hint/code-metadata plus `optimize-instructions-never-fold-or-reorder` as explicit unsupported metadata/options boundaries. The first OI-G byte bulk-memory slice [`../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md`](../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md) adds constant-size-1 `memory.copy` to `i32.load8u` + `i32.store8`, constant-size-1 `memory.fill` to `i32.store8`, and a zero-size `memory.fill` boundary test because Starshine has no OI ignore-traps/TNH/IIT option support. The remaining active backlog starts with wider memory/bulk-memory and general load/store canonicalization, `call_ref`, reference/cast/descriptor/null-trap families, GC non-atomic and atomic rewrites, tuple extraction, and final direct/O4z closeout.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-instructions` parity and scheduler research.
- Use Binaryen `version_130` as the release-gating O4z source/lit matrix for new implementation slices; use the older `version_129` dossier prose as historical explanatory material until fully refreshed.
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
- [`../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md`](../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md) records the current OI behavior-gap inventory and `[O4Z-AUDIT-OI-A]` through `[O4Z-AUDIT-OI-N]` backlog split.
- [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) completes `[O4Z-AUDIT-OI-A]` with the `version_130` source/lit matrix and slice ownership map.
- [`../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md`](../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md) completes `[O4Z-AUDIT-OI-B]` with direct compare-pass and saved O4z slot16/slot44 replay evidence before behavior changes.
- [`../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md`](../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md) completes `[O4Z-AUDIT-OI-C]` with raw no-op gate trace coverage, structured gate ordering repair, and outside-gate public cleanup evidence.
- [`../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md`](../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md) completes `[O4Z-AUDIT-OI-D]` with default scalar arithmetic, float spelling, wrap-constant, and relational canonicalization coverage plus direct 10000 compare evidence.
- [`../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md`](../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md) completes `[O4Z-AUDIT-OI-E]` with the first local scanner-style sign-extension facts, redundant sign-extension removal, shift-pair sign-extension idiom rewrites, focused tests, and direct 10000 compare evidence.
- [`../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md`](../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md) completes `[O4Z-AUDIT-OI-F]` with boolean/select/ternary shell classification, constant-condition `select` cleanup, focused effect/trap negatives, branch-hint/no-fold option boundaries, and direct 10000 compare evidence.
