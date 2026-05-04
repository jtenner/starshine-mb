---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/research/0432-2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md
  - ../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# `gufa-cast-all` implementation structure and tests

## Upstream source rule

Use Binaryen `version_129` as the main source oracle for this page, anchored by the 2026-04-24 raw manifest:

- [`../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md)

## File map

| File | Why it matters for this exact pass |
| --- | --- |
| `src/passes/GUFA.cpp` | Defines the shared pass engine, the exact `castAll` branch in `visitFunction`, the `addNewCasts(func)` walk, the second refinalization after inserted casts, and the public `createGUFACastAllPass()` factory. |
| `src/passes/pass.cpp` | Registers the public pass name `gufa-cast-all` and its one-line public description. |
| `src/ir/possible-contents.h` | Defines `ContentOracle`, the whole-program lattice/oracle the sibling still depends on. |
| `test/lit/passes/gufa-cast-all.wast` | Dedicated proof that this sibling owns a real cast-insertion contract rather than being a cosmetic alias. |
| `test/lit/passes/gufa.wast` | Baseline comparison surface for what plain GUFA already rewrites before the cast-all difference. |
| `test/lit/passes/gufa-optimizing.wast` | Helpful contrast file proving that the other public sibling changes cleanup scheduling instead of cast insertion. |

## Public registration

`pass.cpp` exposes:

- `gufa`,
- `gufa-cast-all`,
- `gufa-optimizing`.

That registration fact alone is important:

- `gufa-cast-all` is a real public surface,
- it is not a hidden tuning flag.

## Shared-engine construction

The bottom of `GUFA.cpp` exposes three factories:

- `createGUFAPass()` => `new GUFAPass(false, false)`,
- `createGUFAOptimizingPass()` => `new GUFAPass(true, false)`,
- `createGUFACastAllPass()` => `new GUFAPass(false, true)`.

This is the simplest exact source proof that `gufa-cast-all` is a shared-engine variant, not a separate implementation file.

## Where the exact sibling behavior lives

The important pieces are split across a few small source regions.

### 1. Shared visitor and family state in `GUFA.cpp`

The shared visitor stores:

- `ContentOracle& oracle`,
- `bool optimizing`,
- `bool castAll`,
- function-level change state.

For this sibling, the key flags are:

- `optimizing = false`,
- `castAll = true`.

### 2. `visitFunction(Function* func)`

This is the central source region for the sibling. It performs, in order:

1. `ReFinalize()` if the common GUFA phase changed anything,
2. optionally `addNewCasts(func)` if `castAll`,
3. `EHUtils::handleBlockNestedPops(...)` after any real rewrite,
4. optionally run nested `dce` and `vacuum` if `optimizing`.

For `gufa-cast-all`, step 2 is the sibling identity and step 4 is intentionally skipped.

### 3. `addNewCasts(Function* func)`

This is the pass-specific materialization walk. The reviewed source shows this rough proof chain:

1. bail out unless GC is enabled,
2. postwalk each expression,
3. skip expressions whose static type is not castable,
4. get the oracle's possible-content type for the expression,
5. skip when that type is not a reference type,
6. downgrade exactness if custom descriptors are unavailable,
7. skip if the target type is unchanged,
8. require the target type to be a subtype of the current type,
9. replace the expression with `Builder::makeRefCast(...)`,
10. run `ReFinalize` again if any casts were inserted.

This keeps the sibling narrow: it materializes safe cast targets; it does not perform new whole-program inference.

### 4. `possible-contents.h`

This file matters because it confirms that the sibling does **not** have a separate inference engine. The same `PossibleContents` / `ContentOracle` machinery is used across the family.

### 5. `gufa-cast-all.wast`

This is the dedicated public behavior surface. Without it, it would be too easy to collapse the sibling into a footnote inside `gufa`.

## What `possible-contents.h` contributes here

`gufa-cast-all` does not get new cast-specific analysis. It still relies on the same `ContentOracle` result families as plain `gufa`:

- impossible contents,
- literal-like contents,
- global/function identity,
- cone/reference-type contents,
- many/unknown fallback.

That means the sibling split is **not** in the analysis file. It is in the post-rewrite phase in `GUFA.cpp`.

## What the dedicated lit file proves

## `gufa-cast-all.wast`

This file is the strongest direct proof that the sibling has its own public contract. It exercises the exact families a beginner might otherwise lose:

- adding new casts where plain GUFA would stop,
- exact cast targets for struct and function reference locals,
- value-replacement cases where no extra cast is useful,
- unreachable preservation cases,
- imported/exported tag cases that stay conservative.

### What this proves about the pass

The file proves at least five durable facts:

1. `gufa-cast-all` is not just “plain GUFA, maybe with better cleanup.”
2. the sibling's visible effect is new cast insertion,
3. exactness is still constrained by feature/legality rules,
4. some candidate expressions remain intentionally unchanged,
5. EH/tag conservatism still comes from the shared oracle boundary.

## Why `gufa.wast` still matters

The dedicated cast-all file is small on purpose. To understand what the sibling is building on, you still need the broader plain-GUFA surface in `gufa.wast`:

- constant propagation through calls/locals/globals,
- unreachable proofs,
- `ref.eq` intersection reasoning,
- `ref.test` cone reasoning,
- existing `ref.cast` refinement.

So the exact implementation story is:

- `gufa.wast` teaches what the shared engine can prove and rewrite directly,
- `gufa-cast-all.wast` teaches what this sibling does **after** those proofs become rewrites.

## Why `gufa-optimizing.wast` is still relevant

That other sibling file makes the contrast sharper. It proves that the alternate public variant changes cleanup scheduling instead of cast insertion.

That is useful because a reader could otherwise wrongly assume the two siblings are just different “aggressiveness” modes. They are not. They change different phases.

## Current-main spot check

For this dossier, the following public surfaces were rechecked as freshness guards on 2026-05-04:

- `src/passes/pass.cpp`
- `src/passes/GUFA.cpp`
- `test/lit/passes/gufa-cast-all.wast`

On the reviewed surfaces, current `main` still matched the `version_129` behavior this dossier teaches closely enough that the tagged release remains a stable oracle for the sibling. That is a reviewed-surface inference, not a full-file identity proof.

## Porting checklist this page suggests

Before calling a future port “done,” verify that it preserves:

- the exact public pass name,
- the shared analysis and first rewrite engine with plain `gufa`,
- the `castAll` gate as the sibling identity,
- refinalization before new-cast insertion,
- feature-sensitive exactness behavior,
- trapping semantics of inserted casts,
- EH nested-pop repair after real rewrites,
- the deliberate absence of nested `dce` + `vacuum`,
- the explicit split from both `gufa` and `gufa-optimizing`.
