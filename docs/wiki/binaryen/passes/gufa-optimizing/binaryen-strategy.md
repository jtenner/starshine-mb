---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ../gufa/index.md
---

# Binaryen `gufa-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is the shared `src/passes/GUFA.cpp` engine.
- The whole-program analysis helper is `src/ir/possible-contents.h`.
- Public registration comes from `src/passes/pass.cpp`.
- The shipped behavior example for this exact sibling is `test/lit/passes/gufa-optimizing.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

## The pass in one sentence

Binaryen `gufa-optimizing` is plain whole-program GUFA rewriting plus a nested `dce`-then-`vacuum` cleanup rerun on each function the rewrite phase actually changed.

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

- **same proof engine, different post-rewrite cleanup contract**.

## Scheduler fact

This pass is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline.
That means this dossier is a deliberate upstream-only registry expansion.

## What the implementation is really organized around

The durable structure is:

1. build one module-wide `ContentOracle`
2. run the shared GUFA visitor on each function in parallel
3. refinalize if the visitor changed anything
4. repair EH nested pops after real rewrites
5. only if `optimizing` is true, run nested `dce` and `vacuum` on that changed function

That is the real contract.
The sibling is all about step 5.

## Phase 1: the analysis is still plain GUFA analysis

The whole-program oracle is `ContentOracle` in `possible-contents.h`.
It still computes the same possible-content facts the broader `gufa` dossier already explains:

- impossible contents / unreachable
- one literal-like value
- one materializable global or function identity
- a tighter reference-type cone
- too-many-values fallback

`gufa-optimizing` does **not** add any new analysis precision beyond that.

## Phase 2: the rewrite surface is still plain GUFA rewrite surface

The shared visitors in `GUFA.cpp` still do the same narrow family of rewrites:

- generic expression replacement when the oracle can prove one legal value
- replacement with `unreachable` when the oracle proves no possible contents
- `ref.eq` simplification using possible-content intersection
- `ref.test` simplification using type-cone inclusion
- `ref.cast` result-type sharpening

So if someone asks, “what IR shapes does this pass understand?”, the answer starts with plain GUFA's shapes.

## Phase 3: refinalization happens before optimizing cleanup

In `visitFunction`, Binaryen first checks whether the shared rewrite phase changed anything.
If it did, it runs `ReFinalize()`.

That ordering matters.
The nested cleanup passes are not run on stale or partially-invalid IR.
They are run after Binaryen has already repaired function-local typing.

## Phase 4: EH nested-pop repair is part of the real contract

After any real rewrite, Binaryen calls:

- `EHUtils::handleBlockNestedPops(func, *getModule())`

This happens before the optimizing-only nested cleanup branch returns or proceeds.
So the sibling's real contract includes:

- GUFA rewrite
- refinalize
- EH nested-pop repair
- only then `dce` / `vacuum`

That is important for any future port that might otherwise be tempted to run cleanup too early.

## Phase 5: `optimizing` mode owns the nested cleanup rerun

The core difference is a small block in `visitFunction`:

- if `!optimizing`, return
- otherwise make a nested `PassRunner`
- `runner.add("dce")`
- `runner.add("vacuum")`
- `runner.runOnFunction(func)`

That is the exact sibling identity.

## Why Binaryen does this at all

The comments in `GUFA.cpp` explain the motivation clearly.
When GUFA proves a nested expression equals one constant, or that a site is unreachable, it may preserve the old child work by wrapping it in new structure:

- `drop`
- `block`
- repeated constants
- explicit `unreachable`

That is semantically correct, but it can increase code size if left alone.
The optimizing sibling exists to pay off that cleanup debt immediately.

## Positive rewrite family 1: nested block/result wrappers after constant proof

The dedicated `gufa-optimizing.wast` file shows the cleanest example.
A helper call returns `1` through nested result blocks.
Plain `gufa` proves the value but leaves a chain of nested blocks and drops.
The optimizing sibling runs cleanup and reaches a much simpler shape:

- preserve the call for effects as `drop (call $foo)`
- return the inferred constant `i32.const 1`

This is the most beginner-friendly way to understand the sibling.

## Positive rewrite family 2: explicit `unreachable` that exposes dead suffixes

When GUFA proves that no contents can reach a site, it emits `unreachable` while preserving earlier side effects.
That often creates later dead control or dead value traffic.
`dce` is the exact nested pass that removes the newly exposed dead code.

## Positive rewrite family 3: wrapper drops that `vacuum` can peel away

When GUFA preserves an old child for effects but replaces the value itself, extra `drop`s and wrapper blocks can remain.
`vacuum` is the exact nested pass that removes now-unused values and trivial wrappers from those shapes.

## Negative family 1: no `castAll` insertion

Because this sibling keeps `castAll = false`, it does **not** run the “insert fresh casts wherever we know a narrower type” phase from `gufa-cast-all`.
That is a separate public sibling with a separate contract.

## Negative family 2: no broader rewrite surface than plain GUFA

This pass still inherits all the shared GUFA boundaries:

- tuple-typed expressions are skipped
- ordered memory operations are not rewritten
- materializable value replacement still needs type-valid emitted IR
- the pass only emits a narrow replacement family directly

So the optimizing sibling is not “plain GUFA plus more rewrite patterns.”
It is “plain GUFA plus cleanup.”

## Negative family 3: unchanged functions do not rerun cleanup

The nested runner is only created after the function has been marked `optimized`.
That means:

- unchanged functions do not pay the extra cost
- the sibling's runtime cost is tied to actual successful GUFA rewrites

That changed-functions-only scope is part of the real implementation behavior.

## Important helper dependencies

The most important helper dependencies are:

- `ContentOracle` / `PossibleContents` in `possible-contents.h`
- `ReFinalize`
- `EHUtils::handleBlockNestedPops`
- nested `PassRunner`
- `dce`
- `vacuum`

This pass is therefore best understood as a **whole-program analysis pass that intentionally hands off to two local cleanup passes**, not as a standalone monolithic transformer.

## What a future Starshine port must preserve

A correct port should preserve eight boundaries:

1. the same whole-program `ContentOracle` analysis as plain `gufa`
2. the same narrow direct rewrite surface as plain `gufa`
3. function-level `optimized` tracking
4. `ReFinalize()` before nested cleanup
5. EH nested-pop repair before nested cleanup
6. nested cleanup with exactly `dce` then `vacuum`
7. changed-functions-only reruns
8. the explicit split from `gufa-cast-all`

## Most important beginner correction

If someone says:

- “`gufa-optimizing` is just the aggressive form of GUFA”

that is not quite wrong, but it is much too blurry.

A much better sentence is:

- “`gufa-optimizing` is the public GUFA sibling that runs `dce` and `vacuum` immediately on functions whose GUFA rewrite phase changed them.”

That is the main durable teaching value of this dossier.
