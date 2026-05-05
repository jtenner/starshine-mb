---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/research/0471-2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./content-oracle-variants-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
  - ../type-refining/index.md
---

# `gufa` implementation structure and tests

## Upstream source rule

Use Binaryen `version_129` as the main source oracle for this page, anchored by [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md).

The 2026-05-05 refresh also spot-checked current `main` on the owner, registration, oracle, and dedicated lit-test surfaces and found no teaching-relevant drift from the tagged release.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/GUFA.cpp` | Core pass-family logic: queries `ContentOracle`, rewrites expressions, specializes `ref.eq` / `ref.test` / `ref.cast`, optionally adds new casts, and optionally reruns `dce` + `vacuum` |
| `src/ir/possible-contents.h` | Defines `PossibleContents` and `ContentOracle`, the whole-program lattice/oracle that makes the pass family possible |
| `src/passes/pass.cpp` | Registers `gufa`, `gufa-cast-all`, and `gufa-optimizing`, and also makes the neighboring `type-refining-gufa` relationship visible |
| `test/lit/passes/gufa.wast` | Main semantic contract surface for plain `gufa`: unreachable, constants, calls, locals, globals, `ref.eq`, `ref.test`, and `ref.cast` |
| `test/lit/passes/gufa-optimizing.wast` | Proves that the optimizing variant owns nested cleanup behavior, not just a naming alias |
| `test/lit/passes/gufa-cast-all.wast` | Proves the cast-insertion behavior and its validation/feature limits |

## Public registration and default-preset story

`pass.cpp` exposes all three public names:

- `gufa`
- `gufa-cast-all`
- `gufa-optimizing`

It also exposes `type-refining-gufa`, which is a useful clue that GUFA's oracle is shared with another public optimization surface.

Just as important is what `pass.cpp` does **not** do:

- the reviewed default no-DWARF optimize pipeline does not schedule any of the GUFA-family passes by default

So this dossier belongs in the upstream-only registry section, not in the current parity queue.

## Top-level implementation flow in `GUFA.cpp`

The durable execution order is:

1. build `ContentOracle oracle(*module, getPassOptions())`
2. run a function-parallel `GUFAOptimizer` over the module
3. query the oracle for each interesting location
4. replace expressions only where Binaryen can emit a valid replacement
5. repair types and EH nested pops after any change
6. stop here for plain `gufa`
7. if `castAll`, run the second cast-adder walk and refinalize again
8. if `optimizing`, run `dce` then `vacuum` on changed functions

That flow already explains most of the pass family.

## `PossibleContents`: the real data model behind the pass

The official helper defines five useful result classes:

- `None`
- `Literal`
- `GlobalInfo`
- `ConeType`
- `Many`

The helper also exposes the key queries the pass uses:

- `getType()`
- `getCone()`
- `haveIntersection(...)`
- `isSubContents(...)`
- `canMakeExpression()`
- `makeExpression(...)`

That is the most important beginner-facing file outside the pass itself.
Without it, GUFA looks like unexplained magic.

## `GUFAOptimizer`: the rewriting half

`GUFAOptimizer` is a `WalkerPass<PostWalker<...>>`.
Important structural details:

### Function parallelism

The pass declares `isFunctionParallel() = true`.
That is why the code keeps a per-worker `newContents` map for newly created expressions instead of mutating the shared oracle.

### Generic visitor

`visitExpression` handles the common case:

- skip constant / none / unreachable / tuple sites
- ask the oracle for the contents at the current location
- turn `None` into `unreachable`
- materialize literals or global/function identities if possible
- enforce the type-compatibility and memory-order guards

### Dedicated visitors

`GUFA.cpp` also has separate methods for:

- `visitRefEq`
- `visitRefTest`
- `visitRefCast`
- `visitFunction`
- `addNewCasts`

That dedicated structure matters because a big part of the contract lives outside the generic replacement path.

## Why `visitFunction` is a real semantic phase, not cleanup trivia

The post-function step does more than cosmetic tidying.
It decides whether the public variant behaves like:

- plain `gufa`
- `gufa-cast-all`
- `gufa-optimizing`

For plain `gufa`, the important conclusion is negative as well as positive: changed functions are refinalized and EH-repaired, but they do not receive fresh casts and do not run the nested cleanup pair.

The important sequence is:

1. `ReFinalize()` if anything changed
2. optionally `addNewCasts(func)` if `castAll`
3. `EHUtils::handleBlockNestedPops(...)` after any real rewrite
4. optionally run `dce` and `vacuum` if `optimizing`

That is why a beginner-friendly dossier must treat the family split as part of the actual semantics.

## Test map

## 1. `gufa.wast`

This is the main contract file for plain `gufa`.
It demonstrates:

- never-called parameter => unreachable
- direct and indirect-looking whole-program value propagation through calls / returns / locals / globals
- cases with one possible value versus two-value ambiguity
- open-world and export boundaries
- cyclic flows that still converge to one value
- `ref.eq` impossibility proofs
- `ref.test` impossible-success and guaranteed-success proofs
- `ref.cast` refinement / non-refinement cases

This file teaches the pass's real scope better than the pass name does.

## 2. `gufa-optimizing.wast`

This file is short but important.
It exists to prove that the optimizing variant owns an extra cleanup contract.

The checked shape is basically:

- plain `gufa` may leave nested drops / blocks / repeated constants behind
- `gufa-optimizing` cleans those up through the nested `dce` + `vacuum` rerun

Without this file, it would be too easy to describe `gufa-optimizing` as just a convenience wrapper.

## 3. `gufa-cast-all.wast`

This file proves that the cast-all sibling is a distinct public surface.
It covers:

- adding new casts where GUFA knows a narrower type
- exact vs inexact cast behavior
- imported/exported and GC-type corner cases
- castability limits
- the fact that some expressions are still left alone even when the oracle knows more

This file is the strongest argument against collapsing `gufa-cast-all` into a footnote.

## Misconceptions these files prevent

### Misconception 1: GUFA is just a constant-folding pass

False.
The test surface includes unreachable inference, type-cone reasoning, `ref.eq` / `ref.test` set logic, and cast refinement.

### Misconception 2: `gufa-optimizing` is the same pass with a different cost model

False.
The dedicated optimizing test shows a real nested-cleanup output difference.

### Misconception 3: `gufa-cast-all` just means “be more aggressive”

Too vague.
The dedicated cast-all test proves a very specific additional semantic step: inserting new casts that plain GUFA avoids.

### Misconception 4: GUFA belongs to the default optimizer because it sounds powerful

False for the reviewed `version_129` pipeline.
`pass.cpp` registers it publicly but does not schedule it in the current default no-DWARF path.

## Current-main spot check

I checked the following public surfaces on current `main` as a freshness guard:

- `src/passes/GUFA.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/gufa.wast`

On the reviewed owner-file, registration, oracle, and dedicated lit-test surfaces, current `main` did not surface teaching-relevant drift from `version_129`.
So the tagged release remains a stable teaching oracle for this dossier today.

## Porting checklist this page suggests

A future Starshine port needs answers to at least these questions:

1. where will a closed-world contents oracle live?
2. can it represent `None`, literal identity, immutable-global / `ref.func` identity, and type cones distinctly?
3. can rewrite workers preserve side effects the same way Binaryen does with dropped-child wrappers?
4. how will refinalization and EH nested-pop repair be modeled after rewrites?
5. will the project expose just plain `gufa`, or also the `gufa-optimizing` and `gufa-cast-all` public siblings?
6. how will the local boundary-only registry, CLI parser, pass-manager dispatch, and preset omissions change when the pass becomes real? See [`./starshine-strategy.md`](./starshine-strategy.md) for current local status.

## Sources

- [`../../../raw/binaryen/2026-05-05-gufa-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-gufa-current-main-recheck.md)
- [`../../../raw/research/0471-2026-05-05-gufa-current-main-recheck.md`](../../../raw/research/0471-2026-05-05-gufa-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md)
- [`../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md`](../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md`](../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- current `main` spot-checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa.wast>
