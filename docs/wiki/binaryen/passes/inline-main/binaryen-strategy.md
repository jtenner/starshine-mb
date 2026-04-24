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
  - ./implementation-structure-and-tests.md
  - ./special-case-contract-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/binaryen-strategy.md
---

# Binaryen strategy for `inline-main`

## Source anchor

Use Binaryen `version_129` as the current source oracle for this pass. The 2026-04-24 immutable source manifest is [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md), which also records the narrow current-main drift check and the exact official source/test URL set.

## One-sentence summary

Binaryen `inline-main` is a tiny whole-module special-case pass that looks for **exactly one direct call** from defined `main` to defined `__original_main` and then delegates the rewrite to the ordinary shared inlining helper.

## Why this needs its own page

The implementation is small enough that it is easy to under-document.
That would be a mistake.

The real strategy is two-layered:

1. a **tiny chooser** unique to `inline-main`
2. the **ordinary low-level inline-body rewriter** shared with plain `inlining`

If a future port keeps only layer 1, it will likely miss label, return, local, and type repair.
If it keeps only layer 2, it will likely overgeneralize the pass into ordinary inlining.

## Phase 1: identify the two named functions

`InlineMainPass` first looks up:

- `main`
- `__original_main`

using module-level name lookup.

It immediately bails out if:

- `main` does not exist
- `__original_main` does not exist
- `main` is imported
- `__original_main` is imported

This means the pass is deliberately about **defined wrapper cleanup**, not import-boundary rewriting.

## Phase 2: scan only direct `Call` nodes in `main`

The implementation then uses `FindAllPointers<Call>` over `main->body`.

Important scope consequences:

- direct `call` only
- no `call_indirect`
- no `call_ref`
- no table reasoning
- no global callgraph planning

That narrow search is part of the contract, not an incidental simplification.

## Phase 3: require exactly one call to `__original_main`

The pass stores at most one candidate `Expression**` callsite pointer.

If it finds:

- zero direct calls to `__original_main` -> no-op
- one direct call to `__original_main` -> success candidate
- more than one direct call to `__original_main` -> bail out entirely

That exact-one-call rule is one of the most important non-obvious semantics in the pass.

It tells us that Binaryen is solving a specific wrapper shape, not doing general repeated wrapper cleanup.

## Phase 4: delegate to shared `doInlining(...)`

On success the pass does this conceptually:

- inline into `main`
- using `__original_main` as the copied callee body
- using ordinary `InliningAction`
- using ordinary pass options

So `inline-main` is not an alternate rewriting engine.
It is a narrow special-case front-end to the same rewriter used by the broader inlining pass family.

## What the shared helper actually brings in

Because the pass calls shared `doInlining(...)`, successful `inline-main` rewrites inherit real low-level behavior from `Inlining.cpp`.

The shared helper does more than paste a body at the callsite.
It also:

- builds a named wrapper block for the inlined code
- rewrites `return` in the copied callee into breaks to that block
- handles `return_call*` details through the updater logic
- uniquifies labels before refinalization
- copies metadata onto the cloned body
- refinalizes the destination function
- repairs nondefaultable locals with `TypeUpdating::handleNonDefaultableLocals`

This is the main reason the pass deserves its own dossier even though the chooser is tiny.

## Why the visible output can still look structured

The dedicated `inline-main.wast` test proves that a successful rewrite may still print as:

- a block named like an inlined body
- containing the copied callee contents

That is expected.

`inline-main` does **not** run a dedicated cleanup pipeline afterwards.
It only performs the shared inline rewrite itself.

So a future Starshine port should preserve the distinction between:

- the immediate result of helper-driven inlining
- and any later cleanup that other passes might perform

## Interaction with neighboring passes

## Versus plain `inlining`

`inlining` and `inline-main` share low-level body rewrite machinery, but their front halves are different.

`inlining` owns:

- function summaries
- caller planning
- heuristics
- optional partial splitting
- multi-action batches
- the plain-vs-optimizing scheduler split

`inline-main` owns only:

- exact-name lookup
- direct-call scan in `main`
- exact-one-call acceptance

So `inline-main` should be taught as a **special-case sibling**, not as a flag on ordinary `inlining`.

## Versus `monomorphize`

`monomorphize` also edits callsites and callees, but in a very different way:

- `monomorphize` clones a specialized new callee
- `inline-main` inserts the existing callee body into the caller

That distinction matters for both implementation strategy and WAT expectations.

## Versus default optimize presets

The pass is registered publicly, but it is not part of the default no-DWARF `-O` / `-Os` schedule reviewed for `version_129`.

So the right scheduler mental model is:

- available as a standalone upstream pass
- useful for specific frontend-generated wrappers
- not part of the repo's current default preset parity queue

## Important positive shapes

The main positive family is:

- defined `main`
- defined `__original_main`
- one direct call from the former to the latter

The direct dedicated test uses a tiny constant-returning `__original_main`, but because the pass delegates to shared inline machinery, the general positive space is wider than that one literal example.

For example, a successful future port must still be prepared for copied bodies that require:

- fresh wrapper labels
- copied locals
- return-to-break lowering
- local-type repair

## Important negative and bailout shapes

The reviewed implementation and lit file make these boundaries explicit:

- missing `main` -> no-op
- missing `__original_main` -> no-op
- imported `main` -> no-op
- imported `__original_main` -> no-op
- no direct call from `main` -> no-op
- more than one direct call from `main` -> no-op

These are not secondary details.
They are the actual semantic footprint of the chooser half of the pass.

## Easy misunderstandings to correct

### Misunderstanding 1: "This is just ordinary inlining focused on main"

Not quite.
The rewrite helper is shared, but the chooser is much smaller and much stricter.
There are no heuristics and no planner.

### Misunderstanding 2: "If the pass succeeds, `main` should always collapse to a bare expression"

No.
The shared inline helper may leave block structure and copied-body scaffolding visible.
The dedicated test proves that.

### Misunderstanding 3: "If there are two wrapper calls, Binaryen will inline one of them"

No.
The pass explicitly bails out on the second matching callsite.

### Misunderstanding 4: "Because it lives in `Inlining.cpp`, it is not really a separate pass"

Also no.
`pass.cpp` registers a distinct public pass name.
That separate public identity should be preserved locally.

## What a future Starshine port must preserve

- separate public registry entry from plain `inlining`
- exact `main` / `__original_main` name match
- defined-function-only requirement
- direct-`Call` search surface only
- exact-one-call acceptance rule
- reuse of a full inline-body rewriting helper, not a textual substitution
- inherited label/type/local repair behavior after success
- no claim that the pass belongs in the default no-DWARF path unless local preset work changes that explicitly

## Sources

- [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md)
- [`../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
