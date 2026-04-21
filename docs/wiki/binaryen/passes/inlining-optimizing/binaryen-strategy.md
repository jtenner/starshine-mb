---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ../dae-optimizing/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `inlining-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/Inlining.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inline helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/FunctionSplitter.cpp`
  - `src/ir/possible-contents.h`
  - `src/ir/cost.h`
- The shipped behavior examples come from `test/lit/passes/inlining.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/FunctionSplitter.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>

## High-level intent

Binaryen uses `inlining-optimizing` to replace profitable callsites with callee bodies.

That sentence is true but incomplete.

The actual implementation is a late **module planner** with four important parts:

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Build `FunctionInfo` summaries for every function and count rewriteable calls | Inline profitability depends on whole-module facts, not only on one call expression |
| Plan | Choose a direct inline, inline-without-delete, partial inline, or no-op action | Different call/callee situations need different rewrite modes |
| Rewrite | Apply the chosen inline or split, update call/use counts, and maybe remove dead internal helpers | The planner has to keep module state honest after every wave |
| Optimize-after-inline | Rerun `precompute-propagate` plus the default function optimization pipeline on touched functions | The optimizing variant is designed to cash in on cleanup opportunities immediately |

That means the pass is not just:

- “tiny function inlining”
- “copy the callee body into the caller”
- or “inline and stop”

## Pass family and scheduler placement

`pass.cpp` exposes two related pass names:

- `inlining`
- `inlining-optimizing`

The default global optimization post-pass cluster uses `inlining-optimizing` when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 2`

In the canonical no-DWARF `-O` / `-Os` path documented in this repo, the pass appears:

- after `dae-optimizing`
- before `duplicate-function-elimination`
- before `duplicate-import-elimination`
- before `simplify-globals-optimizing`

A future Starshine port must preserve that placement because the pass changes the number of functions, their bodies, and which later module cleanups can fire.

## Same engine, different variant

The core implementation in `Inlining.cpp` is one main inliner parameterized by an `optimize` flag.

That split matters:

| Variant | Core inline rewrite | Post-inline filtered cleanup |
| --- | --- | --- |
| `inlining` | yes | no |
| `inlining-optimizing` | yes | yes |

So the optimizing variant is not a cosmetic alias. It is a semantically larger pass.

## Phase 1: `FunctionInfoScanner` is the first real algorithm

Before rewriting anything, Binaryen scans each function and records summary facts.

Important recorded facts include:

- `baseSize`
  - estimated from `CostAnalyzer`
- `hasCalls`
  - whether the function calls anything at all
- `hasInlineableCalls`
  - whether it contains calls worth considering for inline planning
- `hasUninlineableUses`
  - whether some surviving uses are outside the easy rewrite surface
- `hasLoops`
  - used by the profitability heuristics
- `hasTailCalls`
  - a major bailout family
- `hasTryDelegate`
  - a control-structure warning flag
- `refs`
  - direct function-reference uses
- `isRoot`
  - whether the function is exported or is the start function, unless implicit calls are ignored
- `inliningDepth`
  - used to stop unbounded nesting growth

Beginner takeaway:

- a callsite is not planned in isolation
- it is planned using a summary of both the callee and the whole module environment around it

## What counts as a root

By default, exports and the start function are treated as roots.

That means:

- Binaryen must assume unseen callers may still exist
- so the function boundary cannot be treated as disposable just because some direct calls were inlined away

This is one of the most important differences between module inlining and local expression simplification.

## What counts as an uninlineable use

The scanner distinguishes between:

- ordinary direct or precise ref-based calls that the pass might rewrite
- and other uses that keep the function boundary alive

That escape/use distinction is why a callee may inline into some callers while still surviving as a standalone function.

## Phase 2: Binaryen only plans inlineable call kinds

The pass can plan around:

- direct `call`
- direct `return_call`
- some `call_ref`
- some `return_call_ref`

The pass uses `ModuleUtils::ParallelFunctionAnalysis<PossibleContents>` to approximate what function values may flow into a `call_ref` target expression.

Safe summary:

- precise internal target knowledge can unlock ref-based inline opportunities
- broad or unknown indirect targets are left alone

A future port should preserve that asymmetry rather than flattening it into either:

- “only direct calls ever inline,” or
- “all indirect-style calls are fair game”

## Phase 3: the cost model is structural, not hand-wavy

Inlining profitability in Binaryen is based on estimated size, but not in a simplistic “callee smaller than X” way.

The planner combines:

- the estimated callee size from `CostAnalyzer`
- the cost of the current callsite itself
- whether all uses disappear
- whether the callee has a single use
- shrink-vs-speed policy
- loop, tail-call, and recursive-growth guards

Important source-derived rules:

### Very small helpers inline aggressively

Binaryen has an always-inline tiny threshold.

If a helper is tiny enough and not blocked by loop or tail-call structure, it gets a stronger fast path.

### Single-use helpers get a looser threshold

A helper used only once is easier to justify inlining because the separate function body buys less reuse.

### Call overhead is discounted

If Binaryen removes the callsite itself, the effective net size is better than the raw callee-body size suggests.

That is why the pass compares against a net-size model instead of a raw body-size threshold only.

### Tail calls are a strong bailout family

The ordinary “worth inlining” helper bails out for tail-call-containing functions.

So “tiny” is not enough by itself. Tail-call shape changes the whole decision.

### Self-recursive growth is blocked

The planner refuses to inline when the rewrite would grow a self-recursive function in the wrong direction.

This is another sign that the pass is managing module growth, not just matching tiny patterns.

## Phase 4: the planner has several action families

The source models multiple actions, not one yes/no answer.

Useful beginner summary:

| Action family | Meaning |
| --- | --- |
| Inline and remove | Inline the callsites and let the callee disappear if no rewriteable or root-keeping uses remain |
| Inline but keep | Inline at some sites, but the callee boundary must survive because other uses remain |
| Partial inline | Split a structured region into a smaller helper first, then inline that helper |
| No action | Keep the call and callee as they are |

That action split is the easiest way to remember why this pass feels “bigger” than ordinary direct call substitution.

## Phase 5: partial inlining is a real second algorithm

If direct inlining is not chosen, Binaryen may still partially inline a function.

This uses `FunctionSplitter::FlexSplitter` from `FunctionSplitter.cpp`.

The high-level story is:

1. find a structured region whose call-carrying fragment is profitable to peel out
2. split that fragment into a helper function
3. inline the helper where it now pays off better than the original whole function did

The helper source shows that this is intentionally structured and conservative. The splitter is designed around shapes like:

- `if`
- `br_if`
- `select`
- straight-line regions with a clear split point

The splitter also tries to preserve:

- branch targets
- fallthrough meaning
- useful return shapes
- profitability discipline

So a faithful Starshine port will likely need an actual structured splitter helper rather than trying to bolt partial inlining onto a direct inline rewrite.

## Phase 6: rewrites update the module, not just the caller body

After Binaryen chooses inline actions, it updates state such as:

- remaining call counts
- surviving uses
- which callees are now removable
- which callers were modified and should be optimized afterward

That means the pass behaves more like:

- scan
- plan
- mutate
- refresh module state
- maybe plan more

than like a one-shot scan over a frozen call graph.

## Phase 7: `optimizeAfterInlining(...)` is the real contract behind `optimizing`

`opt-utils.h` makes the post-inline helper explicit.

`OptUtils::optimizeAfterInlining(...)`:

1. optionally validates before the nested run in pass-debug mode
2. creates a `FilteredPassRunner` for only the touched functions
3. marks the runner nested
4. prepends `precompute-propagate`
5. reruns the default function optimization pipeline
6. optionally validates afterward in pass-debug mode

That means the optimizing variant is designed to immediately cash in on fresh opportunities created by inlining, including:

- constant propagation
- dead local cleanup
- dead branch cleanup
- cast cleanup
- code folding and block merging
- redundant-set cleanup

The later cleanup is not optional polish. It is part of the intended behavior.

## Saved `-O4z` log evidence

The saved local `-O4z` debug log shows that the top-level `inlining-optimizing` line expands into several nested reruns before Binaryen moves on to top-level `duplicate-function-elimination`.

Repo-local counting over that interval finds:

- `5` nested `ssa-nomerge`
- `5` nested `code-folding`
- `10` nested `local-cse`
- `10` nested `merge-blocks`
- `15` nested `precompute-propagate`

Those numbers are a useful reminder that the pass is not “replace call, then stop.”

## Important helper dependencies

## `CostAnalyzer`

Used to estimate body size and call-overhead tradeoffs. This is the heart of the pass’s size/profitability reasoning.

## `PossibleContents`

Used to approximate what function values may flow into ref-based callsites. This is what makes some `call_ref` / `return_call_ref` opportunities visible.

## `FunctionSplitter::FlexSplitter`

Provides the structured split helper that partial inlining relies on.

## `FilteredPassRunner`

Gives the optimizing variant a way to rerun cleanup only on touched functions instead of the whole module.

## `ReFinalize` / builder-side refinalization

Required because inlining and splitting rebuild and reconnect expressions in a way that changes local typing and control-flow shapes.

## Shipped test coverage worth remembering

`test/lit/passes/inlining.wast` is worth rereading whenever the pass seems simpler than it is.

The test covers:

- plain vs optimizing variants
- tiny-threshold tuning
- partial inlining through `--partial-inlining-ifs`
- export/root preservation
- ref-based call shapes
- loop/return/control corner cases

## Future Starshine port checklist

- Model `inlining-optimizing` as a module pass with function summaries, not a function-local peephole.
- Preserve root/escape conservatism for exports, start, and other uninlineable uses.
- Preserve the direct-call vs precise-ref-call distinction.
- Preserve the size heuristics, including call-overhead discount and single-use bias.
- Preserve tail-call and self-recursive growth guards.
- Preserve partial inlining as a distinct structured split strategy.
- Preserve the filtered nested rerun of `precompute-propagate` plus the default function optimization pipeline.
- Preserve the fact that deleting the callee is conditional on surviving uses, not automatic.
