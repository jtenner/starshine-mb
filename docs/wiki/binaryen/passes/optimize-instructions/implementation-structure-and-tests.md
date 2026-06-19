---
kind: concept
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `optimize-instructions`: implementation structure and tests

This page is the compact source-confirmed map for Binaryen `optimize-instructions`. Most explanatory prose still comes from the reviewed `version_129` dossier, but the release-gating O4z owner map is now the 2026-06-19 `version_130` source/lit matrix in [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md).

Its main job is to answer two practical questions:

1. which upstream files really own the pass contract?
2. which shipped tests prove that contract, and which surfaces are only helper dependencies or neighboring evidence?

## Main owner files

## `src/passes/OptimizeInstructions.cpp`

This is the core owner file.

It contains the visible pass shell and almost all of the directly user-visible rewrite families:

- the `LocalScanner` prescan for `maxBits` and `signExtBits`
- the main function-parallel postwalk
- the local rewrite fixpoint through repeated `replaceCurrent()`-style re-optimization
- compare and commutative canonicalization
- integer and float peepholes
- boolean and ternary-shell cleanup
- memory and bulk-memory simplification
- `call_ref` directization and related rewrites
- GC cast/null-trap/default-constructor logic
- tuple extraction cleanup
- deferred `ReFinalize`, final cleanup, and EH-pop repair

For this dossier, the most important practical lesson is that the pass name undersells the file.
`OptimizeInstructions.cpp` is not a tiny arithmetic peephole file.
It is the actual owner of a broad mid/late function canonicalization surface.

## Registration and scheduler owner files

### `src/passes/pass.cpp`

This file matters because it proves three public-facing facts:

- `optimize-instructions` is a real public pass name
- the short public description is still "optimizes instruction combinations"
- the default and shrink pipelines schedule it in the ordinary function-optimization stack

That registration context is part of the pass contract because the same file also shows why the pass often appears more than once in real optimize runs.

### `src/passes/passes.h`

This file matters because it proves the pass is part of Binaryen's stable public pass roster, not only an internal helper or one-off nested optimization step.

### `src/passes/opt-utils.h`

This file does not own the rewrite algorithm itself.
It still matters because nested cleanup helpers such as `optimizeAfterInlining(...)` can rerun the ordinary function-optimization stack after boundary rewrites.

So `opt-utils.h` is not a semantic-pattern owner, but it is an important owner of the pass's nested rerun story.

## Main helper-semantics owner files

`OptimizeInstructions.cpp` depends on several helper headers whose semantics are part of the real contract.
The most important ones for beginners are:

- `src/ir/bits.h`
  - bit-width proofs, constant-range facts, and other "value fits in fewer bits" reasoning
- `src/ir/properties.h`
  - fallthrough/value-shape classification and sign-extension recognition used by the local prescan and many peepholes
- `src/ir/effects.h`
  - effect-order and side-effect safety checks that block unsafe shell folding or value reordering
- `src/ir/gc-type-utils.h`
  - cast-check classification and reference-type reasoning for the GC half of the pass
- `src/ir/localize.h`
  - child localization helpers used when direct rewrites would otherwise duplicate or reorder effects unsafely
- `src/ir/type-updating.h`
  - type repair and refinalization support after reference-typed rewrites
- `src/passes/call-utils.h`
  - direct-call and related call-target helper logic for the `call_ref` family
- `src/ir/branch-hints.h`
  - branch-hint flipping when `eqz` inversion swaps `if` arms
- `src/ir/drop.h`
  - explicit dropped-value preservation when trap-relaxing rewrites delete or replace effectful shells
- `src/ir/eh-utils.h`
  - final nested-pop repair after the main walk
- `src/ir/literal-utils.h`
  - literal-specific float and constant helper semantics used by parts of the arithmetic cleanup
- `src/ir/load-utils.h`
  - memory/load helper semantics used by the load/store cleanup surface
- `src/ir/manipulation.h`
  - structural helper support used by some of the larger rewrites

## Owner split in one table

| File | Ownership role | What it contributes |
| --- | --- | --- |
| `src/passes/OptimizeInstructions.cpp` | core owner | Pass shell, local prescan, canonicalization, peepholes, memory/GC/`call_ref` rewrites, final repair hooks |
| `src/passes/pass.cpp` | public registration and top-level scheduler placement | CLI-visible pass name and ordinary pipeline exposure |
| `src/passes/passes.h` | public pass roster | Confirms the pass is part of the visible pass family |
| `src/passes/opt-utils.h` | nested rerun context | Explains why the pass can reappear after boundary rewrites |
| `src/ir/bits.h`, `properties.h`, `effects.h`, `gc-type-utils.h`, `localize.h`, `type-updating.h`, `call-utils.h`, `branch-hints.h`, `drop.h`, `eh-utils.h`, `literal-utils.h`, `load-utils.h`, `manipulation.h` | helper semantics | The real legality/proof substrate the rewrite families depend on |

## What the owner map says about implementation complexity

Compared with tiny one-file Binaryen passes, `optimize-instructions` has a broad helper footprint.
That footprint is part of the reason future Starshine parity work cannot be reduced to "just copy a few arithmetic identities."

A useful mental model is:

- `OptimizeInstructions.cpp` owns the visible rewrites
- the helper headers own the legality proofs and repair mechanisms that make many of those rewrites safe

## Shipped proof surface

The pass's real proof surface is distributed across several dedicated lit files, not one single oracle.

## Representative dedicated lit files

### `test/lit/passes/optimize-instructions-default.wast`

This is the broad default proof surface for ordinary arithmetic, compare, and control-shape cleanup.
Use it as the first place to look for the "plain" non-GC, non-bulk-memory, non-`call_ref` contract.

### `test/lit/passes/optimize-instructions-sign_ext.wast`

This file proves the sign-extension and narrow-width cleanup families that are easy to blur together with neighboring passes.
It matters because the `LocalScanner` and bit/sign-extension helpers are core to the pass, not optional extras.

### `test/lit/passes/optimize-instructions-bulk-memory.wast`

This file proves that the pass really does own part of Binaryen's tiny `memory.copy` / `memory.fill` simplification surface.
That is one of the clearest rebuttals to the mistaken "math-only peephole pass" mental model.

### `test/lit/passes/optimize-instructions-call_ref.wast`

This file proves the direct-call and call-target-shape cleanup families behind the pass's `call_ref` story.

### `test/lit/passes/optimize-instructions-gc.wast`

This is the broad GC/reference-typed proof surface.
It matters because a large fraction of the file's real complexity lives in cast, null-trap, constructor-default, and reference-type rewrites.

### `test/lit/passes/optimize-instructions-gc-tnh.wast`

This file proves the trap-relaxed TNH-specific variant of the GC cleanup surface.
It matters because several cast and bulk-memory rewrites are only valid under relaxed trap assumptions.

### `test/lit/passes/optimize-instructions-multivalue.wast`

This file proves the multivalue and tuple-related cleanup families, including the part of the pass that reaches into tuple extraction.

### `test/lit/passes/optimize-instructions_branch-hints-fold.wast`

This file proves the branch-hint-aware arm-flip surface and helps keep the `eqz`/arm-swap behavior tied to an actual shipped test rather than only a source-reading claim.

## Test split in one table

| Test file | Why it matters | What it most directly proves |
| --- | --- | --- |
| `optimize-instructions-default.wast` | default arithmetic/control surface | canonical compare, boolean, and ordinary peepholes |
| `optimize-instructions-sign_ext.wast` | sign/zero-extension and width-sensitive surface | prescan-enabled sign-extension and narrow-width rewrites |
| `optimize-instructions-bulk-memory.wast` | memory/bulk-memory boundary | tiny `memory.copy` / `memory.fill` lowering and trap-sensitive guards |
| `optimize-instructions-call_ref.wast` | call-target cleanup surface | `call_ref` directization and related rewrites |
| `optimize-instructions-gc.wast` | GC/reference surface | casts, null checks, constructor/default rewrites, descriptor/exactness-sensitive cases |
| `optimize-instructions-gc-tnh.wast` | relaxed-trap GC boundary | TNH-only cast and trap-sensitive rewrites |
| `optimize-instructions-multivalue.wast` | multivalue surface | tuple and multivalue-specific cleanup |
| `optimize-instructions_branch-hints-fold.wast` | arm-flip proof | `eqz`-driven `if` inversion with branch-hint preservation |

## What this means for beginners

A beginner often expects one lit file per pass and one source file per pass.
`optimize-instructions` is a good counterexample.

The better mental model is:

- one core owner file
- many helper files whose semantics are part of correctness
- several dedicated lit files, each proving a different major sub-surface

That structure matches the real breadth of the pass.

## Version_130 O4z source/lit matrix

`[O4Z-AUDIT-OI-A]` is complete as of 2026-06-19. The new matrix in [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md):

- re-anchors `OptimizeInstructions.cpp`, `pass.cpp`, `passes.h`, `opt-utils.h`, and the helper headers at `version_130`;
- keeps the dedicated `optimize-instructions*` lit roster explicit;
- maps each upstream visitor/helper family to current Starshine coverage, an explicit local boundary, or an `[O4Z-AUDIT-OI-*]` implementation owner;
- records that current Starshine remains a useful HOT subset, not full upstream OI parity.

The older 2026-05-05 current-main note is still useful historical provenance, but new release-gating OI work should start from the 2026-06-19 `version_130` matrix.

## Porting takeaway

If Starshine ever needs a stricter source-level expansion of this pass, this page suggests a compact checklist:

1. preserve the core pass shell and local prescan from `OptimizeInstructions.cpp`
2. preserve the helper semantics that make the rewrites legal, not only the surface patterns
3. keep the distributed lit proof surface explicit instead of teaching the pass from one file
4. use the `[O4Z-AUDIT-OI-A]` matrix to route work to the current slice owner instead of treating broad missing families as closed
5. remember that `call_ref`, memory, bulk-memory, GC casts, tuple extraction, and final repair are part of the real contract, not optional side stories
