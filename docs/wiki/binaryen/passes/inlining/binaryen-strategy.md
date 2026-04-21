---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ../inlining-optimizing/index.md
---

# Binaryen `inlining` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/Inlining.cpp`.
- Public registration and the plain-vs-optimizing split come from `src/passes/pass.cpp`, `src/passes/NoInline.cpp`, and `src/passes/opt-utils.h`.
- Heuristic defaults come from `src/pass.h`.
- Compilation-hint storage and parsing come from `src/wasm.h`, `src/wasm/wasm.cpp`, `src/wasm/wasm-binary.cpp`, and `src/parser/contexts.h`.
- The most important helper contracts come from:
  - `src/ir/branch-hints.h`
  - `src/ir/branch-utils.h`
  - `src/ir/drop.h`
  - `src/ir/eh-utils.h`
  - `src/ir/find_all.h`
  - `src/ir/literal-utils.h`
  - `src/ir/localize.h`
  - `src/ir/metadata.h`
  - `src/ir/module-utils.h`
  - `src/ir/module-utils.cpp`
  - `src/ir/names.h`
  - `src/ir/properties.h`
  - `src/ir/return-utils.h`
  - `src/ir/type-updating.h`
  - `src/ir/utils.h`
- The shipped behavior examples come from the `inlining*`, `no-inline*`, `inline-main`, and inline-hint lit tests.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/parser/contexts.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
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

## The pass in one sentence

Binaryen `inlining` is a late whole-module function-boundary rewrite pass that chooses profitable direct callsites, optionally splits two narrow `if`-driven function shapes first, copies callee bodies into callers with real control/local/type repair, and removes now-dead private helpers, but **does not** do the optimizing sibling's nested useful-pass rerun.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Build `FunctionInfo` summaries for every function | Inline profitability depends on whole-module facts, not only one call node |
| Classify | Decide `Full`, split pattern, or `Uninlineable` per function | Later planning should not recompute structural eligibility from scratch |
| Discover actions | Walk functions in parallel and collect reachable direct-call inline opportunities | Discovery is local to each caller but still uses module-wide callee facts |
| Choose actions | Filter sequentially for determinism and interaction safety | Avoid inline-into-and-inline-from races and giant-function blowups |
| Rewrite | Copy callee bodies into callers and repair locals, returns, labels, and types | Inline rewrites are structured IR surgery, not text substitution |
| Clean up | Remove now-dead callees and temporary split helpers | Inlining changes module topology |
| Optional optimize-after-inline | Only for `inlining-optimizing` | Harvest newly exposed simplifications immediately |

## Compilation hints versus actual no-inline policy

Binaryen `version_129` has two different “inline hint” surfaces that are easy to blur together.

### Preserved compilation-hint bytes

`src/wasm.h` defines `CodeAnnotation::inline_` plus the named values:

- `NeverInline = 0`
- `AlwaysInline = 127`

`src/wasm/wasm.cpp`, `src/parser/contexts.h`, and `src/wasm/wasm-binary.cpp` make `@metadata.code.inline` a real parsed-and-written annotation surface, and the dedicated `inline-hints*` tests prove those bytes roundtrip on expression sites and function annotations.

### Actual plain-`inlining` suppression knobs

That annotation is **not** what `Inlining.cpp` consults for full or partial inline suppression.
Instead, the pass reads the function booleans:

- `noFullInline`
- `noPartialInline`

Those are set by the separate wildcard-matching pass family in `src/passes/NoInline.cpp` and registered in `pass.cpp` as `no-inline`, `no-full-inline`, and `no-partial-inline`.

So the safe source-backed summary is:

- preserved `@metadata.code.inline` bytes are real metadata,
- but current Binaryen inliner policy uses separate function flags.

`test/lit/passes/no-inline.wast` is the best proof surface for the full-vs-partial split, and `test/lit/passes/no-inline-monomorphize-inlining.wast` plus `src/ir/module-utils.cpp` prove the flags survive cloning.

## Biggest naming fact

`pass.cpp` exposes both:

- `inlining`
- `inlining-optimizing`

and both come from the same `Inlining` pass class with a single `optimize` boolean.

So the plain pass is **not** a different algorithm file. It is the same planner and rewrite engine with the post-inline useful-pass rerun disabled.

## Another important scheduler fact

The default no-DWARF `-O` / `-Os` path uses `inlining-optimizing`, not plain `inlining`.

That means:

- this dossier is a deliberate upstream-only registry expansion,
- not a leftover open slot from the repo's current no-DWARF parity queue.

## Phase 1: `FunctionInfoScanner` is the first real algorithm

Before rewriting anything, Binaryen scans each function into a `FunctionInfo` record containing:

- `refs`
- `size`
- `hasCalls`
- `hasLoops`
- `hasTryDelegate`
- `usedGlobally`
- `trivialInstruction`
- `inliningMode`

Beginner takeaway:

- Binaryen chooses inlining from whole-module summaries, not from one callsite in isolation.

## What `refs` really means here

The scanner increments `refs` for:

- direct calls to the function
- `ref.func` uses of the function

So `refs` is not “number of direct callers” only. It is closer to:

- “how many direct or explicit-function-reference uses still keep this function relevant?”

That is why a function can inline into direct callers but still survive because a `ref.func` or table use remains.

## What `usedGlobally` really means here

After scanning, `prepare()` marks exports and the start function as globally used.

So a function can be profitable to inline and still be undeletable because external or implicit callers may still exist.

## Phase 2: `worthFullInlining(...)` is layered, not one threshold

The full-inline heuristic proceeds in a deliberate order.

### `try_delegate` blocks full inlining

`hasTryDelegate` immediately returns false in `version_129`.

This is a real pass boundary, not an accidental omission.

### Very small helpers inline immediately

If `size <= alwaysInlineMaxSize`, the function is full-inlineable.

`pass.h` sets the default `alwaysInlineMaxSize` to `2`.

### One-use helpers get special treatment

If:

- `refs == 1`
- `!usedGlobally`
- `size <= oneCallerInlineMaxSize`

then the function is full-inlineable.

By default `oneCallerInlineMaxSize = -1`, which effectively means Binaryen is willing to inline all such one-caller functions.

### Trivial shrinking wrappers always inline

If `trivialInstruction == Shrinks`, the function is full-inlineable even in shrink modes.

### Very large functions stop early

If `size > flexibleInlineMaxSize`, the pass returns false.

The default `flexibleInlineMaxSize` is `20`.

### Multi-use flexible cases depend on policy

Once Binaryen gets past the early always-inline cases, it becomes more conservative:

- any shrink-focused mode stops here
- optimize levels below `3` also stop here

### `MayNotShrink` trivial instructions inline only at heavy speed focus

Single-instruction wrappers whose callsite size may grow still inline under `-O3`-style settings.

### Remaining flexible cases must avoid calls and usually loops

The final case requires:

- no calls in the callee body
- and either no loops or `allowFunctionsWithLoops`

The default in `pass.h` leaves `allowFunctionsWithLoops = false`.

## Phase 3: “trivial instruction” is a real size class

Binaryen distinguishes:

- `TrivialInstruction::Shrinks`
- `TrivialInstruction::MayNotShrink`
- `TrivialInstruction::NotTrivial`

A function is `Shrinks` only if:

- the body is not control flow,
- every operand is a `local.get`,
- the locals appear exactly once,
- and they appear in order.

If the instruction is still tiny but uses constants or repeated/skipped locals, it becomes `MayNotShrink` instead.

This is why the official “trivial instruction” and “trivial call” test files matter: they teach a real heuristic class, not a cute optimization trivia case.

## Phase 4: actual inline planning is direct-call based in `version_129`

`Planner::visitCall(...)` adds an `InliningAction` only when all of the following hold:

- the callee is already classified inlineable
- the call is reachable enough to be worth rewriting
- the callee is not the current function itself

The reachability rule is subtle for `return_call`:

- a tail call is treated as unreachable only if one of its operands is unreachable
- an ordinary call uses the call node's own type

## Important direct-call-only correction

In `version_129`, the planner itself does **not** collect `call_ref` or `call_indirect` inline actions.

That matters because the file also contains `CallRef` / `CallIndirect` logic in the *updater*, which could be easy to overread.

The safe summary is:

- planning actual inlines is direct-call based in this release
- updater logic still knows how to repair `return_call_indirect` / `return_call_ref` that already exist inside copied code
- `FunctionInfoScanner` also omits indirect/ref calls from direct-recursion tracking on purpose

## Phase 5: `doCodeInlining(...)` is real IR surgery

Once a callsite is chosen, Binaryen does much more than “replace call with body.”

### It creates a fresh named wrapper block

The wrapper block gets a name derived from the callee and optional numeric hint.
Binaryen then checks for collisions against:

- branch targets inside the callee body
- branch targets inside the call operands, unless the call must be hoisted for a return-in-try case

### It remaps all callee locals onto new caller locals

For every local in the callee, the updater allocates a new local in the caller and records a mapping.

### It stores operands into mapped params first

The copied callee body sees param values through those new locals.

### It zeroes zeroable vars

Binaryen explicitly zeroes copied callee vars when their types have a zero value.
This matters because the inlined block might sit inside a loop, and repeated execution must still see the same initial-local semantics the original callee had.

Nonzeroable locals are skipped, because they cannot validly be read before a write anyway.

### It copies debug-ish metadata and body contents

The pass uses `ExpressionManipulator::copy(...)` plus `metadata::copyBetweenFunctions(...)`, then walks the copied body through the updater.

## Phase 6: returns become breaks

The updater rewrites:

- `return value` -> `br returnLabel value`
- `return` -> `br returnLabel`

This lets copied callee returns exit only the inlined body rather than the entire caller function.

## Phase 7: `return_call*` repair is subtle

If the original outer callsite was not already a return call, then nested `return_call`, `return_call_indirect`, or `return_call_ref` inside the copied callee body cannot keep returning from the whole caller.

Binaryen handles that by:

- converting them into ordinary calls
- collecting follow-up branch information
- then wrapping the function body so those repaired calls still branch out of the inlined body correctly

If the outer callsite *was* already a return call, Binaryen can keep nested return calls as return calls.

## Phase 8: return-call-inside-try uses `hoistCall`

A `return_call` inside a `try` is treated specially.
Binaryen cannot just inline it naively because branch targets in operands and try nesting can capture the wrong labels.

So it:

- wraps the original caller body in a fresh named block
- branches out of that original body after storing arguments
- sequences the inlined body afterward

This is one of the main reasons the tail-call test file matters.

## Phase 9: inlining unreachable callees must preserve trap reachability

Inlining can accidentally make an originally unreachable callsite look reachable if the copied body wraps an unreachable child in a typed block.

Binaryen compensates when the original call node was unreachable and not a return call by forcing the replacement to end in an explicit `unreachable` sequence.

The `inlining-unreachable.wast` file is the clearest official proof surface here.

## Phase 10: `updateAfterInlining()` owns mandatory repair

After inlining into a function, Binaryen always:

1. uniquifies labels with `UniqueNameMapper::uniquify(...)`
2. `ReFinalize()`s the function in module context
3. calls `TypeUpdating::handleNonDefaultableLocals(...)`

That last step is especially important for GC/nonnullable locals, as shown by `inlining-gc.wast`.

## Phase 11: partial inlining is narrow and opt-in

`FunctionSplitter` exists only when:

- `optimizeLevel >= 3`
- `shrinkLevel == 0`
- `partialInliningIfs > 0`

The default in `pass.h` leaves `partialInliningIfs = 0`.

So partial inlining is off by default and only exists in heavier speed-oriented configurations.

## Pattern A

Pattern A looks for a function that begins with:

```wat
(if (simple) (then (return)))
```

followed by heavier later work.

The splitter can build:

- an `inlineable-A` function that contains only the guard and a call to an outlined helper
- an `outlined-A` function that contains the later work

## Pattern B

Pattern B is a short run of top-level `if`s followed by an optional final simple item.

Key gates include:

- only a small number of initial `if`s, bounded by `partialInliningIfs`
- every condition must be simple
- no else arms
- each `if` body must either be `unreachable` or `none` with no returns
- any final item must be simple
- locals written inside those `if` bodies cannot be read by the final item

This is a deliberately narrow source-backed family, not arbitrary CFG extraction.

## What “simple” means here

For `FunctionSplitter::isSimple(...)`, Binaryen accepts only a tiny set:

- `local.get`
- `global.get`
- unary wrappers around simple expressions
- `ref.is_null` of a simple expression

Unreachable expressions are not simple.

So even partial-inlining guards have a strict expression-shape budget.

## Phase 12: splitting can return `Full`

If the would-be outlined piece is itself worth normal full inlining, the splitter returns `InliningMode::Full` instead of a split mode.

That avoids useless intermediate work where Binaryen would:

- split now,
- then full-inline the small remainder later,

and end up with the same final result.

## Phase 13: iteration policy is conservative and deterministic

The pass runs iterative waves, but several limits keep it bounded.

### Bounded outer loop

Binaryen stops after more than the original function count in iterations.

### Per-name repeat cap

It also tracks per-function-name repeated operations and stops when any such name reaches `5` iterations of repeated work.

### Parallel discovery, sequential choice

Discovery of opportunities is parallel.
Choice of which actions to actually perform is sequential and deterministic over a saved function-name order.

### No inline-into and inline-from races in one iteration

If a function has been inlined into, Binaryen will not also inline *that same function* elsewhere in the same iteration.

### Giant-function protection

Chosen actions must satisfy `isUnderSizeLimit(...)`, which uses `maxCombinedBinarySize`.

## Phase 14: the optimizing sibling differs by exactly one nested extra step

Inside `iteration(...)`, Binaryen always runs the actual `DoInlining` pass for chosen actions.

Only when `optimize = true` does it also call:

- `OptUtils::addUsefulPassesAfterInlining(runner)`

and that helper means:

- prepend `precompute-propagate`
- then run the default function-optimization pipeline

So the clean public split is:

- `inlining` = inline and repair
- `inlining-optimizing` = inline, repair, then immediately clean up the touched functions further

## Phase 15: dead private callees and split helpers are removed later

After actions finish, Binaryen removes functions for which:

- all counted uses were just inlined away
- and `usedGlobally` is false

If splitting was used, `FunctionSplitter::finish()` also removes the temporary inlineable helper functions it created.

This is why inlining is a module-shape pass rather than only a caller-body pass.

## Practical porting rules for Starshine

A future Starshine port must preserve at least these source-backed rules:

- plan actual inline actions from reachable direct callsites only, unless newer upstream source is intentionally targeted
- count `ref.func`, export, and start uses separately from easy inlineable direct callers
- keep the layered trivial/one-caller/flexible heuristic structure
- preserve `try_delegate` conservatism
- preserve the exact split between plain and optimizing variants
- repair returns, labels, nondefaultable locals, and reachability after every inline
- keep split inlining limited to the two source-backed top-of-function `if` families
- keep the deterministic action-choice model and the iteration caps

## What beginners most often get wrong

- The pass is not on the repo's current default no-DWARF parity path; only `inlining-optimizing` is.
- `version_129` planning is direct-call based, not general `call_ref` planning.
- Partial inlining is not arbitrary CFG extraction.
- Inlining a callee does not automatically delete the callee declaration.
- The optimizer variant's nested rerun is not optional polish; it is the main public semantic split from plain `inlining`.
