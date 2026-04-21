---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# Binaryen `gufa-cast-all` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is the shared `src/passes/GUFA.cpp` engine.
- The whole-program analysis helper is `src/ir/possible-contents.h`.
- Public registration comes from `src/passes/pass.cpp`.
- The shipped behavior example for this exact sibling is `test/lit/passes/gufa-cast-all.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>

## The pass in one sentence

Binaryen `gufa-cast-all` is plain whole-program GUFA rewriting plus a post-refinalize walk that inserts fresh `ref.cast` nodes where the oracle knows a narrower castable reference type.

## The sibling split in one table

| Variant | Flags in shared engine | What changes | Why it exists |
| --- | --- | --- | --- |
| `gufa` | `optimizing = false`, `castAll = false` | only the oracle-driven rewrites | base behavior |
| `gufa-optimizing` | `optimizing = true`, `castAll = false` | same rewrites, then nested cleanup on changed functions | harvest dead/unreachable/drop scaffolding GUFA introduces |
| `gufa-cast-all` | `optimizing = false`, `castAll = true` | same rewrites, then insert new explicit casts | expose more downstream type information |

## Biggest naming fact

The easiest beginner mistake is reading this sibling as:

- “GUFA, but stronger.”

That is too vague to be useful.

A better model is:

- **same proof engine, different post-rewrite cast-materialization contract**.

## Scheduler fact

This pass is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline.
That means this dossier is a deliberate upstream-only registry expansion.

## What the implementation is really organized around

The durable structure is:

1. build one module-wide `ContentOracle`
2. run the shared GUFA visitor on each function in parallel
3. refinalize if the visitor changed anything
4. if `castAll`, run `addNewCasts(func)`
5. repair EH nested pops after real rewrites
6. only if `optimizing` is true, run nested `dce` and `vacuum`

For `gufa-cast-all`, the identity is all about step 4.

## Phase 1: the analysis is still plain GUFA analysis

The whole-program oracle is `ContentOracle` in `possible-contents.h`.
It still computes the same possible-content facts the broader `gufa` dossier already explains:

- impossible contents / unreachable
- one literal-like value
- one materializable global or function identity
- a tighter reference-type cone
- too-many-values fallback

`gufa-cast-all` does **not** add any new analysis precision beyond that.

## Phase 2: the first rewrite surface is still plain GUFA rewrite surface

The shared visitors in `GUFA.cpp` still do the same narrow family of rewrites first:

- generic expression replacement when the oracle can prove one legal value
- replacement with `unreachable` when the oracle proves no possible contents
- `ref.eq` simplification using possible-content intersection
- `ref.test` simplification using type-cone inclusion
- existing `ref.cast` result-type sharpening

So if someone asks, “what IR shapes does this pass understand before the sibling-specific step?”, the answer starts with plain GUFA's shapes.

## Phase 3: refinalization happens before cast insertion

In `visitFunction`, Binaryen first checks whether the shared rewrite phase changed anything.
If it did, it runs `ReFinalize()`.

That ordering matters.
The new-cast insertion walk is not run on stale or partially-invalid IR.
It runs only after Binaryen has already repaired function-local typing after the common GUFA rewrites.

## Phase 4: `castAll` mode owns the new-cast insertion walk

The core difference is a small branch in `visitFunction`:

- if `castAll`, call `addNewCasts(func)`
- if `optimizing`, later run nested cleanup

This sibling is therefore not about cleanup.
It is about **making already-proved type information explicit**.

## Why Binaryen does this at all

The shared oracle can know more than the direct replacement surface can emit.
For example, Binaryen may know that some expression is always in a narrower subtype cone, but plain GUFA may not have a direct exact-value replacement for it.
`gufa-cast-all` exists to turn some of that latent type knowledge into explicit IR via `ref.cast`.

## Phase 5: exactness is feature-sensitive

This is one of the easiest parts to misunderstand.
The reviewed family sources and lit file show that exact refinement is **not** unconditional.
When descriptor/custom-descriptor support is unavailable, Binaryen may need to downgrade an exact inferred type to a non-exact cast target.

So the pass is not:

- “emit the most precise mathematically possible cast.”

It is:

- “emit the most precise valid cast this module's feature surface can actually represent.”

## Phase 6: EH nested-pop repair is still part of the real contract

After any real rewrite, Binaryen still calls:

- `EHUtils::handleBlockNestedPops(func, *getModule())`

This happens for this sibling too.
So the public contract still includes:

- GUFA rewrite
- refinalize
- optional cast insertion
- EH nested-pop repair

and only then an early return because `optimizing` is false.

## Positive rewrite family 1: a new cast is inserted where plain GUFA would stop

The dedicated `gufa-cast-all.wast` file shows the cleanest example family.
A value has a broad static type, but the oracle can prove it actually lives in a narrower cone.
Plain `gufa` may leave that value alone.
`gufa-cast-all` can instead make the fact explicit with a new `ref.cast`.

This is the most beginner-friendly way to understand the sibling.

## Positive rewrite family 2: existing-cast refinement and new-cast insertion are distinct

The shared visitor can already sharpen an existing `ref.cast` based on proven contents.
The cast-all sibling adds a second source-backed family:

- insert a brand-new cast where there was no cast before.

That distinction is important for teaching because otherwise readers can blur all cast-related rewrites into one vague bucket.

## Positive rewrite family 3: downstream GC/cast opportunities become visible

The extra casts are not just cosmetic.
They expose sharper reference types to later passes and to readers of the IR.
That is the practical reason Binaryen publishes this as a separate public sibling.

## Negative family 1: no `dce` / `vacuum` rerun

Because this sibling keeps `optimizing = false`, it does **not** run the changed-functions-only nested `dce` and `vacuum` pass runner from `gufa-optimizing`.
That is a separate public sibling with a separate contract.

## Negative family 2: no broader inference than plain GUFA

This pass still inherits all the shared GUFA boundaries:

- the same `ContentOracle`
- the same value/cone proof space
- the same common-rewrite conservatism before cast insertion

So the cast-all sibling is not “plain GUFA plus more proof power.”
It is “plain GUFA plus more explicit cast materialization.”

## Negative family 3: no arbitrary cast insertion everywhere the oracle knows more

The insertion step is filtered by castability, legality, exactness support, and emitability.
That is why the dedicated lit file includes preserved cases.
Those no-op cases are part of the contract, not test clutter.

## Important helper dependencies

The most important helper dependencies are:

- `ContentOracle` / `PossibleContents` in `possible-contents.h`
- the shared GUFA visitor logic in `GUFA.cpp`
- `ReFinalize`
- `EHUtils::handleBlockNestedPops`
- the sibling-specific `addNewCasts(func)` walk

This pass is therefore best understood as a **whole-program analysis pass that intentionally hands off to a second type-materialization walk**, not as a standalone cast peephole.

## What a future Starshine port must preserve

A correct port should preserve eight boundaries:

1. the same whole-program `ContentOracle` analysis as plain `gufa`
2. the same narrow direct rewrite surface as plain `gufa`
3. function-level change tracking
4. `ReFinalize()` before the cast-insertion walk
5. feature-sensitive exactness downgrades
6. EH nested-pop repair after real rewrites
7. no nested `dce` + `vacuum` rerun here
8. the explicit split from both plain `gufa` and `gufa-optimizing`

## Most important beginner correction

If someone says:

- “`gufa-cast-all` is just the aggressive form of GUFA”

that is not quite wrong, but it is much too blurry.

A much better sentence is:

- “`gufa-cast-all` is the public GUFA sibling that inserts new explicit `ref.cast` nodes after the shared rewrite phase when the oracle knows a narrower castable reference type.”

That is the main durable teaching value of this dossier.
