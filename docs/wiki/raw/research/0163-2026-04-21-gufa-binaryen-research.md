# Binaryen `gufa` research

Date: 2026-04-21
Status: source-backed upstream-only dossier expansion
Pass: `gufa`
Sibling variants reviewed: `gufa-optimizing`, `gufa-cast-all`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Campaign context: the original no-DWARF / saved-`-O4z` queue and the first widened upstream-only queue were already dossier-covered, so this note deliberately expands the tracker again using a source-backed registry candidate that is already named locally and already matters to the existing `type-refining` GUFA notes.

## 1. Why this pass is an eligible campaign target

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

The main parity queue is already dossier-covered, and the first upstream-only registry expansion queue is dossier-covered too.
So this thread needed either:

- a major-gap fallback in an already-deep folder, or
- a new source-backed upstream-only registry candidate.

I chose the second path.

`gufa` is a good candidate because:

1. it is already a named local boundary-only registry entry in `src/passes/optimize.mbt`
2. upstream also exposes two closely related public siblings, `gufa-optimizing` and `gufa-cast-all`, which confirms this is a stable public pass family rather than an internal helper
3. the existing `type-refining` dossier already treats GUFA as an important neighboring inference engine, so a dedicated folder improves beginner-facing explanation instead of duplicating unrelated work
4. it still had no dedicated folder under `docs/wiki/binaryen/passes/`
5. `agent-todo.md` currently has **no dedicated `gufa` slice**

That makes this a real local-registry documentation gap, not a random side quest.

## 2. Source inventory reviewed for this note

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`
- `docs/wiki/raw/research/0150-2026-04-21-type-refining-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/GUFA.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/ir/possible-contents.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- `test/lit/passes/gufa.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- `test/lit/passes/gufa-optimizing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- `test/lit/passes/gufa-cast-all.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>

### Freshness / drift spot-check

I also spot-checked `main` for the same public surfaces:

- `src/passes/GUFA.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/gufa.wast`

On the reviewed surfaces, current `main` still matched `version_129` exactly in file length and in the key public registration / rerun / cast-all lines I checked.
So this dossier can treat `version_129` as a stable source oracle without needing a separate drift page yet.

## 3. The main conclusion in one paragraph

Binaryen `gufa` is a whole-program content-propagation pass built around `ContentOracle`, a closed-world analysis that answers what values or reference cones can actually reach each program location. The pass then rewrites expressions using those answers: locations with no possible contents become `unreachable`, locations with a single known literal or immutable-global / `ref.func`-style value may be replaced with that value, impossible `ref.eq` and `ref.test` cases can collapse to `0`, guaranteed `ref.test` success can collapse to `1`, and `ref.cast` can refine its target type. The plain `gufa` variant stops there; `gufa-optimizing` immediately reruns `dce` and `vacuum` on modified functions; `gufa-cast-all` adds new casts wherever the oracle knows a more refined type. So the real pass family is not generic “global constant propagation.” It is a closed-world, reference-aware, whole-program content oracle plus a deliberately small rewrite surface.

## 4. Registry and scheduler placement

## Upstream registration

`pass.cpp` registers three public pass names together:

- `gufa`
- `gufa-cast-all`
- `gufa-optimizing`

It also registers `type-refining-gufa` separately, which is a strong clue that GUFA is treated upstream as a reusable inference engine, not just as one pass-local trick.

## Default scheduler fact

The reviewed `pass.cpp` default optimize pipeline does **not** add `gufa`, `gufa-optimizing`, or `gufa-cast-all` to the current no-DWARF `-O` / `-Os` pipeline.
That means:

- this folder is an explicit tracker expansion, not a leftover parity-queue dossier
- a future Starshine port should not silently pretend GUFA is already part of the default preset story

## Local registry fact

`src/passes/optimize.mbt` already tracks:

- `gufa`
- `gufa-optimizing`
- `gufa-cast-all`

as `boundary-only` names.
That local fact is what makes this expansion justified for this campaign.

## 5. What `ContentOracle` actually computes

The biggest beginner-facing fact is that the pass file itself is only half the story.
The real engine is `ContentOracle` in `src/ir/possible-contents.h`.

The reviewed source describes `ContentOracle` as whole-program analysis over a **closed world** that starts from roots such as newly created values and propagates them through the locations they can reach.
It focuses on three things:

1. locations with **no** possible contents at all
2. locations that must contain a specific **constant-like value**
3. reference locations where the possible runtime values lie in a smaller **type cone** than the IR says

The helper data model is `PossibleContents`.
Its useful cases are:

- `None` = no possible contents, which maps to unreachable
- `Literal` = one exact constant-like value
- `GlobalInfo` = one specific immutable-global / function value source with a tracked content type
- `ConeType` = a reference type plus a subtype-depth bound
- `Many` = too many possibilities to simplify further

This is why GUFA can do things that simpler local passes cannot.
It is not just looking for a nearby `local.set` or a one-block pattern.
It is using a program-wide reachability-and-contents model.

## 6. The actual implementation structure in `GUFA.cpp`

The core implementation is `GUFAOptimizer`, a function-parallel post-walker that queries `ContentOracle` while rewriting each function.

Important implementation phases:

### Phase 1: hold one shared oracle and one per-worker map for newly created nodes

`ContentOracle` is built once for the module.
`GUFAOptimizer` keeps a per-worker `newContents` map so that when a rewrite replaces one node with another, later steps in the same worker can still ask for the inferred contents of that new node without mutating the shared oracle.

That detail matters because the pass is function-parallel.

### Phase 2: generic expression rewrite through `visitExpression`

The generic visitor skips:

- `unreachable`
- `none`
- already constant expressions
- tuple-typed expressions

For everything else it asks the oracle for the location's possible contents.

Then the logic splits:

- if the oracle says `unreachable`, replace the expression with `unreachable` while preserving child side effects using `getDroppedChildrenAndAppend(...)`
- if the oracle cannot materialize a concrete replacement expression, bail out
- if the current operation is an ordered atomic access, bail out
- otherwise build the concrete replacement and try to use it

The current materializable cases are narrow:

- literals / constant expressions
- global gets
- `ref.func`

That is a very important teaching boundary. GUFA learns more than it can always emit directly.

### Phase 3: type compatibility check after materialization

Even if the oracle knows the unique runtime value, Binaryen still checks whether the replacement expression's type is a subtype of the current location's type.

If yes:

- replace the expression, keeping child effects via drop wrappers if needed

If not:

- and the replacement is a `global.get` or `ref.func`, Binaryen currently bails out instead of forcing an extra repair cast or `ref.as_non_null`
- otherwise, when the concrete replacement is just a constant expression with the wrong type, Binaryen treats that as proof the original code path is unreachable and rewrites to `unreachable`

This is one of the easiest parts to misunderstand.
GUFA can know “only this value can flow here” without being able to emit that value directly at that exact type.

### Phase 4: dedicated `ref.eq` optimization

`visitRefEq` uses `PossibleContents::haveIntersection(...)`.
If the two sides cannot possibly contain the same reference, the result becomes `i32.const 0`.

This is not generic equality folding.
It is a content-intersection proof.

### Phase 5: dedicated `ref.test` optimization

`visitRefTest` compares the operand contents against the cone of the test target type.

- if the two sets have no intersection, the result is `0`
- if the operand contents are a subset of the target cone, the result is `1`
- otherwise Binaryen leaves the test alone

This is a stronger, more semantic rewrite than a plain local cast/test peephole.

### Phase 6: dedicated `ref.cast` optimization

`visitRefCast` first asks the oracle for a refined result type for the cast itself.
If the inferred type is a proper subtype of the existing cast result type, Binaryen sharpens the cast type in place.

Then it falls through to the ordinary `visitExpression` logic, which can sometimes replace the whole cast with a constant or `unreachable`.

A subtle but important guard is that exact casts are only used when custom descriptors allow them; otherwise the inferred type is relaxed back to inexact.

### Phase 7: function-final repair and optional nested reruns

After each function walk:

- `ReFinalize` repairs newly inserted `unreachable` and other type changes
- if `castAll` is enabled, a second walk may add fresh `ref.cast`s to any castable expression with a more refined oracle type, followed by another `ReFinalize`
- if anything changed, `EHUtils::handleBlockNestedPops(...)` repairs EH block/pop structure
- if `optimizing` is enabled, Binaryen immediately reruns `dce` and `vacuum` on that function

So the public family split is real:

- `gufa` = oracle rewrite only
- `gufa-optimizing` = oracle rewrite + local cleanup rerun
- `gufa-cast-all` = oracle rewrite + explicit cast insertion, but **not** the optimizing rerun

## 7. Why `gufa-optimizing` exists

The code comments make the reason explicit.
GUFA may introduce extra `drop`, `block`, and `unreachable` structure while preserving side effects.
Without cleanup, repeated GUFA applications can even grow code.

The official `gufa-optimizing.wast` test exists mainly to prove that the optimizing sibling cleans up those wrappers by running:

- `dce`
- `vacuum`

on modified functions.

That means `gufa-optimizing` is not just a convenience CLI alias.
The nested rerun is part of the semantic contract.

## 8. Why `gufa-cast-all` exists

The plain pass only sharpens **existing** `ref.cast` instructions.
It does not add new casts everywhere the oracle knows a more specific type.

The `castAll` mode exists because later optimization opportunities often benefit from having those explicit casts in the IR.
`gufa-cast-all.wast` is the dedicated surface that proves that behavior.

The pass still keeps several brakes:

- GC must be enabled
- the expression must be castable
- the inferred type must be a proper subtype of the current IR type
- exact casts are downgraded to inexact when custom descriptors are unavailable
- uncastable types are not refined by force

So `gufa-cast-all` is not “cast everything aggressively.”
It is still shaped by validation and feature rules.

## 9. Important positive shapes from the official tests

## Whole-program constant result inference

The main `gufa.wast` file shows that a function that is only ever called with one effective value can be simplified even when the proof crosses calls, returns, locals, or globals.

This is one of the main differences from smaller local passes.

## Never-called parameter / unreachable bodies

If no possible value can reach a location, the pass rewrites to `unreachable`.
The official test uses this for a never-called function parameter case.

## Local / block / select result simplification

When a block result or select result has one possible content, GUFA may replace the larger expression with that value, preserving side effects with drops.

## `ref.eq` impossible-equality folding

If two references cannot possibly intersect, GUFA emits `0`.

## `ref.test` impossible-success or guaranteed-success folding

If the operand's possible contents are disjoint from the test cone, emit `0`.
If they are entirely inside the cone, emit `1`.

## `ref.cast` type refinement

If GUFA proves a narrower result type is enough, it sharpens the cast type itself before any later replacement.

## `gufa-cast-all` explicit cast insertion

The dedicated lit file shows cases where plain GUFA would not insert a new cast, but `gufa-cast-all` does.
This is important for downstream passes and for teaching that the pass family has three distinct public surfaces.

## 10. Important bailout and preserved shapes

## Open-world uncertainty

The main `gufa.wast` file explicitly uses `--closed-world` because otherwise external `ref.func` reachability would make more things callable from outside.
That is a major beginner-facing clue:

- closed-world assumptions are not incidental here
- they are part of why the oracle can be strong

## Ordered atomics

`visitExpression` bails out on anything whose memory order is not `Unordered`.
That preserves synchronization semantics.

## Tuple types

The pass explicitly skips tuple-typed expressions.
So this is not a generic multivalue propagation engine.

## Nonmaterializable contents

When the oracle says a location has a narrower cone type but not a single materializable literal/global value, plain GUFA often cannot emit a replacement there.
The knowledge is still useful for `ref.test`, `ref.cast`, and `gufa-cast-all`, but not for arbitrary expression replacement.

## Type-mismatch replacement with `global.get` / `ref.func`

Even when GUFA knows a single global or function value reaches a site, it currently refuses to replace the expression if the emitted `global.get` / `ref.func` type would not validate at the original site.

This is a key “sounds more powerful than it is” rule.

## Exact-cast feature limits

The pass relaxes exact inferred types back to inexact when custom descriptors are not enabled.

## 11. Pass interactions that matter

## With `dce` and `vacuum`

This is the most explicit interaction.
The optimizing variant literally depends on them to clean up the extra wrapper structure GUFA may create.

## With `type-refining-gufa`

The existing `type-refining` dossier already showed this, but the dedicated `gufa` folder makes the relationship clearer:

- `type-refining-gufa` reuses the same whole-program `ContentOracle` idea
- but it applies that information to field-type refinement rather than to GUFA's direct expression rewrite surface

So a future Starshine port can treat GUFA as a reusable analysis family, not just one isolated pass.

## With GC / cast-sensitive passes

`gufa-cast-all` can expose more explicit cast structure for later GC-aware cleanup, but it can also increase immediate code size or runtime cast count.
So its value depends on surrounding pipeline choices.

## 12. What a future Starshine port must preserve

A credible port should preserve these source-backed rules:

1. GUFA is **whole-program** and **closed-world** in spirit, not a local peephole pass.
2. The analysis engine is the important part: it answers possible contents per location, not just constants.
3. The plain pass rewrite surface is intentionally narrow.
4. Side effects are preserved by dropping old children before inserting replacement values.
5. Ordered atomics, tuples, and type-incompatible materializations stay conservative.
6. `ref.eq`, `ref.test`, and `ref.cast` have dedicated logic beyond the generic replacement path.
7. `gufa-optimizing` owns the nested `dce` + `vacuum` rerun contract.
8. `gufa-cast-all` owns the explicit cast-insertion contract.
9. EH nested pops and refinalization are required repair steps after rewrites.

## 13. Most important beginner corrections

The reviewed sources suggest five corrections worth preserving in the living docs:

1. **GUFA is not just constant propagation.**
   It is a contents oracle over constants, unreachable locations, and reference cones.
2. **GUFA is not a default optimize pass in the reviewed no-DWARF pipeline.**
   This dossier is a tracker expansion, not a parity leftover.
3. **`gufa-optimizing` is not just a faster implementation.**
   It has a different public contract because it reruns `dce` and `vacuum` on changed functions.
4. **`gufa-cast-all` is not the same as plain GUFA.**
   It adds new casts that plain GUFA deliberately avoids.
5. **Knowing one runtime value is possible does not always mean Binaryen can emit that value directly.**
   Type-compatibility and feature rules still matter.

## 14. Living wiki work this research justifies

This note justifies a dedicated living folder:

- `docs/wiki/binaryen/passes/gufa/index.md`
- `docs/wiki/binaryen/passes/gufa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/gufa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/gufa/content-oracle-variants-and-boundaries.md`
- `docs/wiki/binaryen/passes/gufa/wat-shapes.md`

It also justifies widening the pass tracker and pass-folder index to list `gufa` explicitly as another upstream-only registry dossier.

## 15. Sources

### Local repo

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`
- `docs/wiki/raw/research/0150-2026-04-21-type-refining-binaryen-research.md`

### Official Binaryen

- `version_129`
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `src/passes/GUFA.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/ir/possible-contents.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- `test/lit/passes/gufa.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- `test/lit/passes/gufa-optimizing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- `test/lit/passes/gufa-cast-all.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- current `main` spot-checks
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa.wast>
