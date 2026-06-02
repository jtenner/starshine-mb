---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-05-23-inlining-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/index.md
---

# Binaryen `inlining` Strategy

## Source rule

Use Binaryen `version_129` as the tagged oracle for this dossier; Binaryen's public release horizon now reaches `version_130`, but the 2026-05-23 current-main recheck still recorded no teaching-relevant drift in the inlining surfaces. The core implementation is `src/passes/Inlining.cpp`; public registration and the plain-vs-optimizing split come from `src/passes/pass.cpp` and `src/passes/opt-utils.h`; heuristic defaults come from `src/pass.h`; no-inline policy comes from `src/passes/NoInline.cpp`; clone-surviving no-inline flags come from `src/ir/module-utils.cpp`.

Primary upstream URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>

## One-sentence contract

Binaryen `inlining` is a late whole-module function-boundary pass that classifies functions with module-wide facts, chooses profitable reachable direct callsites, optionally splits two narrow top-of-function conditional families first, copies callee bodies into callers with local/control/type repair, removes only now-dead private helpers, and stops before the optimizing sibling's nested cleanup rerun.

## Phase table

| Phase | What Binaryen does | Why it matters |
| --- | --- | --- |
| Scan | Build `FunctionInfo` summaries for every function | Profitability and deletion depend on module-wide facts, not only one call node |
| Classify | Cache `Full`, split pattern, or `Uninlineable` mode | Later callsite planning should not redo structural checks |
| Discover | Collect reachable direct `call` / `return_call` actions | Reviewed `version_129` chosen-action surface is intentionally narrower than arbitrary indirect calls |
| Filter | Choose actions deterministically and avoid same-wave races | Prevent inline-into/inline-from conflicts, recursive blowups, and giant combined functions |
| Rewrite | Copy callee body into caller | Requires local, return, tail-call, label, reachability, and type repair |
| Cleanup | Remove dead private helpers and temporary split helpers | Inlining changes the function graph, not just one expression |
| Stop | Do not run nested useful passes | This is the public split from `inlining-optimizing` |

## 1. `FunctionInfoScanner` is the real first algorithm

The scanner computes facts such as:

- reference count (`refs`);
- estimated body size;
- whether the function has calls, loops, `try_delegate`, or tail-call forms;
- whether it is globally used by export/start status;
- whether it is trivially shrinking, maybe-growing, or not trivial;
- cached inline mode.

`refs` includes direct calls and `ref.func` uses. Exports and the start function set global/root use during preparation. Those facts make three outcomes distinct:

1. inline a callsite and delete the callee;
2. inline a callsite and keep the callee alive;
3. do not inline at all.

A local port that treats “one direct call” as “one total use” will delete rooted functions incorrectly.

## 2. Full-inline profitability is layered

Binaryen does not use one flat “max inline size” rule.

1. `try_delegate` rejects full inlining in the reviewed contract.
2. `size <= alwaysInlineMaxSize` accepts tiny helpers; `pass.h` default is `2`.
3. `refs == 1 && !usedGlobally && size <= oneCallerInlineMaxSize` accepts one-use private helpers; the default `-1` acts as an effectively unbounded one-caller threshold.
4. `TrivialInstruction::Shrinks` accepts wrappers that provably shrink.
5. `size > flexibleInlineMaxSize` rejects large flexible cases; default is `20`.
6. Shrink-focused modes and optimize levels below `3` stop before aggressive flexible cases.
7. `TrivialInstruction::MayNotShrink` is accepted only under heavier speed focus.
8. Remaining flexible cases require no calls and either no loops or `allowFunctionsWithLoops`.

The result is policy-sensitive optimization, not a proof that every small function must inline.

## 3. Trivial-instruction classes are semantic policy, not trivia

A shrinking trivial wrapper is a one-instruction non-control body whose operands are parameter `local.get`s in exact order and exact single-use form. It always shrinks because the call boundary disappears without needing extra operand scaffolding.

A maybe-growing trivial wrapper is still tiny but can use constants, skipped locals, or repeated locals. It may require drops or temps, so Binaryen takes it mainly in speed-oriented settings.

The official `inlining-trivial-instructions.wast` and `inlining-trivial-calls-1.wast` files are the best proof surfaces for this distinction.

## 4. Reviewed `version_129` action planning is direct-call based

The most important correction for this dossier is scope:

- chosen inline actions are planned from reachable direct `call` / `return_call` sites;
- the planner skips self-inlining at the current function;
- ordinary calls use the call node's reachability/type, while `return_call` reachability is affected by unreachable operands;
- `call_ref` / `call_indirect` logic in the file is repair/survival-adjacent, not the main chosen-action planner surface in the reviewed release.

So the safe implementation first slice is direct calls, not broad precise-ref-call inlining. Future widening should cite a newer upstream source ingest.

## 5. `doCodeInlining(...)` is structured IR surgery

The low-level rewrite must preserve the callee-frame illusion inside the caller.

### Fresh wrapper block

Binaryen wraps copied code in a fresh named block derived from the callee name and optional numeric hint. It checks for branch-label collisions against copied callee labels and call operand labels, with special handling when the call must be hoisted out of a `try`.

### Callee locals become fresh caller locals

Every callee param and body local is mapped to a newly allocated caller local. Call operands are evaluated and stored into the mapped params before the copied body runs.

### Zeroable locals are reinitialized

Defaultable copied vars are explicitly reset to zero values. This preserves separate-call-frame semantics when the inlined body is inside a loop. Nondefaultable locals are not fake-zeroed; they are handled by later type/local repair.

### Metadata and body copy

Binaryen copies expression contents and metadata, then runs the updater over the copied body.

## 6. Returns become local exits

Copied `return` instructions cannot return from the caller unless the original control says so. Binaryen rewrites:

- `return value` to `br returnLabel value`;
- `return` to `br returnLabel`.

This is why the wrapper block's result type and label are part of correctness.

## 7. Tail-call behavior is subtle

There are three separate tail-call concerns.

1. A direct outer `return_call` can itself be a chosen inline action if the callee is otherwise eligible.
2. Nested `return_call`, `return_call_indirect`, or `return_call_ref` inside a copied callee body must be downgraded/repaired when the outer site was not itself a return-style call, so they do not accidentally return from the whole caller.
3. A `return_call` inside a `try` can require `hoistCall`: Binaryen wraps the original caller body in a fresh block, stores operands, branches out, and sequences the inlined body after the original try-sensitive region.

Tail calls are therefore not just ordinary tiny helper bodies. Future Starshine widening should either implement the repair exactly or skip those shapes conservatively.

## 8. Unreachable/trap reachability must be preserved

If an unreachable callee is copied into a typed wrapper block, the wrapper can accidentally make the surrounding expression look reachable. Binaryen compensates for unreachable original callsites by forcing explicit unreachable structure where needed. `inlining-unreachable.wast` is the clearest proof surface.

## 9. Post-inline repair is mandatory

After an inline, Binaryen runs repair over touched functions:

1. uniquify labels;
2. refinalize the function;
3. handle nondefaultable locals;
4. repair EH nested-pop structure where needed.

The GC/nonnullable-local test exists because copied locals can invalidate a function even when the value semantics look right.

## 10. Partial inlining is narrow and opt-in

`FunctionSplitter` exists only under heavier speed settings:

- `optimizeLevel >= 3`;
- `shrinkLevel == 0`;
- `partialInliningIfs > 0`.

The default `partialInliningIfs = 0`, so ordinary default plain inlining does not split.

### Pattern A

A function begins with a simple guard that returns early:

```wat
(if (simple-condition)
  (then (return ...)))
;; heavier later work
```

Binaryen can build an inlineable guard wrapper plus an outlined remainder.

### Pattern B

A function starts with a short run of top-level simple `if`s:

- simple conditions only;
- no else arms;
- bounded count by `partialInliningIfs`;
- bodies are unreachable or none-typed without returns;
- any final item is simple;
- locals written in if bodies are not read by that final item.

This is structured source splitting, not arbitrary CFG extraction.

## 11. Iteration is bounded and deterministic

Binaryen runs waves, but guards them:

- stop after more iterations than the original function count;
- stop repeated per-function-name work at `5` iterations;
- discover actions in parallel but choose sequentially over a stable function order;
- avoid inlining into a function and also inlining that same function elsewhere in the same wave;
- enforce `maxCombinedBinarySize` using the default `400 * 1024` limit.

This explains why Starshine's iterative waves are directionally right but not yet exact parity.

## 12. Dead-helper cleanup is conditional

Binaryen removes functions only when all counted uses were rewritten away and the function is not globally/root used. Split helper cleanup is separate. Exported, start, tabled, or `ref.func`-used functions may inline into direct callers and still survive.

## 13. Plain versus optimizing

Inside the shared engine, plain `inlining` does not call `OptUtils::addUsefulPassesAfterInlining(...)` / `optimizeAfterInlining(...)`. The optimizing sibling does, and that helper prepends `precompute-propagate` before running the default function pipeline on changed functions.

Therefore:

- `inlining` = inline + repair + helper cleanup;
- `inlining-optimizing` = same + filtered nested useful-pass rerun.

## Porting rules for Starshine

A faithful port must preserve:

- whole-module summaries before mutation;
- direct-call chosen-action scope unless a newer upstream source widens it;
- roots and `ref.func` survival;
- layered heuristics and `try_delegate` conservatism;
- local/label/return/tail-call/type repair;
- nondefaultable-local repair;
- exact plain-vs-optimizing stop point;
- partial inlining only after Pattern A/B proof;
- helper deletion only after surviving roots/refs are rechecked;
- separate classification of Binaryen/tool parse failures versus Starshine semantic mismatches.
