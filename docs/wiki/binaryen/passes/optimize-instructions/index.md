---
kind: entity
status: supported
last_reviewed: 2026-06-20
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
  - ../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md
  - ../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md
  - ../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md
  - ../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md
  - ../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md
  - ../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md
  - ../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md
  - ../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md
  - ../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md
  - ../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md
  - ../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md
  - ../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md
  - ../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md
  - ../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md
  - ../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md
  - ../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md
  - ../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md
  - ../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md
  - ../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md
  - ../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md
  - ../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md
  - ../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md
  - ../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md
  - ../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md
  - ../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md
  - ../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md
  - ../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md
  - ../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md
  - ../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md
  - ../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md
  - ../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md
  - ../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md
  - ../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md
  - ../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md
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
  - ../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md
  - ../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md
  - ../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md
  - ../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md
  - ../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md
  - ../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md
  - ../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md
  - ../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md
  - ../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md
  - ../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md
  - ../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md
  - ../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md
  - ../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md
  - ../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md
  - ../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md
  - ../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md
  - ../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md
  - ../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md
  - ../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md
  - ../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md
  - ../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md
  - ../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md
  - ../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md
  - ../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md
  - ../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md
  - ../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md
  - ../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md
  - ../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md
  - ../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md
  - ../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md
  - ../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md
  - ../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md
  - ../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md
  - ../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md
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

The 2026-06-19 behavior inventory [`../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md`](../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md) keeps `[O4Z-AUDIT-OI]` open. The same-day `version_130` matrix [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) completes `[O4Z-AUDIT-OI-A]` by mapping upstream visitor and lit families to current Starshine coverage, explicit boundaries, or follow-up slice owners. The OI-B baseline [`../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md`](../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md) captured direct and saved O4z slot evidence: the direct 1000-case lane hit the default failure ceiling after `54/1000` compared cases with `27` raw mismatches classified as scalar/default canonicalization parity gaps and `1` Binaryen/tool command failure, while the targeted native slot16 and slot44 saved replay filters each passed `2` tests. OI-C through OI-F covered raw-gate trace accountability, default scalar parity, first sign-extension facts, and boolean/select shell cleanup. The eighteen OI-G slices add size-`1`/`2`/`4`/`8` `memory.copy` exact load/store lowering, constant/local-value `memory.fill` lowering for selected sizes, memory64 fixture/typechecker coverage, narrow stored-value mask/truncation cleanup, memory32/memory64 constant-pointer static-offset folding, explicit `memory.copy` and `load-call-optimize-instructions-noop` boundaries, size-1 constant fill low-byte truncation, and a nonconstant pointer-add offset no-change boundary. The first seven OI-H sub-slices cover direct `ref.func` targets to direct `call` / `return_call`, `table.get` targets to `call_indirect` / `return_call_indirect`, zero-argument select-of-direct-`ref.func` targets to direct-call `if` arms, the superseded argument-bearing select localization boundary, zero-argument fallthrough-known block targets to dropped-target plus direct-call forms, positive single-result argument select localization, and boundary negatives for mixed select arms plus argument-bearing fallthrough-known targets. The first OI-I sub-slice [`../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md`](../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md) adds local null-reference basics: `ref.is_null(ref.null)` to `i32.const 1`, `ref.eq(x, null)` / `ref.eq(null, x)` to `ref.is_null(x)`, and `ref.eq(null, null)` to `i32.const 1`. The second OI-I sub-slice [`../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md`](../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md) adds first `ref.as_non_null` basics: `ref.as_non_null(ref.null)` to `unreachable`, `ref.as_non_null(ref.i31(x))` to `ref.i31(x)`, plus exact `ref.cast(unreachable)` validity repair for stacked cast shapes. The third OI-I sub-slice [`../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md`](../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md) adds local known-non-null constructor proofs: `ref.is_null(ref.i31)` and `ref.is_null(ref.func)` fold to `i32.const 0`, null equality against `ref.i31` folds to `i32.const 0`, and the validator now accepts non-null `ref.is_null` operands. The fourth and fifth OI-I slices add `ref.as_non_null(ref.func)` elision and nullable null-operand `ref.test` / `ref.cast` basics; the sixth OI-I slice [`../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md`](../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md) folds exact successful `ref.test (ref i31)` / `ref.cast (ref i31)` forms fed by local `ref.i31` constructors; the seventh widens that local-i31 proof to `eq` and `any` targets; and the eighth [`../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md`](../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md) folds exact successful `ref.test (ref func)` / `ref.cast (ref func)` forms fed by local `ref.func` constructors. The remaining active backlog starts with any further source-backed OI-G load/store work, any further source-backed OI-H known-target shapes, remaining reference/cast/descriptor/null-trap families, GC non-atomic and atomic rewrites, tuple extraction, and final direct/O4z closeout.

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
- [`../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md`](../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md) records the first `[O4Z-AUDIT-OI-G]` byte bulk-memory sub-slice for size-1 `memory.copy` and `memory.fill` plus zero-size trap-mode boundary evidence.
- [`../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md`](../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md) records the first `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: direct `ref.func` targets under `call_ref` and `return_call_ref` now directize to `call` and `return_call`.
- [`../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md`](../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md) records the second `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: `table.get` targets under `call_ref` and `return_call_ref` now lower to `call_indirect` and `return_call_indirect`.
- [`../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md`](../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md) records the third `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: zero-argument typed `select` targets whose arms are direct `ref.func`s now lower to an `if` with direct `call` / `return_call` arms; fallthrough-known and positive argument-bearing select-known-target lowering remained open at that point.
- [`../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md`](../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md) records the fourth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: argument-bearing select-of-`ref.func` targets were an explicit fail-closed boundary until Starshine had Binaryen-style argument localization.
- [`../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md`](../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md) records the fifth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: zero-argument fallthrough-known block targets now lower to a dropped target expression plus direct `call` / `return_call`, preserving target-side effects.
- [`../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md`](../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md) records the sixth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: argument-bearing select-of-`ref.func` targets now localize single-result call arguments before lowering to direct-call `if` arms.
- [`../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md`](../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md) records the seventh `[O4Z-AUDIT-OI-H]` `call_ref` boundary sub-slice: mixed select arms and argument-bearing fallthrough-known targets are intentionally kept unchanged until a broader safe lowering is proven.
- [`../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md`](../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md) records the first `[O4Z-AUDIT-OI-I]` reference-null sub-slice: `ref.is_null(ref.null)` and null-operand `ref.eq` rewrites now cover the local null equality/test basics while broader casts and exactness-sensitive behavior remain open.
- [`../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md`](../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md) records the second `[O4Z-AUDIT-OI-I]` reference sub-slice: first `ref.as_non_null` null/known-`i31` cleanup and exact `ref.cast(unreachable)` validity repair are covered while broader casts, tests, and descriptor/exactness-sensitive behavior remain open.
- [`../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md`](../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md) records the third `[O4Z-AUDIT-OI-I]` reference sub-slice: known-non-null `ref.i31` / `ref.func` null tests and `ref.i31` null equality now fold to `i32.const 0`, with the supporting `ref.is_null` typechecker correction.
- [`../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md`](../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md) records the fourth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.as_non_null(ref.func f)` now reuses the local known-non-null constructor proof and rewrites to `ref.func f` while arbitrary cast/test/type proofs remain open.
- [`../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md`](../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md) records the fifth `[O4Z-AUDIT-OI-I]` reference sub-slice: nullable null-operand `ref.test` folds to `i32.const 1` and nullable null-operand `ref.cast` rewrites to the null child, while public non-null cast/test fixtures remain a validation/type-surface follow-up.
- [`../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md`](../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md) records the sixth `[O4Z-AUDIT-OI-I]` reference sub-slice: exact successful `ref.test (ref i31)` and `ref.cast (ref i31)` forms fed by local `ref.i31` constructors now fold while broader successful cast/test proofs remain open.
- [`../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md`](../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md) records the seventh `[O4Z-AUDIT-OI-I]` reference sub-slice: successful local-`ref.i31` cast/test folds now cover absolute target supertypes `eq` and `any` as well as exact `i31`.
- [`../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md`](../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md) records the eighth `[O4Z-AUDIT-OI-I]` reference sub-slice: exact successful `ref.test (ref func)` and `ref.cast (ref func)` forms fed by local `ref.func` constructors now fold while target supertypes and broader cast/test proofs remain open.
- [`../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md`](../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md) records the ninth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.eq` between immediate `ref.i31(i32.const)` operands now folds to `i32.const 1` for equal payloads and `i32.const 0` for unequal payloads, while broader reference identity proofs remain open.
- [`../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md`](../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md) records the tenth `[O4Z-AUDIT-OI-I]` reference sub-slice: declared non-null `local.get` refs now feed `ref.is_null`, `ref.as_non_null`, and null-equality folds through local type metadata, while nullable-local and broader flow-sensitive proofs remain open.
- [`../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md`](../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md) records the second `[O4Z-AUDIT-OI-G]` sub-slice for constant-value size-2 and size-4 `memory.fill` lowering and nonconstant wider-fill boundary evidence.
- [`../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md`](../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md) records the third `[O4Z-AUDIT-OI-G]` sub-slice for constant-value size-8 `memory.fill` lowering to repeated-byte `i64.store` while keeping nonconstant wider fills open.
- [`../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md`](../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md) records the fourth `[O4Z-AUDIT-OI-G]` sub-slice for local.get value size-2 and size-4 `memory.fill` lowering through low-byte mask and repeat multiply expressions while keeping effectful values and nonconstant size-8 fills open.
- [`../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md`](../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md) records the fifth `[O4Z-AUDIT-OI-G]` sub-slice for local.get value size-8 `memory.fill` lowering through low-byte mask, `i64.extend_i32_u`, and repeated-byte `i64.mul` while keeping effectful values open.
- [`../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md`](../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md) records the sixth `[O4Z-AUDIT-OI-G]` sub-slice for constant-size `2`/`4`/`8` `memory.copy` lowering to exact load/store pairs while preserving overlap and trap safety.
- [`../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md`](../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md) records the seventh `[O4Z-AUDIT-OI-G]` boundary sub-slice for intentionally keeping zero-size, size-16, and nonconstant-size `memory.copy` unchanged without trap-relaxed mode support or overlap-safe multi-store lowering proofs.
- [`../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md`](../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md) records the eighth `[O4Z-AUDIT-OI-G]` sub-slice for direct-core memory64 `memory.copy` fixtures that prove i64 address preservation for size-1 and size-8 exact lowering plus oversized/nonconstant memory64 length boundaries.
- [`../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md`](../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md) records the ninth `[O4Z-AUDIT-OI-G]` sub-slice: validator/typechecker memory64 `memory.fill` length acceptance plus direct-core OI fixtures proving size-1 and size-8 fill lowering preserves `i64` destination operands.
- [`../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md`](../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md) records the tenth `[O4Z-AUDIT-OI-G]` sub-slice: a narrow `optimizeStoredValue` subset that drops redundant `i32.and` masks before `i32.store8` / `i32.store16` when all written low bits are preserved, plus focused value-changing-mask boundaries.
- [`../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md`](../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md) records the eleventh `[O4Z-AUDIT-OI-G]` sub-slice: a Starshine-win generalization that drops redundant `i64.and` masks before `i64.store8` / `i64.store16` / `i64.store32` when all written low bits are preserved, while explicitly documenting that Binaryen `version_130` keeps those exact i64 masks.
- [`../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md`](../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md) records the twelfth `[O4Z-AUDIT-OI-G]` sub-slice: the source-backed `optimizeMemoryAccess` constant-pointer static-offset fold for memory32 loads/stores, plus the Binaryen-style positive-`i32` range boundary.
- [`../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md`](../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md) records the thirteenth `[O4Z-AUDIT-OI-G]` sub-slice: the memory64 extension of constant-pointer static-offset folding for scalar loads/stores, using direct-core fixtures and Binaryen's unsigned `u64` no-wrap boundary.
- [`../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md`](../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md) records the fourteenth `[O4Z-AUDIT-OI-G]` sub-slice: an explicit fail-closed `load-call-optimize-instructions-noop` decision for scalar load constant-offset folding. Binaryen folds the mixed load/call fixture, but Starshine keeps the public pipeline raw gate until a broader safe escape proof exists.
- [`../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md`](../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md) records the fifteenth `[O4Z-AUDIT-OI-G]` sub-slice: redundant narrow-store mask cleanup now accepts the constant mask on either side of the `and`, matching Binaryen for the `i32.store8` / `i32.store16` cases and preserving the documented Starshine-win `i64` generalization.
- [`../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md`](../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md) records the sixteenth `[O4Z-AUDIT-OI-G]` sub-slice: constant stored values are truncated before `i32.store8` / `i32.store16` and `i64.store8` / `i64.store16` / `i64.store32`, matching Binaryen-observable `optimizeStoredValue` behavior for the covered constants.
- [`../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md`](../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md) records the seventeenth `[O4Z-AUDIT-OI-G]` sub-slice: size-1 constant `memory.fill` lowering now canonicalizes oversized values to their low byte before materializing `i32.store8`, matching Binaryen-observable `optimizeMemoryFill` spelling for the covered constants.
- [`../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md`](../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md) records the eighteenth `[O4Z-AUDIT-OI-G]` sub-slice: a source-backed boundary decision that nonconstant pointer-add address forms such as `local.get + const` are not claimed as `optimize-instructions`-owned load/store offset canonicalization under Binaryen `version_130`; Starshine keeps the tested forms unchanged.
