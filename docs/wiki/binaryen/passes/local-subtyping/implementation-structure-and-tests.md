---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_core.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# `local-subtyping`: implementation structure and tests

This page is the source-map companion for the `local-subtyping` dossier. It explains which upstream files own the pass, which official tests prove the contract, and which exact Starshine files currently represent the unimplemented local status and future landing zone.

## Correction status

Use [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md) as the strongest source for this page.

It partially supersedes the 2026-04-22 dossier wording. The older correction was right to reject a generic `LocalUpdater` / copy-local-insertion story, but wrong to say the owner file has no `local.get` surface, no iterative `ReFinalize()`, and no parameter scan surface.

The 2026-05-05 current-main recheck keeps that correction intact and adds a fresh provenance bridge.

The reviewed owner/test surface remains the same: no teaching-relevant drift on the current-main path.

## Upstream owner map

| File | Role |
| --- | --- |
| `src/passes/LocalSubtyping.cpp` | Owner file. Defines the public pass, GC gate, relevant-local scanner, set-fed LUB analysis, get-aware dominance and retagging, declaration rewrite, iterative refinalization loop, and changed/unchanged result. |
| `src/passes/passes.h` | Declares the pass constructor in the public pass set. |
| `src/passes/pass.cpp` | Registers the pass name and places it before `coalesce-locals` in the GC/local cleanup neighborhood. |
| `src/passes/opt-utils.h` | Shows where the default function optimization helper can rerun the local-cleanup neighborhood after inlining-style rewrites. |
| `src/ir/lubs.h` and `src/ir/lubs.cpp` | Provide the `LUBFinder` used to compute one common target type from the values assigned to a local. |
| `src/ir/local-structural-dominance.h` | Provides the non-null dominance proof and non-dominating-get list used to decide whether gets may take the non-null declaration type. |
| `test/lit/passes/local-subtyping.wast` | Dedicated official proof surface for narrowing, non-null dominance, loops, tees, repeated refinement, named-type LUBs, parameter preservation, tuple/nondefaultable preservation, and local-cleanup interactions. |

## Owner-file phase map

A faithful read-along of `LocalSubtyping.cpp` should follow these phases:

1. **Pass shell and GC gate**
   - The pass is function-parallel.
   - It exits unchanged when GC is disabled.
2. **Relevant-local scan**
   - A local becomes relevant when its current type is a reference type.
   - The source currently has a TODO to ignore parameters during scanning, so scanning and rewriting are not identical scopes.
3. **Set/get collection**
   - `local.set` and `local.tee` sites feed assigned-value evidence.
   - `local.get` sites are recorded for dominance and type repair.
4. **Iterative refinalization**
   - After the first round, the pass refinalizes before rescanning, because one local declaration change can sharpen later assigned values.
5. **LUB candidate selection**
   - The candidate type for a local comes from the LUB of recorded set/tee value types.
   - Gets do not directly choose the LUB.
6. **Non-null dominance and defaultability gate**
   - Nondefaultable candidates are only kept when they are non-null references and every relevant get is dominated.
   - Otherwise Binaryen falls back to the nullable version.
7. **Body-local declaration rewrite**
   - The rewrite loop starts at `getVarIndexBase()`, so parameters are not rewritten even if they were recorded by the scanner.
8. **Get/tee type repair**
   - Safe `local.get` sites take the new declaration type.
   - Non-dominated gets keep the older nullable type when needed.
   - `local.tee` expression types are retagged from the rewritten declaration.
9. **Repeat until stable**
   - The pass repeats until no further declaration changes appear.

## Official lit-test map

The dedicated `local-subtyping.wast` file is unusually important here because it prevents multiple plausible overreads.

| Test family | What it proves |
| --- | --- |
| Basic narrowing | Body locals declared with a wider reference type can be narrowed when all assigned values share a narrower type. |
| Named-type and sibling cases | The pass chooses a LUB/common parent, not a random leaf subtype. |
| `local.tee` cases | Tee sites contribute assigned-value evidence and their expression type must be repaired after declaration narrowing. |
| Non-null cases | Nullable-to-non-null refinement requires dominance over relevant gets. |
| Loop and control cases | Textual order is not enough; structural dominance over control flow is part of the contract. |
| Repeated refinement | Iterative refinalization can expose a second narrowing round. |
| Parameter cases | Parameters remain unchanged by the declaration rewrite. |
| Nondefaultable/tuple cases | Unsupported local shapes are preserved rather than forced through the reference-local rewrite. |
| Neighborhood combos | `optimize-casts`, `coalesce-locals`, and `local-cse` tests show why the scheduler cluster matters. |

## Current Starshine code map

Starshine still has no implementation file or dispatcher case for `local-subtyping`.

Current exact status and prerequisite surfaces:

- `src/passes/optimize.mbt:144-151`
  - `pass_registry_removed_names()` includes `"local-subtyping"`.
- `src/passes/pass_manager.mbt:8688-8704`
  - active hot-pass dispatch has no `local-subtyping` case.
- `src/passes/optimize_test.mbt:390-395`
  - preset-honesty regression keeps `reorder-locals` out of `optimize` / `shrink` until neighboring local passes land.
- `agent-todo.md:372-383`
  - `LS` backlog slice for the future port.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33`
  - canonical neighborhood: `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`.
- `src/lib/types.mbt:55-65`
  - `RefType` and `ValType` surfaces that model reference-local types.
- `src/lib/types.mbt:230-238`
  - grouped `Locals` declaration storage.
- `src/lib/types.mbt:416-420`
  - function body stores `Locals` plus expression.
- `src/lib/types.mbt:536-538`
  - `LocalGet`, `LocalSet`, and `LocalTee` instruction constructors.
- `src/validate/typecheck.mbt:535-558`
  - local get/set/tee validation reads from the current local declaration type.
- `src/ir/hot_core.mbt:150-178`
  - HOT local metadata separates params and locals, which matters if a future implementation is HOT-aware.

## Validation guidance for a future Starshine port

A source-faithful port should add tests in this order:

1. body-local reference narrowing from set/tee values
2. LUB/common-parent cases
3. tee retagging
4. repeated refinement requiring a refinalize-like repair pass
5. nullable-to-non-null positives and dominance failures
6. parameter preservation
7. non-reference and tuple/nondefaultable preservation
8. ordered neighborhood tests with `optimize-casts`, `coalesce-locals`, and `local-cse`

Do not claim parity from a declaration-only rewrite unless local get/tee expression typing, non-dominated nullable gets, and repeated refinement are covered too.

## Sources

- [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- Binaryen `version_129` owner: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
