# 0121 - `inlining-optimizing` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `inlining-optimizing` really works, which helpers it leans on, and which IR shapes a future Starshine port must preserve.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` now suggests `inlining-optimizing` as the highest-value remaining next dossier.
- The pass still has wiki status `none` in the tracker and is still only a boundary-only placeholder in `src/passes/optimize.mbt`.
- The canonical Binaryen no-DWARF `-O` / `-Os` path runs it in the late global post-pass cluster immediately after `dae-optimizing`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `49`
- This pass is easy to misdescribe as “inline small functions.” The actual Binaryen implementation is much bigger than that:
  - it is a whole-module planner with per-function summaries
  - it has several different inline actions, not one
  - it can do partial inlining by splitting conditional call-containing regions first
  - it reasons about some `call_ref` traffic with `PossibleContents`
  - the `optimizing` variant is only complete once it reruns the nested cleanup pipeline on touched functions
- That combination makes it a strong documentation target near already-documented neighbors like `dae-optimizing`, `duplicate-function-elimination`, `code-folding`, `local-cse`, and `rse`.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/Inlining.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/FunctionSplitter.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/FunctionSplitter.cpp>
- `src/ir/possible-contents.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- `src/ir/cost.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- `test/lit/passes/inlining.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>

## Fast answer

Binaryen’s `inlining-optimizing` pass is a late module-level inliner that repeatedly:

1. scans the whole module to summarize each function
2. chooses one of several actions for profitable call patterns
3. rewrites callsites and maybe deletes now-dead internal helpers
4. reruns `precompute-propagate` plus the default function optimization pipeline on the functions that changed

That means the pass is **not**:

- a function-local peephole
- a pure size-only rule like “inline all tiny callees”
- the same thing as plain `inlining`
- limited to direct `call`
- finished once the call expression disappears

The important durable facts are:

- `inlining-optimizing` is the same core inliner as plain `inlining`, but with `optimize = true` so it invokes `OptUtils::optimizeAfterInlining(...)` on the changed functions.
- Binaryen plans from **whole-module summaries** such as:
  - estimated callee size via `CostAnalyzer`
  - call counts
  - whether a function is a root because it is exported or the start function
  - whether a function has loops, tail calls, or `try_delegate`
  - whether a function still has uses the inliner cannot safely rewrite away
- The planner has more than one profitable action:
  - inline directly and maybe delete the callee
  - inline but keep the callee because other uses remain
  - partially inline by splitting an `if` / `br_if` / `select`-shaped region into a helper first
  - do nothing
- Some `call_ref` and `return_call_ref` sites are eligible when `PossibleContents` can prove a sufficiently precise internal target set. Unknown indirect traffic is deliberately preserved.
- Binaryen is conservative around roots, imports, loops, tail calls, `try_delegate`, recursive growth, and non-call uses such as escaping function references.
- The nested cleanup rerun is part of the real pass contract, not optional polish.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` schedules `inlining-optimizing` in `addDefaultGlobalOptimizationPostPasses()` when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 2`

In the canonical no-DWARF `-O` / `-Os` pipeline in this repo, the pass appears here:

- after `dae-optimizing`
- before `duplicate-function-elimination`
- before `duplicate-import-elimination`
- before `simplify-globals-optimizing`

The current local no-DWARF page already records the same placement.

## Saved generated-artifact `-O4z` audit

The saved generated-artifact ordered replay records a real skipped top-level slot:

- slot `49`: `inlining-optimizing`

That `-O4z` ordinal is higher than the no-DWARF ordinal because the shrinkier pipeline also includes extra earlier function passes such as `flatten`, `merge-locals`, and the no-tee simplify-locals variant.

## Nested reruns are part of the pass, not aftermath

`opt-utils.h` shows that after Binaryen inlines new code it runs:

- `precompute-propagate`
- then the full default function optimization pipeline
- but only on the touched functions

The saved `o4z-wasm-opt-debug.log` proves that `inlining-optimizing` is not “one top-level pass name and done.” Between the top-level `inlining-optimizing` line and the next top-level `duplicate-function-elimination` line, repo-local counting over the saved log finds:

- `5` nested `ssa-nomerge` executions
- `5` nested `code-folding` executions
- `10` nested `local-cse` executions
- `10` nested `merge-blocks` executions
- `15` nested `precompute-propagate` executions

Those counts make sense because each nested rerun replays the full function cleanup pipeline, and that pipeline itself contains repeated slots.

The same interval also shows the more aggressive `-O4z`-specific nested shape with repeated:

- `flatten`
- `simplify-locals-notee-nostructure`
- `merge-locals`

So the future Starshine port needs two scheduler stories:

1. the canonical no-DWARF `-O` / `-Os` rerun contract
2. the wider `-O4z` evidence that the same optimizing helper scales up to the shrinkier function pipeline too

## Actual implementation structure

## 1. Pass family and variant split

`pass.cpp` registers two related pass names:

- `inlining`
- `inlining-optimizing`

The source comment beside `inlining` literally nudges users toward the optimizing variant.

In `Inlining.cpp`, the implementation is one main module pass parameterized by an `optimize` flag. The important practical split is:

- plain `inlining`
  - performs the inlining rewrite only
- `inlining-optimizing`
  - performs the same rewrite
  - then runs `OptUtils::optimizeAfterInlining(...)` on changed functions

This is very similar to the `dae-optimizing` relationship, but the core transformation here is callsite replacement rather than function-boundary simplification.

## 2. This is a module pass, not a function pass

The inliner keeps whole-module state such as:

- function summaries
- reverse call counts
- root-ness
- escaped or otherwise uninlineable uses
- possible `call_ref` targets
- the set of functions worth re-optimizing after rewrite

That is why the repo tracker is right to keep it in the boundary-only bucket today. A faithful port needs module-wide reasoning and nested rerun support, not just another HOT function walker.

## 3. `FunctionInfoScanner` is the real first phase

The source spends a lot of effort computing a `FunctionInfo` summary per function before planning any rewrite.

Important fields and facts collected here include:

- `baseSize`
  - an estimated code-size cost from `CostAnalyzer`
- `refs`
  - how many direct function-reference uses were seen
- `hasCalls`
  - whether the function body calls anything at all
- `hasInlineableCalls`
  - whether the body contains callsites the pass might inline into
- `hasUninlineableUses`
  - whether the function is still used in ways the pass cannot fully rewrite away
- `hasLoops`
  - used in profitability and safety heuristics
- `hasTailCalls`
  - blocks several otherwise-profitable rewrites
- `hasTryDelegate`
  - makes Binaryen more conservative
- `isRoot`
  - whether implicit callers may exist because the function is exported or is the module start
- `inliningDepth`
  - a heuristic depth cap so Binaryen does not keep nesting inlines forever

The beginner-friendly takeaway is:

- Binaryen does **not** decide inline profitability from the call expression alone.
- It decides from caller state, callee state, use counts, and escape/root facts.

## 4. What counts as an inlineable call

The scanner can recognize and later plan around:

- direct `call`
- direct `return_call`
- some `call_ref`
- some `return_call_ref`

It does **not** treat every indirect call as fair game.

For `call_ref`-family cases, the pass uses `ModuleUtils::ParallelFunctionAnalysis<PossibleContents>` to ask what function values might flow into the callee reference expression.

Safe high-level summary:

- if Binaryen can prove the possible targets precisely enough and they are internal inlineable functions, the ref-based call may become a candidate
- if the target information is too broad or escapes out of Binaryen’s reasoning, the call stays as-is

I am intentionally phrasing that conservatively. The source clearly relies on `PossibleContents` to unlock ref-based opportunities, but I did not derive a separate formal matrix for every multi-target case in this thread.

## 5. Roots and escaping uses matter a lot

The pass distinguishes between:

- a function that is only called through rewriteable sites
- and a function that might still be observed from somewhere else

Two especially important root families are:

- exports
- the start function

Unless `ignoreImplicitCalls` is set, Binaryen treats those as roots because outside callers or implicit runtime entry can still exist.

Likewise, if Binaryen sees uses it cannot reason through as rewriteable calls, the function is not just “a tiny leaf ready to delete.” It has an observable surface that must remain available.

This is one of the main reasons the pass feels more like boundary optimization than like simple local cleanup.

## 6. The cost model is size-based, but not naively size-based

The central profitability helper is `worthInlining(...)`.

The key ingredients are:

- estimated callee size from `CostAnalyzer`
- the inline overhead cost of the current callsite
- whether all callsites will disappear
- whether the function has a single use
- shrink-vs-speed policy
- loop and tail-call conservatism
- self-recursion growth limits

Important details the source makes explicit:

### Very small functions get a stronger fast path

Binaryen has an `alwaysInlineMaxSize` threshold.

If a function is tiny enough and not blocked by loops or tail-call shape, the planner is happy to inline it aggressively.

### One-caller functions get a looser threshold

Binaryen has a separate “one caller” threshold. If a helper is only used in one place, the pass can be more willing to inline it because keeping the separate helper buys less reuse.

### The pass discounts the cost of the callsite itself

Inlining removes a call instruction.
If all callsites disappear, Binaryen can ignore more of the call-overhead cost while comparing “callee size” against “net size after inline.”

That is why the source does not just check `callee_size <= threshold`.
It checks whether the inline would be a net improvement once the old call form disappears.

### Tail calls are a major negative family

`worthInlining(...)` bails out early for functions with tail calls.

So even if a function is not enormous, “contains tail calls” is enough to make the profitability story fundamentally different.

### Self-recursive growth is blocked

Binaryen refuses to inline when the rewrite would grow a self-recursive function in the wrong direction.

That is another good example of the pass not being “inline every profitable-looking site independently.”
It watches whole-function growth patterns too.

## 7. Partial inlining is a real second strategy

If direct full inlining is not chosen, Binaryen may still decide the function is worth **partial** inlining.

The pass computes a `worthPartialInlining` signal while scanning call-containing control subexpressions.
The rough idea is:

- find a conditional or control fragment that contains calls
- estimate the amount of code outside that fragment
- if splitting that fragment into a helper looks profitable, do the split first
- then the new helper can often be fully inlined where the original whole function was too large or too mixed

This is why the pass source depends on `FunctionSplitter::FlexSplitter`.

The helper in `FunctionSplitter.cpp` shows that this is not arbitrary CFG surgery. The splitter is focused on structured patterns like:

- `if`
- `br_if`
- `select`
- straight-line call-carrying regions with a clear split point

It is also careful about things like:

- preserving fallthrough and branch destinations
- not splitting expressions that are too small to justify the new helper
- isolating only one profitable split location at a time

So a faithful future port will likely need:

1. a whole-module inliner
2. plus a small structured function splitter

rather than trying to fake partial inlining as a special inline rewrite.

## 8. The planner has multiple actions, not one yes/no answer

`InliningAction` in the source makes the real planning surface explicit.

The action families are roughly:

- **inline directly and remove the callee if possible**
- **inline directly but keep the callee**
- **partially inline by splitting first**
- **do nothing**

That action split is one of the most useful beginner mental models for this pass.

A function does not move from “uninlined” to “inlined” in one uniform way.
It can instead move through:

- keep as helper
- inline some uses only
- split one hot conditional path into a helper
- inline the helper
- leave the original boundary alive for other reasons

## 9. The pass updates module state after each wave

After a batch of inline decisions, Binaryen updates state such as:

- remaining call counts
- removed uses
- which callees can now be deleted
- which callers were modified and therefore are worth post-inline cleanup

Then it can loop again.

This means the pass is not a single scan with a frozen call graph.
It is more like:

- scan
- plan
- mutate
- refresh key counts
- maybe plan more

## 10. Nested cleanup is the contract behind the word `optimizing`

`OptUtils::optimizeAfterInlining(...)` does four important things:

1. optionally validates the module before the nested run in pass-debug mode
2. creates a `FilteredPassRunner` for only the touched functions
3. prepends `precompute-propagate`
4. then reruns the default function optimization pipeline

That makes the word `optimizing` concrete.

This is not “maybe do some later cleanup eventually.”
It is a deliberately chosen immediate subpipeline.

The cleanup is important because inlining often exposes fresh:

- constant propagation opportunities
- dead local traffic
- dead branches
- cast cleanup
- code folding and block merging opportunities
- redundant-set cleanup

Without that nested rerun, a Starshine port would still be missing real Binaryen behavior even if the call replacement itself matched.

## 11. What the shipped test covers

`test/lit/passes/inlining.wast` is very useful because it locks several families that are easy to misunderstand.

Visible covered themes include:

- plain `--inlining`
- `--inlining-optimizing`
- partial inlining through `--partial-inlining-ifs`
- tiny-threshold behavior through `--always-inline-max-function-size=4`
- root and export preservation
- ref-based callsite inlining shapes
- loops and return-shape interactions
- EH-sensitive and feature-sensitive cases

I am treating that test as the best shipped source for the pass’s user-visible rewrite surface.

## Important rewrite shapes

## Positive family 1: tiny direct leaf helpers inline eagerly

If a private helper is tiny, called directly, and free of the major blockers, Binaryen will usually inline it into the caller and may remove the helper afterward.

## Positive family 2: one-caller helpers can inline even when not tiny-tiny

The separate one-caller threshold means a helper used in only one place can inline even when it is not in the smallest bucket.

## Positive family 3: known ref-based callsites can inline

When a `call_ref` or `return_call_ref` carries a function reference Binaryen can resolve precisely enough, the site can behave more like a direct call for inlining purposes.

## Positive family 4: conditional call shapes may split first, then inline

If a whole function is too mixed to inline directly, but one structured branchy region is a good candidate, Binaryen may split out a helper and then inline that smaller piece.

## Negative family 1: imports never inline

Imported functions are a boundary. They are callable, but the implementation is outside the module and cannot be copied into the caller.

## Negative family 2: exports and start roots are not deletable helpers

Even if Binaryen inlines some root calls, the function boundary must remain if implicit or external callers may still exist.

## Negative family 3: tail-call-containing callees are deliberately conservative

Tail calls are a strong source-level bailout for the ordinary inline-worth heuristic.

## Negative family 4: broad or unknown indirect targets stay indirect

If Binaryen cannot make a precise enough `PossibleContents` claim, it does not guess.

## Negative family 5: self-recursive growth is blocked

Inlining that only makes a recursive function bigger is deliberately rejected.

## Negative family 6: `try_delegate` and similar control hazards reduce willingness to inline

The source keeps extra conservatism around these shapes rather than forcing the inline and repairing later.

## What a future Starshine port must preserve

- Treat `inlining-optimizing` as a **module** transformation with call-count, root, and escape reasoning, not as a plain function-local AST substitution pass.
- Preserve the split between:
  - plain `inlining`
  - `inlining-optimizing`
- Preserve direct-call and precise-ref-call reasoning instead of pretending all indirect calls are equally inlineable.
- Preserve root and escape conservatism for:
  - exports
  - the start function
  - uninlineable uses / escaping references
- Preserve the size heuristics, including:
  - always-inline tiny threshold
  - one-caller threshold
  - callsite-overhead discount
  - tail-call conservatism
  - self-recursive growth guard
- Preserve partial inlining as a real structured split strategy, not as an afterthought.
- Preserve the nested `optimizeAfterInlining(...)` rerun with `precompute-propagate` first.
- Preserve the function-filtered rerun scope: only touched functions get the nested cleanup.

## Easy misunderstandings to avoid

1. **“This pass is just tiny-function inlining.”**
   - No. It is a module-level planner with multiple action families and a nested cleanup pipeline.
2. **“Plain `inlining` and `inlining-optimizing` are just aliases.”**
   - No. The optimizing variant is the one that triggers the filtered nested rerun.
3. **“Indirect calls are out of scope entirely.”**
   - Too broad. The pass can reason about some ref-based calls using `PossibleContents`.
4. **“Inlining finishes when the call expression is gone.”**
   - No. The optimizing variant is designed around post-inline cleanup.
5. **“Deleting a callee is automatic after any inline.”**
   - No. Roots and other surviving uses can keep the function alive.
6. **“Partial inlining is the same as ordinary full inlining.”**
   - No. It depends on a separate structured splitting helper.

## Uncertainties and explicit inferences

- I relied directly on `Inlining.cpp`, `opt-utils.h`, `pass.cpp`, `FunctionSplitter.cpp`, `possible-contents.h`, `cost.h`, and the shipped `inlining.wast` test.
- I did **not** separately audit the option-parsing site for every inliner flag. Where I mention flags like `--partial-inlining-ifs` or `--always-inline-max-function-size`, I am grounding that claim in the shipped lit test invocation lines.
- I am treating the repo’s maintained no-DWARF page as the canonical local summary of the ordinary `-O` / `-Os` scheduler, and the saved `.artifacts/o4z-wasm-opt-debug.log` as the canonical local evidence for the more aggressive generated-artifact `-O4z` nested reruns.
- I did not derive a separate proof table for every multi-target `call_ref` possibility. My safer summary is: precise `PossibleContents` facts can unlock ref-based inline opportunities, while broad or unknown targets remain indirect.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/FunctionSplitter.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>
