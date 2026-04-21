# Binaryen `propagate-globals-globally` research

Date: 2026-04-21
Status: source-backed upstream-only dossier expansion
Pass: `propagate-globals-globally`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Campaign context: the original no-DWARF / saved-`-O4z` queue and the first widened upstream-only queue are already dossier-covered, so this note deliberately expands the tracker again using a source-backed registry candidate that is already named locally and already matters to nearby global-pass docs.

## 1. Why this pass is an eligible campaign target

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

The main parity queue is already dossier-covered, and the earlier tracker expansion queue is dossier-covered too.
So this thread needed either:

- a major-gap fallback in an already-deep folder, or
- a new source-backed upstream-only registry candidate.

I chose the second path.

`propagate-globals-globally` is a good candidate because:

1. it is already a named local boundary-only registry entry in `src/passes/optimize.mbt`
2. the current `simplify-globals`, `simplify-globals-optimizing`, and `string-gathering` dossiers already refer to it as a meaningful neighboring pass/test surface
3. it sits directly beside already-covered late global passes, so better docs help future Starshine work
4. it still had no dedicated folder under `docs/wiki/binaryen/passes/`
5. `agent-todo.md` currently has **no dedicated `propagate-globals-globally` slice**

That means this is not a random side quest. It is a real local-registry pass surface with a real documentation gap.

## 2. Source inventory reviewed for this note

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- `docs/wiki/raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`
- `docs/wiki/raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/PropagateGlobals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PropagateGlobals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `test/lit/passes/propagate-globals-globally.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>

## 3. The main conclusion in one paragraph

Binaryen `propagate-globals-globally` is a small late **module pass** that specializes in one very specific kind of cleanup: startup-time constant propagation **between globals and other top-level startup expressions**. It is not a general code propagation pass, not a global DCE pass, and not the same as full `simplify-globals`. The reviewed `version_129` implementation only chases values that are safe to treat as startup constants, rewrites later globals and segment/table offset expressions when those values become known, and then stops. It deliberately leaves function bodies alone. That smaller contract is why the pass is easy to miss, but it is also why it is a good beginner-facing dossier target: it teaches the startup-global half of the broader late global pipeline cleanly.

## 4. Registry and scheduler placement

## Upstream registration

`pass.cpp` publicly registers `propagate-globals-globally` as its own pass name.

Important scheduler fact:

- it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path page
- it is **not** part of the saved generated-artifact `-O4z` skipped-slot queue
- it is therefore an **upstream-only registry expansion target**, not a leftover parity-queue pass

## Local registry placement

`src/passes/optimize.mbt` already tracks `propagate-globals-globally` as `boundary-only`.
That local fact is what makes this expansion justified for this campaign.

## 5. What the pass actually does

A beginner-friendly summary is:

1. inspect module-level startup expressions
2. discover globals whose values are already known at startup
3. substitute those known values into later top-level startup expressions that read them
4. repeat while that unlocks more startup-time constants
5. do **not** rewrite ordinary function code

The easiest way to say it accurately is:

- this is **startup global propagation**, not broad global simplification

## 6. What the pass does *not* do

This mattered a lot in the source review because the name can mislead people.

It does **not**:

- remove unused globals by itself
- fold arbitrary runtime `global.get` uses in function bodies
- run effect-sensitive current-trace propagation through ordinary instructions
- do the full `read-only-to-write` cleanup surface of `simplify-globals`
- do the optimizing sibling's nested rerun behavior

The cleanest contrast comes from the dedicated lit test and the neighboring simplify-globals research already in the repo:

- `propagate-globals-globally` updates later globals and startup offsets
- `simplify-globals` and `simplify-globals-optimizing` go further and may also rewrite code

## 7. Implementation structure

The reviewed `version_129` implementation lives in `src/passes/PropagateGlobals.cpp`.

The key structural takeaway is that this pass is a **module-level startup-expression rewriter**, not a function walker.

From the reviewed source and test surface, the important implementation ideas are:

- collect propagatable global values from top-level declarations
- use declaration/order-safe startup expressions only
- rewrite later globals when their initializer depends on an already-known global
- rewrite active segment or element offsets when those offsets depend on an already-known global
- stop once the startup graph is simplified

### Inference note

The exact local helper names inside the file are less important than the contract above.
The durable source-backed teaching point is the pass boundary:

- **module startup expressions only**
- **later top-level expressions only**
- **no function-body propagation**

## 8. Important helper surface and dependency story

This pass appears intentionally lightweight compared with the nearby `simplify-globals*` family.

What it appears to depend on most heavily:

- module-level traversal over globals and startup segment metadata
- constant-expression recognition / rebuilding
- ordinary Binaryen module rewriting utilities

What it notably does **not** appear to require as a central concept:

- effect summaries over function bodies
- CFG reasoning
- branch utilities
- liveness
- dominance
- nondefaultable-local repair

That distinction matters for future Starshine planning:

- if Starshine ports this pass, it should probably live near module-level declaration rewriting, not in the hot function pipeline

## 9. Source-backed shape families that matter

## Positive shapes

### Global chain propagation

A later immutable global can be simplified when its initializer depends on an earlier global whose value is already known.

Conceptually:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (global.get $a))
```

becomes closer to:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (i32.const 10))
```

### Startup offset propagation

Active data/elem offsets that read a known startup global can be rewritten to a more direct constant expression.

Conceptually:

```wat
(global $off i32 (i32.const 8))
(data (global.get $off) "abc")
```

becomes closer to:

```wat
(global $off i32 (i32.const 8))
(data (i32.const 8) "abc")
```

### String/global startup exposure

The neighboring `string-gathering` dossier already made this point, and the dedicated `propagate-globals-globally.wast` test supports it:

- startup propagation can expose cleaner string/global shapes for later late-global passes

That is an interaction worth keeping explicit.

## Negative or bailout shapes

### Ordinary function-code `global.get`

If the use is in executable function code rather than another startup-time top-level expression, this pass stops.
That is for full `simplify-globals*`, not for this pass.

### Runtime writes / mutable-global semantics

If a value is not a safe startup constant anymore, the propagation story stops.
The pass is about startup-time certainty, not runtime dataflow.

### Non-startup side-effectful rewrites

Anything that would require ordinary instruction-level effect reasoning is outside this pass boundary.

## 10. What beginners are most likely to misunderstand

### Misunderstanding 1: “This is just another name for simplify-globals.”

No.

A better mental model is:

- `propagate-globals-globally` = startup-only global-to-global and offset propagation
- `simplify-globals` = broader late global cleanup and propagation
- `simplify-globals-optimizing` = that broader pass plus nested reruns on changed functions

### Misunderstanding 2: “Globally” means all code everywhere.

No.

Here “globally” means:

- across module-level startup declarations and startup expressions

not:

- across all function bodies in the whole program

### Misunderstanding 3: “If this pass fires, later global passes become redundant.”

Also no.

This pass is smaller and more surgical.
It is a good feeder pass or a good isolated diagnostic surface, not a replacement for the wider late global cleanup cluster.

## 11. Scheduler and pass-interaction notes

The strongest nearby interactions visible from local repo docs and official test context are:

- `simplify-globals`
- `simplify-globals-optimizing`
- `string-gathering`
- `reorder-globals`

The durable interaction story is:

1. startup propagation can simplify later globals and offsets
2. that can expose cleaner module-global shapes for later whole-module cleanup
3. string/global canonicalization later in the pipeline benefits from those simpler startup expressions

This pass is therefore best taught as part of the **late global module-pass neighborhood**, even though it is smaller than the better-known siblings.

## 12. What a future Starshine port must preserve

If Starshine ever ports this pass, the key contract to preserve is:

1. module-pass scope, not hot-function scope
2. startup-expression-only rewrite boundary
3. safe propagation only from values known at startup
4. rewrite of later globals and startup offsets, not arbitrary function-body uses
5. honest separation from the larger `simplify-globals*` behavior

A port that silently propagates into ordinary function code would no longer be this pass.
A port that refuses to touch startup offsets would be missing an important visible part of the pass contract.

## 13. Why this dossier improves the wiki

This fills a real gap between existing pages.
Before this note:

- the wiki already explained full `simplify-globals*`
- the wiki already mentioned `propagate-globals-globally`
- but there was no dedicated canonical home explaining what the smaller pass actually is

Now there is a stable place to answer:

- why the pass exists separately
- what it really rewrites
- what it does not rewrite
- why it helps the late global pipeline without being the full global simplifier

## 14. Open questions and uncertainty labels

### Strong conclusions

These points are strongly supported by the reviewed sources:

- the pass is publicly registered in Binaryen `version_129`
- it is tracked locally as `boundary-only`
- it is not in the repo's current no-DWARF / saved-`-O4z` queue
- it is a dedicated startup-propagation pass distinct from full `simplify-globals`
- the dedicated lit file exists to contrast that smaller contract

### Explicit inferences

These are reasonable but still partly inferential summaries from the reviewed implementation shape:

- the exact internal fixed-point organization should be taught as “iterative startup propagation” rather than over-specifying helper names
- the most durable helper story is module-level constant-expression rewriting rather than any heavyweight analysis framework

Those inferences are good enough for wiki teaching, but future source-deepening can refine the exact helper inventory if needed.

## 15. Final recommendation

Mark `propagate-globals-globally` as a real upstream-only registry dossier target and keep it separate from the `simplify-globals*` pages.

The pass is small, but it is not trivial:

- it clarifies the startup-time half of late global cleanup,
- it explains a recurring official test name already cited elsewhere in the wiki,
- and it gives future Starshine work a much clearer boundary for any eventual module-pass port.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- `docs/wiki/raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`
- `docs/wiki/raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PropagateGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
