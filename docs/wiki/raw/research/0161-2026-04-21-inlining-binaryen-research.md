# Binaryen `inlining` research

Date: 2026-04-21
Author: OpenAI Codex
Status: archived research feeding living wiki pages

## Scope

This note adds a first-class dossier for upstream Binaryen `inlining`, the **plain** sibling of the already documented `inlining-optimizing` pass.

The campaign rules for this thread required picking exactly one Binaryen pass that still needed more wiki information. The main no-DWARF / saved-`-O4z` queue was already dossier-covered, and the first widened upstream-only registry queue was also dossier-covered. So this note explicitly widens the tracker again with a source-backed local-registry candidate.

## Why this pass is an eligible tracker expansion

`inlining` is a fair campaign target because all of the following are true:

1. it is already a named local boundary-only registry entry in `src/passes/optimize.mbt`
2. it is a real upstream Binaryen public pass name registered in `src/passes/pass.cpp`
3. it shares its implementation with the already-covered `inlining-optimizing` pass, so understanding the plain variant removes a real teaching gap rather than inventing a speculative side topic
4. the plain-vs-optimizing split is scheduler-significant and easy to misunderstand
5. `agent-todo.md` currently has **no dedicated `inlining` slice**; it only has the optimizing `INL` slice

## Main question

What does Binaryen `version_129` actually do for plain `inlining`, and how is that different from `inlining-optimizing`?

## Short answer

Binaryen `inlining` is a whole-module boundary pass that:

- scans every function to compute call counts, size estimates, loop/delegate flags, trivial-instruction status, and root-like global uses
- decides whether each function is fully inlineable, partially inlineable through a split, or not inlineable
- plans only reachable **direct** `call` / `return_call` sites for actual inline actions in `version_129`
- rewrites callsites by copying the callee body, remapping locals, replacing returns with breaks, zeroing zeroable vars, and preserving reachability semantics
- optionally splits a function into `inlineable` and `outlined` pieces for two narrow top-of-function `if` pattern families
- removes now-dead non-root callees and temporary split helpers
- refinalizes, uniquifies labels, and repairs nondefaultable locals in touched functions

The **plain** pass stops there.

`inlining-optimizing` is the same engine with `optimize = true`, which causes a nested rerun of `precompute-propagate` plus Binaryen's default function-optimization pipeline on the functions that changed.

That optimizing rerun is the central reason this separate dossier is useful.

## Primary upstream sources reviewed

### Core implementation and scheduler

- Binaryen `version_129` `src/passes/Inlining.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/opt-utils.h`
- Binaryen `version_129` `src/pass.h`

### Helper dependencies referenced by the pass

- `src/ir/branch-hints.h`
- `src/ir/branch-utils.h`
- `src/ir/drop.h`
- `src/ir/eh-utils.h`
- `src/ir/find_all.h`
- `src/ir/literal-utils.h`
- `src/ir/localize.h`
- `src/ir/metadata.h`
- `src/ir/module-utils.h`
- `src/ir/names.h`
- `src/ir/properties.h`
- `src/ir/return-utils.h`
- `src/ir/type-updating.h`
- `src/ir/utils.h`

### Official test surfaces reviewed

- `test/lit/passes/inlining_optimize-level=3.wast`
- `test/lit/passes/inlining_enable-tail-call.wast`
- `test/lit/passes/inlining_splitting.wast`
- `test/lit/passes/inlining_splitting_basics.wast`
- `test/lit/passes/inlining-trivial-instructions.wast`
- `test/lit/passes/inlining-trivial-calls-1.wast`
- `test/lit/passes/inlining-unreachable.wast`
- `test/lit/passes/inlining-gc.wast`
- `test/lit/passes/no-inline.wast`
- `test/lit/passes/no-inline-monomorphize-inlining.wast`
- `test/lit/passes/inline-main.wast`
- `test/lit/inline-hints.wast`
- `test/lit/inline-hints-func.wast`

## Relation to existing repo docs

I also reviewed the existing `inlining-optimizing` dossier because it already documents the same upstream implementation file. That folder remains useful background, but it does **not** remove the need for a plain-pass home because it teaches the optimizing wrapper as the main subject.

The new dossier should therefore preserve two truths at once:

- most of the implementation is shared
- the public pass contract is **not** identical because only the optimizing variant adds the nested useful-pass rerun

## Key implementation findings

## 1. One implementation, three public names nearby

`pass.cpp` registers:

- `inlining`
- `inlining-optimizing`
- `inline-main`

The first two share the same `Inlining` pass class and differ only by the `optimize` flag. `inline-main` is a tiny special-case wrapper that calls the same low-level `doInlining(...)` helper for `main` and `__original_main`.

So the real plain-pass question is not “which file belongs to it?” but rather:

- what behavior disappears when `optimize = false`?

Answer: the inline planner, splitter, callsite rewrite, touched-function refinalization, and dead-callee cleanup all stay; only the nested useful-pass rerun disappears.

## 2. Plain `inlining` is **not** part of the default no-DWARF optimize path

The default no-DWARF `-O` / `-Os` post-pass cluster in `pass.cpp` schedules:

- `dae-optimizing`
- `inlining-optimizing`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `simplify-globals-optimizing` or `simplify-globals`
- `remove-unused-module-elements`
- later string/global/layout cleanup

It does **not** schedule plain `inlining` in that default path.

That matters for this dossier:

- the pass is an upstream/public/local-registry surface,
- but it is an upstream-only expansion topic for this repo's current parity campaign, not an open no-DWARF missing slot.

## 3. `FunctionInfo` is the real first algorithm

Before planning inline rewrites, Binaryen scans each function into a `FunctionInfo` record containing at least:

- `refs`
- `size`
- `hasCalls`
- `hasLoops`
- `hasTryDelegate`
- `usedGlobally`
- `trivialInstruction`
- `inliningMode`

This is the durable beginner lesson:

- Binaryen is not choosing inlining from one call expression in isolation
- it is choosing from whole-module summaries plus per-function shape classification

## 4. The planner in `version_129` only chooses direct callsites

This was the most important source-grounded correction from this review.

`Planner::visitCall(...)` plans reachable direct `call` / `return_call` sites whose target function is known inlineable and is not the current function itself.

But `FunctionInfoScanner` intentionally omits `CallIndirect` and `CallRef` from direct-call recursion tracking, and the planner itself does **not** add `visitCallRef(...)` / `visitCallIndirect(...)` actions for inline planning in `version_129`.

So the real planning contract in this release is:

- actual inline *selection* is direct-call based
- indirect/ref calls still matter indirectly for conservatism and reachability of function boundaries
- `CallRef` / `ReturnCallRef` handling exists in the *updater* because already-inlined code may contain return-style ref calls that must be repaired when copied

That distinction is easy to miss and worth keeping explicit.

## 5. The worth-inlining heuristic is layered

`FunctionInfo::worthFullInlining(...)` is not one flat threshold.

It applies several ordered rules:

1. `try_delegate` bodies are currently rejected outright
2. tiny bodies under `alwaysInlineMaxSize` inline immediately
3. one-use, not-globally-used functions inline under `oneCallerInlineMaxSize`
4. trivially shrinking single-instruction wrappers always inline
5. bodies above `flexibleInlineMaxSize` never inline
6. multi-use functions stop under size-focused or not-heavily-speed-focused settings
7. `MayNotShrink` trivial instructions inline only under heavier speed focus
8. remaining functions inline only if they have no calls and either no loops or loops are allowed by option

This gives a much better beginner summary than “Binaryen inlines small functions.”

## 6. “Trivial instruction” is a real size class

The pass distinguishes:

- `Shrinks`
- `MayNotShrink`
- `NotTrivial`

A function is `Shrinks` only when its body is one non-control instruction using parameter locals exactly once and in order.

That lets Binaryen say:

- this inline always shrinks code size at the callsite

The lit files `inlining-trivial-instructions.wast` and `inlining-trivial-calls-1.wast` are the easiest official proof surfaces for this rule.

## 7. Exports, start, and `ref.func` uses keep boundaries alive

During `prepare()`, exports and the start function mark `usedGlobally = true`.
The scanner also counts `ref.func` uses into `refs`.

That means a function can inline into direct callers while still surviving as a standalone function because:

- it is exported
- it is the start function
- it is tabled or otherwise referenced through `ref.func`

A future port must preserve that “inline some callsites but keep the callee” split.

## 8. The core rewrite is branch-structured, not text substitution

`doCodeInlining(...)` does careful AST repair:

- create a fresh outer block for the inlined code
- pick a unique label that avoids collisions with existing branch targets
- map callee locals onto fresh caller locals
- assign operands into the mapped params
- zero out zeroable callee vars because loop re-entry can otherwise observe stale values
- copy the callee body and metadata into the caller
- rewrite `return` into `br` to the new return block
- rewrite nested `return_call*` when the outer callsite is not itself a return
- preserve unreachable-typed behavior when an unreachable call becomes a reachable block wrapper after copying

This is why a future port must think in terms of label, local, and type repair rather than “replace call node with body.”

## 9. `return_call` handling has a subtle try-specific split

The pass has a special `hoistCall` path when the original callsite is a `return_call` inside a `try`.

In that case Binaryen:

- wraps the caller body in a new named block,
- branches out of the original body before entering the inlined body,
- and sequences the inlined body afterward.

This exists because simply inserting the inlined block in place would give wrong branch-capture behavior around try nesting and operand expressions.

The dedicated tail-call test file is essential here.

## 10. Partial inlining is narrow, structured, and optional

`FunctionSplitter` is enabled only when all of the following hold:

- optimize level is at least `3`
- shrink level is `0`
- `partialInliningIfs > 0`

So partial inlining is not a default generic mode.

The splitter only recognizes two top-of-function pattern families.

### Pattern A

A function begins with:

- `if (simple) return;`
- followed by heavier later work

The splitter can outline the later work and inline only the guard.

### Pattern B

A function body is a small run of top-level `if` guards with simple conditions and simple final item rules.

Important checked constraints include:

- no breaks to the top-level body block
- conditions must be simple
- no else arms
- if bodies must be `none` without returns, or `unreachable`
- any final item must be simple
- locals written inside the `if` bodies must not be read by that final item

This is a deliberately narrow shape family, not arbitrary CFG splitting.

## 11. The splitter can intentionally upgrade partial to full inlining

If the would-be outlined remainder is itself small enough to inline normally, `FunctionSplitter` returns `Full` instead of a split mode.

That avoids doing:

- split now,
- then full-inline the outlined remainder later,

when the final result would match a normal full inline anyway.

The source comments explicitly call out that this can inline functions slightly larger than the nominal limit when the split creates a small enough outlined piece.

## 12. Iteration policy is conservative and deterministic

The pass runs iterative waves, but not forever.

Important guards include:

- at most one outer loop per original function count
- at most `5` iterations of repeated inlining/splitting work per function name
- deterministic sequential choice of actions after parallel discovery
- do not inline **into** a function and also inline that same function elsewhere in the same iteration
- reject actions that would exceed `maxCombinedBinarySize`

So the algorithm is best described as:

- parallel discovery,
- deterministic filtering,
- parallel application on disjoint target functions.

## 13. `maxCombinedBinarySize` is a real global safety rail

The size guard is not about raw function node counts alone.
Binaryen estimates combined binary size as:

- `BytesPerExpr * (target.size + source.size)`

and compares that against `maxCombinedBinarySize`, whose default in `pass.h` is `400 * 1024`.

That keeps pathological giant-function growth out of the pass even when other heuristics might otherwise allow the inline.

## 14. Plain vs optimizing is one boolean with a big semantic effect

Inside `iteration(...)`, Binaryen always adds the actual `DoInlining` worker.
It only adds `OptUtils::addUsefulPassesAfterInlining(runner)` when `optimize` is true.

`opt-utils.h` makes that helper explicit:

- prepend `precompute-propagate`
- then run `addDefaultFunctionOptimizationPasses()`

So the beginner-safe distinction is:

- `inlining`: inline and repair only
- `inlining-optimizing`: inline, repair, then immediately harvest the new cleanup opportunities

## 15. `updateAfterInlining()` owns more than refinalization

After copied code lands, Binaryen always:

1. uniquifies block labels
2. `ReFinalize()`s the touched function
3. runs `TypeUpdating::handleNonDefaultableLocals(...)`

The GC/nondefaultable-local test file exists because simply adding a new local slot is not enough when the copied callee had a nonnullable local type.

## 16. `inline-main` is intentionally tiny and reuses the same low-level helper

The special `inline-main` pass only:

- looks for both `main` and `__original_main`
- refuses imports or multiple callsites
- then performs one `doInlining(...)` rewrite

This confirms that Binaryen sees the lower-level inline helper as a reusable primitive, while the main planner pass layers heuristics and iteration on top.

## Important shapes to preserve in a future Starshine port

A future port must preserve at least these source-backed families:

- tiny single-instruction wrappers that always shrink
- one-caller inline-and-remove cases
- exported/tabled/start survivors that inline but remain declared
- unreachable callees whose trap must propagate into the caller
- return-call rewriting into branches and hoisted try-local cases
- partial-inlining Pattern A and Pattern B, but **only** with their narrow syntactic and local-dependency gates
- nondefaultable-local repair after copied locals are introduced
- label-collision avoidance and post-inline unique-name repair
- the exact difference between plain `inlining` and optimizing `inlining-optimizing`

## Easy things to misunderstand

1. plain `inlining` is not on the repo's current default no-DWARF optimize path
2. `version_129` actual inline planning is direct-call based, not generic `call_ref` planning
3. partial inlining is not arbitrary CFG extraction; it is two narrow top-of-function `if` families
4. the pass keeps some inlined callees alive because root/reference uses survive
5. inline rewrite requires label/local/type repair, not just AST substitution
6. the optimizing variant's nested rerun is not optional polish; it is the main public semantic split from plain `inlining`

## Open questions / uncertainty

- I did not audit a newer post-`version_129` upstream release for drift in the `Inlining.cpp` planner surface during this thread. Claims above are for `version_129` unless explicitly labeled otherwise.
- The existing repo-local `inlining-optimizing` dossier already teaches the shared engine, but some of its older summaries read more broadly than the `version_129` direct-call planner proved in this pass-focused review. Treat the new plain-pass dossier as the stricter `version_129` baseline if the two summaries appear to disagree.

## Files added / updated by this research

Planned living pages created from this note:

- `docs/wiki/binaryen/passes/inlining/index.md`
- `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inlining/heuristics-splitting-and-plain-vs-optimizing.md`
- `docs/wiki/binaryen/passes/inlining/wat-shapes.md`

Planned shared-page updates:

- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Local registry and scheduler context:
  - `src/passes/optimize.mbt`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-calls-1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints-func.wast>
