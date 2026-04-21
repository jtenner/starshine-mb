---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ../inlining-optimizing/index.md
---

# `inlining`: heuristics, splitting, and plain-vs-optimizing

This page focuses on the parts of Binaryen `inlining` that are easiest to misunderstand.

## The big beginner warning

If you summarize the pass as:

- “inline every small function”

you will miss most of the implementation.

The real story is closer to:

- “scan the whole module, classify each function with layered heuristics, choose only safe direct callsites, sometimes split two narrow `if`-driven function shapes first, repair the caller carefully, and only then decide whether more optimization should rerun.”

## 1. Plain and optimizing are not the same public contract

The two passes share the same engine, but they do not have the same public behavior.

## Plain `inlining`

It:

- scans
- plans
- rewrites
- refinalizes / repairs
- removes dead helpers

and then stops.

## `inlining-optimizing`

It does all of that, then additionally:

- prepends `precompute-propagate`
- reruns the default function-optimization pipeline on the touched functions only

That means the optimizing suffix is not just a marketing adjective.
It is the scheduler-significant semantic difference between the two public pass names.

## 2. `version_129` actual planning is direct-call based

This is the easiest detail to overread from the source file.

The file contains logic for `CallIndirect` and `CallRef`, but that does **not** mean those are planned as inlineable callsites in the same way as ordinary `Call`.

The safe `version_129` summary is:

- actual inline **selection** is built from reachable direct `call` / `return_call` sites
- `CallRef` / `CallIndirect` are still relevant in repair code and in “keep the boundary alive” reasoning
- but they are not the main planner's actual chosen-action surface in this release

If a future port widens beyond that, it should do so deliberately against newer upstream source, not by assumption.

## 3. “One caller” is not the same as “one direct call”

`refs` includes `ref.func` uses as well as direct calls.

So a function that appears to have one direct caller may still fail the “one use” intuition if it is also:

- tabled
- referenced elsewhere through `ref.func`
- exported
- or the start function

That is why Binaryen can inline into some callers and still keep the callee around.

## 4. Trivial wrappers are a special family

Binaryen does not treat all small functions equally.

## `Shrinks`

A one-instruction wrapper whose operands are the params in exact order always shrinks when inlined.

## `MayNotShrink`

A one-instruction wrapper that uses constants, skips locals, or repeats locals is still tiny, but inlining may create:

- drops
- extra temps
- or larger encodings

So Binaryen only takes those fully at heavier speed settings.

This is why the trivial-wrapper tests deserve explicit teaching space.

## 5. `try_delegate` is a real blocker

The worth-inlining heuristic rejects functions with `try_delegate` outright in `version_129`.

That is a real source-backed limitation, not just a missing test.

A future port must either preserve that bailout or justify a stronger replacement.

## 6. Loop avoidance is policy, not a parser rule

Loops do not make inlining impossible forever.

Instead, Binaryen's default heuristic says:

- loops usually imply heavier work where call overhead matters less,
- so do not inline loop-containing functions by default.

`pass.h` exposes that as `allowFunctionsWithLoops`, which defaults to false.

So the rule is:

- conservative by default,
- configurable in principle.

## 7. Partial inlining is a different strategy, not “half an inline”

When full inlining is not chosen, Binaryen may still partially inline.
But partial inlining does **not** mean:

- “copy some arbitrary subset of the callee body.”

It means:

- split out a narrow top-of-function shape into `inlineable` and `outlined` pieces,
- then inline the `inlineable` piece using the normal mechanism.

That is a structured source transformation, not a generic graph cut.

## 8. Pattern A: early guard then heavy work

Pattern A matches the mental shape:

```wat
(func $f (param $x i32)
  (if (local.get $x)
    (then (return))
  )
  ;; heavy later work
)
```

Binaryen can outline the heavy later work and inline just the guard logic.

That is profitable because:

- constants can kill the guard entirely,
- and dynamic false cases can avoid the call overhead.

## 9. Pattern B: a short ladder of top-level ifs

Pattern B is not “many ifs anywhere.”
It is a specific body shape:

- a small run of top-level `if`s,
- simple conditions,
- no else arms,
- no dangerous final-item local dependency.

This is why the local-written / final-item-read check exists.

Without that restriction, splitting could silently change the relationship between the `if` bodies and the later final item.

## 10. Simple conditions are really simple

For split inlining, “simple” currently means only tiny expression families like:

- `local.get`
- `global.get`
- unary wrappers over simple values
- `ref.is_null` over simple values

So even though the overall pass is called `inlining`, its split optimizer is much more of a shape recognizer than a general cost-model pass.

## 11. No-full-inline and no-partial-inline controls matter

The official tests prove that Binaryen honors command-line controls that can block:

- full inlining only
- partial inlining only
- both

And the source confirms those are not abstract policy names: `NoInline.cpp` sets the exact `noFullInline` / `noPartialInline` function booleans that `Inlining.cpp` later consults.

That matters for beginners because it means the pass behavior is not just “whatever the heuristic wants.”
It also has explicit policy gates.

## 12. No-inline metadata can survive through other transforms

The `no-inline-monomorphize-inlining.wast` test proves a subtle rule:

- if a transform creates a new copy of a function, no-inline intent can still apply to that copy

The source-backed reason is `ModuleUtils::copyFunction`, which copies `noFullInline` and `noPartialInline` onto the cloned function.

This is an important future-port lesson:

- inlining policy may be attached to function identity/metadata, not just recomputed from body shape alone.

## 13. Preserved `@metadata.code.inline` bytes are a separate mechanism

Binaryen also has a real `@metadata.code.inline` annotation surface, with one-byte values like `"\\00"`, `"\\01"`, `"\\7e"`, and `"\\7f"` roundtripped by the dedicated `inline-hints*` tests.

But that is a different mechanism from the practical `no-inline*` policy flags used by `Inlining.cpp`.
If you need the exact source-confirmed split, see [`./compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md).

## 14. `inline-main` is not the same pass, but it proves reuse of the primitive

`inline-main` is a tiny special-case pass, not the main planner.
But it matters here because it shows Binaryen's low-level inline rewrite helper is reusable outside the full heuristic engine.

That is a useful design clue for a future Starshine port:

- keep the rewrite primitive separate enough that special-case passes can reuse it.

## 15. Good mental model for future Starshine work

If you need one short planning summary, use this:

- classify first,
- plan direct callsites only,
- preserve roots and refs,
- split only the two source-backed `if` families,
- repair locals, labels, and reachability carefully,
- then decide separately whether you want the optimizing wrapper's nested rerun.

That is much closer to real Binaryen behavior than the simpler but misleading slogan:

- “inline small functions.”
