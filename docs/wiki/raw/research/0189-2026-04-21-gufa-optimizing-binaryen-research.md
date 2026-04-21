# Binaryen `gufa-optimizing` research

Date: 2026-04-21
Status: completed research note
Pass: `gufa-optimizing`
Upstream baseline: Binaryen `version_129`

## Why this note exists

The main no-DWARF queue and the first upstream-only expansion wave were already dossier-covered before this thread.
The tracker therefore no longer had an obvious `wiki status = none` candidate inside the original parity queues.
I re-checked the local registry in `src/passes/optimize.mbt` and found that it still exposes the public upstream variant `gufa-optimizing`, but the living wiki only had a family-level `gufa/` folder, not a dedicated dossier for this exact pass name.

That makes `gufa-optimizing` a justified tracker expansion:

- it is a real local boundary-only registry name
- it is a real public Binaryen pass name in `version_129`
- it has dedicated upstream lit coverage
- it is easy to mis-teach as “just GUFA with a different aggressiveness knob” when its real contract is a nested cleanup rerun on modified functions

## Inputs consulted

Repo docs / tracker / local registry:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- existing `docs/wiki/binaryen/passes/gufa/*`

Official Binaryen `version_129` sources:

- `src/passes/GUFA.cpp`
- `src/passes/pass.cpp`
- `src/ir/possible-contents.h`
- `test/lit/passes/gufa-optimizing.wast`
- `test/lit/passes/gufa.wast`
- `test/lit/passes/gufa-cast-all.wast`
- release tag `version_129`

## Tracker / backlog status before doing the work

- `agent-todo.md` has **no dedicated `gufa-optimizing` slice**.
- The pass is **not** part of the current canonical no-DWARF `-O` / `-Os` path documented in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`.
- The pass also does **not** appear in the saved generated-artifact `-O4z` skipped-pass queue.
- This is therefore an upstream-only registry expansion, not a parity-queue pass.

## Main conclusion in one sentence

`gufa-optimizing` is the same whole-program `ContentOracle`-driven rewrite engine as plain `gufa`, but with `optimizing = true`, which means that after GUFA proves new constants or unreachability and refinalizes the changed function, Binaryen immediately reruns local `dce` and `vacuum` on that modified function to remove the new wrapper, `drop`, dead-result, and repeated-`unreachable` debris the proof-based rewrite can create.

## Beginner-friendly mental model

Plain `gufa` says:

- “I proved this site can only hold one value or no value, so I will rewrite the site.”

`gufa-optimizing` says:

- “I proved that, **and then** I will immediately clean up the extra scaffolding my proof inserted.”

So this is not a different analysis.
It is a different **post-rewrite contract**.

## What matters in `GUFA.cpp`

### 1. The file comment already defines the sibling split

At the top of `GUFA.cpp`, upstream says GUFA can increase code size when it inserts constants and `unreachable`, and that the “optimizing” variant will automatically run followup opts in functions where it made changes.

That top-level comment is not fluff.
It is the public reason the sibling exists.

### 2. The pass family is one engine with two booleans

`GUFAOptimizer` stores:

- `bool optimizing`
- `bool castAll`

and `GUFAPass` constructs one engine with one of three settings:

- plain `gufa` => `(false, false)`
- `gufa-optimizing` => `(true, false)`
- `gufa-cast-all` => `(false, true)`

So `gufa-optimizing` is not a forked implementation.
It is the same engine with one flag flipped.

### 3. The actual rewrite logic is still plain GUFA logic

The generic and dedicated visitors are the same family logic already described in the broader `gufa` dossier:

- skip constants / tuples / unreachable / `none`
- query `ContentOracle`
- replace `None` with `unreachable` while preserving child effects
- materialize constant / `global.get` / `ref.func` replacements when legal
- simplify `ref.eq`
- simplify `ref.test`
- refine existing `ref.cast`

So the optimizing sibling does **not** widen the core rewrite surface.

### 4. The difference appears in `visitFunction`

The key control flow in `visitFunction(Function* func)` is:

1. if anything changed, run `ReFinalize()`
2. if `castAll`, maybe add new casts
3. if nothing changed after that, return
4. repair EH nested pops with `EHUtils::handleBlockNestedPops(...)`
5. if `!optimizing`, return
6. otherwise create a nested `PassRunner`
7. add `dce`
8. add `vacuum`
9. run them on the changed function

That is the whole public identity of `gufa-optimizing`.

## Why the nested cleanup rerun exists

The source comments explain the exact problem.
GUFA may repeatedly infer the same constant at nested expression sites, preserving earlier work by wrapping the old expression in `drop` / `block` structure.
That is correct, but it can leave code like:

- repeated constants
- extra `drop`s
- extra `block`s
- explicit `unreachable`s whose consequences have not yet been harvested

The file comment and the in-function comment both say the optimizing variant exists to run `dce` and `vacuum` right away so repeated GUFA runs do not bloat output.

This is a subtle but important design lesson:

- proof-based optimization can create cleanup debt
- Binaryen exposes one public sibling that leaves the debt visible
- Binaryen exposes another public sibling that pays the debt immediately

## What the dedicated test proves

`test/lit/passes/gufa-optimizing.wast` compares:

- `--gufa`
- `--gufa-optimizing`

on the same module.

The key example uses nested result blocks around a call to a helper that returns `1`.
Plain `gufa` proves the value is `1`, but leaves a visibly noisy chain of nested `drop` + `block` wrappers.
The `DO_OPT` expectation for `gufa-optimizing` shows the cleaned result:

- `drop (call $foo)`
- then `i32.const 1`

So the shipped test teaches exactly the sibling difference the source comments describe.

## Important positive shapes

### Positive family 1: nested block/result shells that GUFA collapses semantically but not structurally

If GUFA proves a value through nested blocks, plain `gufa` may leave nested wrappers.
`gufa-optimizing` runs `dce` + `vacuum` to erase those wrappers.

### Positive family 2: new `unreachable` that exposes dead code

If GUFA proves a site has no possible contents, it replaces it with `unreachable` while preserving child effects.
That often leaves dead suffixes or dead result traffic for `dce` to prune.

### Positive family 3: new dropped values

If GUFA preserves side effects from an old expression but replaces the value itself, extra `drop`s can remain.
`vacuum` is the explicit downstream cleaner for that shape.

## Important negative / preserved / bailout shapes

### Negative family 1: no new analysis power over plain `gufa`

`gufa-optimizing` does **not** know more than plain `gufa`.
It uses the same `ContentOracle`, same generic visitor, same `ref.eq` / `ref.test` / `ref.cast` logic, and same tuple / ordered-memory boundaries.

### Negative family 2: no cast-all insertion step

Because this sibling is `(true, false)` rather than `(false, true)`, it does **not** add the extra “insert new casts everywhere we know a narrower type” step from `gufa-cast-all`.
It only cleans up after ordinary GUFA rewriting.

### Negative family 3: cleanup runs only on modified functions

The nested `PassRunner` is created inside `visitFunction` after the `optimized` check.
So unchanged functions do not pay this extra cleanup cost.
This is part of the practical runtime contract.

### Negative family 4: still not part of the default optimize pipeline

`pass.cpp` registers the pass publicly, but the reviewed default no-DWARF pipeline does not schedule it.
So this is an optional public tool, not a preset-mandated stage.

## Analyses and helper dependencies a future port must preserve

Core dependencies:

- `ContentOracle` / `PossibleContents` in `possible-contents.h`
- `ReFinalize`
- `EHUtils::handleBlockNestedPops`
- nested `PassRunner`
- `dce`
- `vacuum`

Important inference: the porting boundary is not just “implement GUFA and add another CLI spelling.”
A real port must also preserve the sibling’s **post-rewrite cleanup staging** and the fact that cleanup is run only for changed functions.

## Easy beginner misunderstandings

### “It is just GUFA but more aggressive”

Too vague.
The actual difference is a very specific nested `dce` + `vacuum` cleanup contract.

### “It should be in default `-O` if it makes code cleaner”

Not in reviewed `version_129`.
It is public, but not part of the default no-DWARF scheduler.

### “It is the same as `gufa-cast-all` plus cleanup”

No.
`gufa-cast-all` changes the type-rewrite surface by adding new casts.
`gufa-optimizing` keeps `castAll = false` and instead runs cleanup passes.

### “The cleanup is whole-module”

No.
The nested runner is invoked per modified function.

## Porting checklist for Starshine

A future Starshine `gufa-optimizing` port should preserve:

1. the same closed-world `ContentOracle` analysis as plain `gufa`
2. the same narrow direct rewrite surface as plain `gufa`
3. `optimized` tracking at function scope
4. `ReFinalize()` before post-cleanup
5. `EHUtils::handleBlockNestedPops(...)` after real rewrites
6. a nested cleanup runner with **`dce` then `vacuum`** in that order
7. the changed-functions-only cleanup scope
8. the explicit split from `gufa-cast-all`
9. the fact that the pass is public but not in the default no-DWARF scheduler

## Suggested living wiki follow-through

The living wiki should give `gufa-optimizing` its own folder rather than treating it as a bullet inside the broader `gufa` dossier, because:

- it is a separate public pass name
- the nested rerun contract is the entire point
- the dedicated lit file teaches a concrete before/after shape worth preserving

## Official source links

- Binaryen `version_129` `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `possible-contents.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- Binaryen `version_129` `gufa-optimizing.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- Binaryen `version_129` `gufa.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- Binaryen `version_129` `gufa-cast-all.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- Binaryen `version_129` release tag: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
