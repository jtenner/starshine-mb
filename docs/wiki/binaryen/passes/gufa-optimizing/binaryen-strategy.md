---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md
  - ../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
---

# Binaryen `gufa-optimizing` strategy

## Upstream source rule

Use Binaryen `version_129` as the stable source oracle for this pass. The 2026-04-24 raw manifest at [`../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md) captures the exact sources reviewed and the current-`main` freshness check.

Primary online sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

## The pass in one sentence

Binaryen `gufa-optimizing` is plain whole-program GUFA rewriting plus a nested `dce`-then-`vacuum` cleanup rerun on each function the rewrite phase actually changed.

## The sibling split

| Variant | Shared-engine flags | What changes | Why it exists |
| --- | --- | --- | --- |
| `gufa` | `optimizing = false`, `castAll = false` | only oracle-driven rewrites | base behavior |
| `gufa-optimizing` | `optimizing = true`, `castAll = false` | same rewrites, then nested cleanup on changed functions | harvest dead/unreachable/drop scaffolding GUFA introduces |
| `gufa-cast-all` | `optimizing = false`, `castAll = true` | same rewrites, then insert new explicit casts | expose more downstream type information |

The important correction is that `gufa-optimizing` is **not** GUFA with a stronger oracle. It is the same proof engine plus a different post-rewrite cleanup contract.

## Source-level organization

The durable sequence in `GUFA.cpp` is:

1. build one module-wide `ContentOracle`;
2. run the shared GUFA visitor over each function;
3. if the function changed, run `ReFinalize()`;
4. if `castAll` is enabled, optionally insert new casts;
5. if the function did not change, return;
6. repair EH nested pops;
7. if `optimizing` is enabled, run a nested pass runner with `dce` then `vacuum` on that function.

For this exact sibling, `castAll` is false and `optimizing` is true, so steps 6 and 7 are the public distinction.

## Shared analysis phase

The analysis is still plain GUFA analysis. `ContentOracle` / `PossibleContents` can prove facts such as:

- no possible runtime contents,
- one literal-like value,
- one materializable global or function identity,
- a tighter reference-type cone,
- too many values to rewrite safely.

`gufa-optimizing` does not add cleanup-specific facts to the oracle.

## Shared rewrite phase

The inherited rewrite surface is the plain GUFA surface:

- replace a site with a materializable known value when doing so preserves typing and effects;
- replace impossible sites with `unreachable` while preserving needed side effects;
- simplify `ref.eq` when possible-content sets cannot intersect;
- simplify `ref.test` from type-cone knowledge;
- refine existing `ref.cast` results when the oracle has sharper type information.

So if someone asks what instruction shapes this pass transforms, start with [`../gufa/index.md`](../gufa/index.md) and then add this sibling's cleanup stage.

## Optimizing-only cleanup phase

The actual sibling identity is the nested cleanup branch:

- it runs only after the function has changed;
- it runs after refinalization;
- it runs after EH nested-pop repair;
- it adds `dce` first and `vacuum` second;
- it runs on the changed function, not the entire module indiscriminately.

That order matters because GUFA can create type-sensitive wrapper residue. Cleanup sees refinalized IR rather than a stale partially-rewritten function.

## Why Binaryen does this

GUFA must preserve side effects while replacing values. That proof-first strategy can leave behind:

- `drop` wrappers,
- extra `block` wrappers,
- dead suffixes after new `unreachable`,
- known constants surrounded by old value scaffolding.

`dce` harvests newly exposed deadness. `vacuum` trims trivial value and wrapper residue. The dedicated `gufa-optimizing.wast` file proves this distinction by comparing plain `gufa` residue against the cleaned optimizing output.

## Boundaries and non-goals

`gufa-optimizing` does **not**:

- widen the core rewrite surface beyond plain GUFA;
- run cleanup on unchanged functions;
- insert the fresh casts owned by `gufa-cast-all`;
- become a generic local cleanup preset;
- appear in the reviewed Starshine no-DWARF `-O` / `-Os` path.

## What a future Starshine port must preserve

A correct port should preserve these source-backed boundaries:

1. the shared whole-program GUFA oracle;
2. the same first-phase rewrites as plain `gufa`;
3. per-function mutation tracking;
4. refinalization or equivalent validation before cleanup;
5. EH / control-stack repair before cleanup;
6. nested cleanup in the order `dead-code-elimination` then `vacuum`;
7. cleanup only on changed functions;
8. no fresh-cast insertion in this sibling.

## Beginner correction

If someone says “`gufa-optimizing` is just aggressive GUFA,” replace it with:

> `gufa-optimizing` is the public GUFA sibling that runs `dce` and `vacuum` immediately on functions whose GUFA rewrite phase changed them.
