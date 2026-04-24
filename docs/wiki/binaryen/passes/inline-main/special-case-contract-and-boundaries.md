---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md
  - ../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../inlining/index.md
  - ../monomorphize/index.md
---

# `inline-main` special-case contract and boundaries

The source-backed contract here is anchored by the 2026-04-24 raw manifest [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md) plus the Starshine status page [`./starshine-strategy.md`](./starshine-strategy.md).

## The teaching problem

The hardest part of documenting `inline-main` is that the pass is simultaneously:

- much smaller than plain `inlining`, and
- more substantial than its tiny chooser suggests

The chooser is tiny because the accepted shape is tiny.
The rewrite is substantial because the pass reuses ordinary inline-body machinery.

This page focuses on that split.

## What makes `inline-main` its own pass

The pass is public and separately named in upstream `pass.cpp`.
That already tells us it is not just a hidden convenience mode.

But the deeper reason it deserves a separate identity is its **selection rule**.

Plain `inlining` asks:

- which functions are profitable to inline?
- which callsites are legal?
- which actions should be chosen from many candidates?

`inline-main` asks only:

- do we have the exact `main` / `__original_main` wrapper shape?

That is a totally different front half.

## The exact acceptance rule

A good durable summary is:

> inline only when defined `main` directly calls defined `__original_main` exactly once.

That expands into five concrete requirements:

1. `main` exists
2. `__original_main` exists
3. neither is imported
4. there is at least one direct `Call` from `main` to `__original_main`
5. there is no second such direct call

If any of those fail, the pass does nothing.

## Why the exact-one-call rule matters

A beginner might expect the pass to inline all matching wrapper calls.
The official test file proves otherwise.

Once a second direct call is found, `InlineMainPass` bails out entirely.
That means Binaryen treats the single-wrapper case as a special cleanup opportunity, not as the start of a broader repeated-call optimization.

This is one of the easiest points to mis-teach if the pass is summarized too casually.

## Why "direct call" matters

The implementation scans only `Call` nodes.
So the pass does not reason about:

- `call_indirect`
- `call_ref`
- table entries
- aliases through globals or locals
- wrapper equivalence by behavior rather than exact naming

That keeps the pass cheap and predictable.
It also makes the name-based wrapper-cleanup mental model accurate.

## Why imported endpoints are hard stops

The pass requires bodies it can inspect and rewrite.
Imports do not provide that.

So imported `main` and imported `__original_main` are both no-op cases.
The official lit file includes each one explicitly.

## What is inherited from the shared helper

After the chooser succeeds, the actual rewrite is not unique to `inline-main`.
It inherits the same helper-based obligations as ordinary inlining.

That includes:

- wrapper block creation
- return-to-break conversion
- branch-label collision repair
- local remapping
- metadata copying
- refinalization
- nondefaultable-local fixups

This is why a naive future implementation like:

- replace `(call $__original_main ...)` with the raw body of `__original_main`

would be incomplete.

## Why the output may still contain an inlined block wrapper

The dedicated `inline-main.wast` file shows a successful result where `main` still contains a named inlined block wrapper.

That is not accidental noise.
It proves a broader point:

- `inline-main` performs the shared rewrite
- it does not promise an already-cleaned final canonical form

Later passes might simplify the result further, but that is outside the standalone pass contract.

## Relationship to neighboring passes

## Versus `inlining`

Use this rule of thumb:

- `inlining` = general planner
- `inline-main` = exact wrapper recognizer

Both share the lower-level body rewriter.
Only one owns heuristic action selection.

## Versus `inlining-optimizing`

`inlining-optimizing` adds the nested `optimizeAfterInlining(...)` rerun contract.
`inline-main` does not.

So a future port should not silently attach the optimizing wrapper's extra cleanup to `inline-main` unless it is making a deliberate local policy change.

## Versus `monomorphize`

`monomorphize` clones a new specialized callee based on callsite context.
`inline-main` inserts the existing callee body into the caller.

That distinction affects:

- signature editing
- function-count effects
- what later cleanup is needed
- what WAT shapes appear afterwards

## Main preserved families

The following families should remain no-ops in a faithful port:

- missing `main`
- missing `__original_main`
- imported `main`
- imported `__original_main`
- no direct call to `__original_main`
- more than one direct call to `__original_main`

These preserved families are just as important as the one positive family.

## Easy misconceptions to stamp out early

### Misconception: "The pass removes `__original_main`"

Not by itself.
The dedicated test surface proves the primary effect is inlining into `main`.
Removal of now-dead helpers would belong to other passes.

### Misconception: "The pass is a tiny AST text substitution"

No.
It reuses real inline-body machinery.

### Misconception: "Because it is small, it does not need a dedicated dossier"

Also no.
The chooser is small, but the public identity and inherited rewrite contract are exactly why it benefits from a separate page.

## Porting checklist

If Starshine ever adds this pass, the minimal honest checklist is:

- [ ] separate registry name from plain `inlining`
- [ ] exact `main` / `__original_main` lookup
- [ ] direct-call-only scan in `main`
- [ ] exact-one-call acceptance rule
- [ ] imported-endpoint bailouts
- [ ] shared inline-body rewrite with proper control/label/local repair
- [ ] no accidental claim that the pass belongs in the default no-DWARF path

## Sources

- [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md)
- [`../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
