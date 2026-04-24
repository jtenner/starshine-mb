# 0177 - Binaryen `inline-main` research

Date: 2026-04-21
Status: completed research ingest; superseded for raw-source provenance and Starshine status by `0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`
Pass: `inline-main`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Related neighboring dossiers: `inlining`, `inlining-optimizing`, `monomorphize`

## Why this pass was chosen

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered in the living tracker.
The prompt also excluded nearly all of the recently dossiered fallback candidates.
That left two honest options:

1. justify a major-gap fallback inside an already-deep folder, or
2. widen the tracker again with another real upstream pass that is already named in the local registry and still lacks dedicated docs.

I chose option 2 again.

`inline-main` is a good expansion target because:

- it is a real public Binaryen pass on `version_129`
- it is already named in the local boundary-only registry in `src/passes/optimize.mbt`
- it is already mentioned inside the `inlining` dossier, but only as a sibling and test clue, not as its own canonical home
- it sits directly beside `inlining` and `monomorphize`, so future work is likely to blur them together unless the differences are documented explicitly
- its implementation is tiny, but the shared helper it reuses has non-obvious control-flow, return, label, and nondefaultable-local repair behavior

`agent-todo.md` currently has **no dedicated `inline-main` slice**.

## Primary official sources reviewed

### Core implementation and registration

- Binaryen `version_129` `src/passes/Inlining.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- helper and dependency files that matter because `inline-main` reuses the ordinary inlining helper:
  - `src/pass.h`
  - `src/passes/opt-utils.h`
  - `src/ir/branch-utils.h`
  - `src/ir/find_all.h`
  - `src/ir/metadata.h`
  - `src/ir/names.h`
  - `src/ir/type-updating.h`
- current-main spot check of `src/passes/Inlining.cpp` for drift on the `InlineMainPass` definition

### Official lit tests reviewed or indexed

- `test/lit/passes/inline-main.wast`
- supporting neighboring context reviewed for shared-helper behavior already documented in the plain `inlining` dossier:
  - `test/lit/passes/inlining*.wast`
  - `test/lit/passes/no-inline*.wast`
  - `test/lit/inline-hints*.wast`

## High-level conclusion

Binaryen `inline-main` is **not** a miniature version of the full `inlining` planner.

It is a very narrow whole-module special-case pass for one historical toolchain pattern:

- find a defined `main`
- find a defined `__original_main`
- confirm there is exactly one direct call from `main` to `__original_main`
- inline that one call with the same low-level helper used by the ordinary inliner
- otherwise do nothing

So the best beginner summary is:

- **special-case wrapper removal for the Clang/Emscripten `main`/`__original_main` split**
- not heuristic general inlining
- not a scheduler alias for `inlining`
- not a multi-call or callgraph optimizer

## The most important source-backed takeaways

1. `inline-main` is registered as its own public pass name in `pass.cpp` with the summary `inline __original_main into main`.
2. It is **not** part of Binaryen's default no-DWARF `-O` / `-Os` schedule in `version_129`.
3. The implementation lives inside `Inlining.cpp`, but it does **not** run the ordinary planner, heuristics, or `DoInlining` batch machinery.
4. The pass requires both `main` and `__original_main` to exist and both to be non-imported.
5. The pass scans `main` for direct `Call` nodes targeting `__original_main`.
6. It bails out unless there is **exactly one** such direct call site.
7. On success it calls the shared `doInlining(...)` helper directly.
8. Because it uses the shared helper, it inherits the same low-level inline repair work:
   - copied-body insertion
   - return-to-branch conversion
   - unique block-name repair
   - refinalization
   - nondefaultable-local fixups
9. The dedicated `inline-main.wast` test file proves that the pass is intentionally tiny and conservative:
   - one-call positive
   - already-inlined no-op
   - missing-function no-op
   - multiple-call no-op
   - imported-`main` no-op
   - imported-`__original_main` no-op
10. The reviewed `InlineMainPass` implementation on current Binaryen `main` matches the `version_129` code exactly in the checked section, so the narrow special-case contract appears stable.

## What the pass is really solving

The source comment in `Inlining.cpp` explains the reason clearly:

- Clang/LLVM may place the user's actual program body in `__original_main`
- `main` can then become a wrapper because toolchains need to handle multiple `main` signatures

That means `inline-main` is really a cleanup pass for a known ABI / frontend artifact.

A beginner should think of it like this:

- the frontend created a wrapper for toolchain reasons
- Binaryen recognizes the exact wrapper relation by name
- if the wrapper relation is simple enough, Binaryen removes one layer by inlining it

## Implementation structure

## 1. Registration is separate from general inlining

In `src/passes/pass.cpp`, Binaryen registers:

- `inline-main`
- `inlining`
- `inlining-optimizing`

as distinct pass names.

That matters because a future Starshine port should not silently treat `inline-main` as just a flag on ordinary inlining.
It is public surface in its own right.

## 2. `InlineMainPass` is tiny and whole-module

The actual special-case implementation in `Inlining.cpp` is just a small `Pass` subclass.
Its `run(Module*)` body does four things:

1. look up `main`
2. look up `__original_main`
3. search the body of `main` for direct calls to `__original_main`
4. inline exactly one call if found

There is no cost model.
There is no caller-count heuristic.
There is no partial-inlining split.
There is no batch planning.

That is the main teaching boundary.

## 3. The direct-call scan is intentionally narrow

The pass uses `FindAllPointers<Call>` on `main->body`.
That means it only looks for Binaryen direct `Call` nodes.

Important consequences:

- no `call_indirect`
- no `call_ref`
- no table reasoning
- no alias analysis
- no wrapper equivalence proof beyond direct named calls

If `main` reaches `__original_main` in some other way, this pass does not help.

## 4. The "exactly one call site" rule is a real bailout, not an accident

The loop in `InlineMainPass` stores one `Expression** callSite` pointer.
If it discovers a second direct call to `__original_main`, it returns immediately.

This is a major behavioral rule.
Binaryen is not trying to inline all wrapper calls or partially simplify repeated wrappers here.
It wants the simple, obvious one-wrapper case.

The official lit file proves this with a negative example where `main` contains:

- one dropped call to `__original_main`
- and one result-producing call to `__original_main`

That module is intentionally left unchanged.

## 5. Success delegates to the shared `doInlining(...)` helper

Once the single-call check passes, `InlineMainPass` does not reinvent rewriting.
It calls:

- `doInlining(module, main, InliningAction(callSite, originalMain, true), getPassOptions())`

This is the most important implementation fact after the exact-one-call rule.
It means:

- the special-case pass is tiny
- but the rewrite semantics are inherited from ordinary inlining

So a future port must preserve both layers:

- the tiny special-case chooser
- and the much richer shared inline-body rewriter

## 6. The shared helper brings real rewrite obligations

The shared inlining helper in `Inlining.cpp` is not trivial.
The reviewed code shows that after copying the callee body into the caller it also does things like:

- create a named wrapper block for the inlined body
- convert callee `return` into breaks to that block
- fix name collisions using `BranchUtils` and `Names`
- copy metadata
- refinalize the function
- repair nondefaultable locals through `TypeUpdating::handleNonDefaultableLocals`

So even though `inline-main` sounds like a tiny wrapper remover, the actual replacement can still need the full set of low-level inline repairs.

## 7. Why the block wrapper appears in the tests

The first positive case in `inline-main.wast` does not fully collapse to a bare constant.
Instead it prints a named inlined block wrapper around the copied body.

That is evidence for an easy-to-miss truth:

- `inline-main` does not perform a dedicated cleanup pass afterwards
- it only performs the shared inline rewrite itself

A future port should therefore preserve the distinction between:

- the direct result of shared inlining machinery
- and any later simplification that might happen if another pass runs later

## 8. Why imports are hard bailouts

The implementation returns early if either:

- `main` is imported, or
- `__original_main` is imported

That matches the lit tests and makes sense:

- imported functions have no local body to scan or rewrite
- the pass is about wrapper cleanup, not interface rewriting

## 9. Why this is not part of the default optimize path

The reviewed `pass.cpp` registration proves the pass exists.
The reviewed no-DWARF scheduler sources and the repo's tracked `no-dwarf-default-optimize-path.md` show it is not in the default `-O` / `-Os` path.

That means `inline-main` is best treated as:

- a public standalone cleanup tool
- useful for specific frontend-produced module shapes
- not part of the standard parity queue for this repo's default optimizer today

## Positive, negative, and bailout WAT shapes

## Positive family: exactly one direct wrapper call

Canonical positive shape:

```wat
(func $__original_main (result i32)
  (i32.const 0)
)
(func $main (param i32 i32) (result i32)
  (call $__original_main)
)
```

Binaryen rewrites `main` by copying the callee body in place.
In the dedicated lit file the result still includes the shared inlining block wrapper.

## Positive family: already simplified body stays simple

The test file also includes a module where `main` already contains the direct result and no longer calls `__original_main`.
That remains unchanged.

So the pass is not trying to find semantic equivalence or delete `__original_main` proactively.
It only reacts to the exact direct call pattern.

## Negative family: missing partner function

If either wrapper endpoint is absent:

- no `main`, or
- no `__original_main`

then the pass is a no-op.

## Negative family: imported endpoints

If either endpoint is imported, the pass is a no-op.

The lit file checks both:

- imported `main`
- imported `__original_main`

## Bailout family: multiple direct calls from `main`

If `main` directly calls `__original_main` more than once, the pass bails out completely.
It does not inline just one of them.
It does not partially rewrite the body.

That rule is easy to miss from the pass name alone and must be preserved.

## Easy-to-misunderstand points

### 1. It is not just "inlining, but only for main"

That is close, but incomplete.
The real difference is:

- ordinary `inlining` plans many potential actions using heuristics and can split functions
- `inline-main` applies one exact wrapper-specific rule and bypasses the planner

### 2. It is not guaranteed to erase all wrapper evidence immediately

Because it reuses the shared inline helper, the immediate result may still contain:

- an inlined block wrapper
- copied locals
- later cleanup opportunities

So a before/after diff may still look structured even when the pass succeeded.

### 3. It is not a default optimization stage

It is a standalone public pass.
That matters for both teaching and future Starshine scheduling.

### 4. The single-call condition is a semantic part of the contract

This is not just an implementation convenience.
The dedicated lit test proves Binaryen intentionally refuses the multi-call case.

## Future Starshine port constraints

A faithful future port should preserve all of the following:

1. public pass identity separate from plain `inlining`
2. exact `main` / `__original_main` name match
3. imported-endpoint bailouts
4. direct-`Call`-only search surface
5. exact-one-call requirement
6. reuse of the normal inline-body rewrite machinery rather than a weaker text substitution
7. inherited post-inline repairs:
   - label uniqueness
   - refinalization
   - nondefaultable-local handling
8. no implication that this pass belongs in the repo's default no-DWARF optimize path

## Supersession note

The 2026-04-24 follow-up [`0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](./0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md) adds the immutable raw source manifest and exact Starshine status page this first note lacked. The core Binaryen source reading here remains useful historical research, but living pages should cite the newer manifest first.

## Open questions and uncertainty

- I did not find a separate dedicated helper file for `inline-main`; the reviewed source indicates the contract is intentionally embodied by the tiny `InlineMainPass` plus shared inlining helpers.
- The `InliningAction(..., true)` argument passed by `InlineMainPass` is source-visible, but for ordinary non-`return_call` wrapper shapes it appears to have no practical effect. My current reading is that it is safe because the special-case pass delegates to the same helper shape without needing separate try-depth analysis here. That specific interpretation is an inference from the reviewed helper code, not a direct source comment.
- The reviewed current-main spot check covered the `InlineMainPass` implementation specifically. I did not do a full current-main review of all shared helper code because this dossier is anchored to `version_129`.

## Recommended living wiki landing shape

This pass deserves its own living folder because the main reusable lessons are compact but durable:

- why it is a separate pass from `inlining`
- how small the chooser really is
- which wrapper shapes it accepts or rejects
- and which parts of the real rewrite are inherited from the larger inlining engine

That keeps future boundary-pass work from either:

- overengineering `inline-main` into a full planner,
- or underengineering it into a naive AST substitution.

## Sources

- Binaryen `version_129` `src/passes/Inlining.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/pass.h`
- Binaryen `version_129` `src/passes/opt-utils.h`
- Binaryen `version_129` `src/ir/branch-utils.h`
- Binaryen `version_129` `src/ir/find_all.h`
- Binaryen `version_129` `src/ir/metadata.h`
- Binaryen `version_129` `src/ir/names.h`
- Binaryen `version_129` `src/ir/type-updating.h`
- Binaryen `version_129` `test/lit/passes/inline-main.wast`
- current-main spot check of `src/passes/Inlining.cpp` for the `InlineMainPass` section
