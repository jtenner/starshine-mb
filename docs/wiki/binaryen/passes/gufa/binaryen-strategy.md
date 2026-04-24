---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./content-oracle-variants-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
  - ../type-refining/index.md
---

# Binaryen `gufa` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass family.
- The committed raw manifest [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md) is the provenance anchor for plain `gufa`.
- The core implementation is `src/passes/GUFA.cpp`.
- The core analysis helper is `src/ir/possible-contents.h`.
- Public registration comes from `src/passes/pass.cpp`.
- The shipped behavior examples are `test/lit/passes/gufa.wast`, `gufa-optimizing.wast`, and `gufa-cast-all.wast`.
- A 2026-04-24 current-`main` spot check of the reviewed owner/registration/oracle/test surfaces did not surface teaching-relevant drift from `version_129`.

## The pass family in one sentence

Binaryen `gufa` is a closed-world whole-program contents-oracle pass that rewrites expressions when it can prove that only one value, one type cone, or no value at all can reach a location.

## The family in one table

| Variant | What Binaryen does | Why it exists |
| --- | --- | --- |
| `gufa` | Run `ContentOracle`, rewrite impossible or uniquely known locations, simplify `ref.eq` / `ref.test` / existing `ref.cast`, then repair types and EH nested pops | Base behavior |
| `gufa-optimizing` | Do all of plain `gufa`, then rerun `dce` and `vacuum` on changed functions | Prevent wrapper/drop/unreachable growth and harvest the new opportunities GUFA creates |
| `gufa-cast-all` | Do all of plain `gufa`, then insert fresh `ref.cast`s anywhere the oracle knows a narrower type | Expose more downstream GC/cast optimization opportunities |

## Biggest naming fact

The easiest beginner mistake is reading GUFA as:

- generic whole-program constant propagation.

That is too small.

A better model is:

- **Grand Unified Flow Analysis** = whole-program contents reasoning over unreachable locations, constants, immutable-global / `ref.func` identities, and reference subtype cones.

## Scheduler and Starshine fact

This pass family is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline.
That means this dossier is a deliberate upstream-only registry expansion.

Current Starshine also does not implement plain `gufa`: it is boundary-only in `src/passes/optimize.mbt`, CLI requests are rejected in `src/cmd/cmd.mbt`, and there is no `src/passes/gufa*.mbt` owner file. See [`./starshine-strategy.md`](./starshine-strategy.md) for the exact local follow-along map.

## Relationship to `type-refining-gufa`

This is the most important neighboring-pass relationship in the whole folder.

- `gufa` uses `ContentOracle` to rewrite expressions directly
- `type-refining-gufa` uses the same style of whole-program inference to refine field declarations and then repair reads/writes

So GUFA is not just a suffix in another pass name.
It is a reusable Binaryen analysis idea with multiple public clients.

## What the implementation is really organized around

The durable structure is:

1. build one module-wide `ContentOracle`
2. walk each function in postorder, asking what contents each location can have
3. replace unreachable or uniquely-known locations where Binaryen can materialize a valid replacement
4. apply dedicated logic for `ref.eq`, `ref.test`, and `ref.cast`
5. refinalize and repair EH nested pops
6. stop there for plain `gufa`
7. optionally add new casts or rerun local cleanup only in the public siblings

That is the real contract.
It is larger than a peephole pass, but smaller than “rewrite everything the oracle knows.”

## Why the pass is function-parallel even though the analysis is whole-program

The analysis itself is built once at module scope.
But the actual rewriting is per function.

Binaryen handles that split by:

- creating one shared `ContentOracle`
- keeping a small per-worker `newContents` map for expressions the worker itself creates during rewriting

That avoids mutating the shared oracle while still letting later steps in the same worker query newly created nodes.

## Phase 1: `ContentOracle` computes possible contents per location

`ContentOracle` is defined in `possible-contents.h`.
The source comments say it assumes a **closed world**, starts from roots such as newly created values, and propagates them to the locations they reach.

The important result kinds are:

- **None** = no value can reach the location
- **Literal** = one exact constant-like value
- **GlobalInfo** = one specific global or function source with a tracked content type
- **ConeType** = one reference cone with subtype-depth information
- **Many** = too many possibilities to optimize further

That is why GUFA can prove more than ordinary local constant folding.

## Phase 2: generic expression rewrite through `visitExpression`

The generic visitor ignores:

- already `unreachable` expressions
- `none`-typed expressions
- already constant expressions
- tuple-typed expressions

For everything else it queries the oracle.

### If the contents are `None`

Binaryen rewrites the expression to `unreachable`, but preserves child side effects using `getDroppedChildrenAndAppend(...)`.

That means GUFA is not deleting evaluation blindly.
It is proving the result is unreachable while still honoring earlier work that may have side effects.

### If the contents are materializable

Binaryen currently only materializes a narrow set of replacements directly:

- literals / constant expressions
- `global.get`
- `ref.func`

If the materialized replacement's type is a subtype of the current location type, Binaryen inserts it.

### If the materialized value has the wrong type

Binaryen splits the case carefully.

- For `global.get` and `ref.func`, it currently bails out because the value identity is right but the emitted IR type might not validate at the current location.
- For ordinary constant expressions with the wrong type, Binaryen treats that as proof the path is unreachable and emits `unreachable` instead.

This is a subtle but important rule.
Knowing one runtime value reaches a site does not always mean GUFA can emit that value directly.

### Memory-order guard

If `Properties::getMemoryOrder(curr)` is not `Unordered`, Binaryen bails out.
That preserves synchronization semantics.

## Phase 3: `ref.eq` becomes a set-intersection question

`visitRefEq` asks whether the possible contents of the two operands intersect.
If they do not, the result is definitely `0`.

So this is not just a syntactic simplifier.
It is an oracle-backed proof that the two sides cannot alias.

## Phase 4: `ref.test` becomes a cone-membership question

`visitRefTest` compares the operand contents against `PossibleContents::coneType(curr->castType)`.

- no intersection => result `0`
- operand contents are a subset of the target cone => result `1`
- otherwise no change

That is a stronger shape than ordinary cast/test peepholes because it uses whole-program inferred contents.

## Phase 5: `ref.cast` can refine even before full replacement

`visitRefCast` first tries to sharpen the cast result type itself if the oracle proves a narrower subtype.
Only after that does it run the ordinary `visitExpression` logic.

Important exactness rule:

- exact inferred types are relaxed to inexact when custom descriptors are unavailable

So exact refinement is feature-sensitive, not unconditional.

## Phase 6: refinalization and EH repair are mandatory

After a function rewrite, Binaryen calls:

- `ReFinalize()`
- `EHUtils::handleBlockNestedPops(...)`

That is a strong signal that GUFA is not just replacing leaves.
It can change control/value typing enough that post-rewrite repair is part of the real contract.

## Phase 7: `gufa-optimizing` owns the cleanup rerun contract

If `optimizing` is enabled, Binaryen runs a local `PassRunner` with:

- `dce`
- `vacuum`

on modified functions.

The source comment explains why: GUFA may add repeated drops, wrapper blocks, and explicit `unreachable`s.
Without cleanup, repeated GUFA application can even increase code size.

So the optimizing variant is not just “the same pass, but tuned.”
It has a genuinely different output contract.

## Phase 8: `gufa-cast-all` owns the new-cast insertion contract

After the first rewrite and refinalize, `castAll` mode runs a second walk over castable expressions.
If the oracle knows a proper subtype of the current IR type, Binaryen inserts a fresh `ref.cast`.

This is how the family exposes more precise type information for downstream passes.

Important limits:

- GC must be enabled
- the expression must be castable
- the inferred type must still be a valid subtype
- exactness is downgraded when descriptors are unavailable

## Positive rewrite family 1: unreachable-by-proof

The main `gufa.wast` file shows a never-called-parameter case.
If no content can reach a location, GUFA turns the relevant expression into `unreachable`.

That is one of the easiest families to teach because it falls directly out of the `None` result kind.

## Positive rewrite family 2: one known result through calls / locals / globals

GUFA can optimize locations whose unique contents are only obvious after following whole-program flows.
That includes values that cross:

- calls
- returns
- locals
- globals
- cyclic but convergent flows

This is the cleanest “why GUFA exists” family.

## Positive rewrite family 3: impossible or guaranteed ref checks

`ref.eq` and `ref.test` have direct, source-backed special handling.
This is a big part of why the pass is not reducible to plain constant propagation.

## Positive rewrite family 4: explicit cast insertion in `gufa-cast-all`

The dedicated lit file proves that `gufa-cast-all` is not just plain GUFA with more cleanup.
It adds new validation- and optimization-relevant casts where the plain pass would leave the original expression shape alone.

## Negative family 1: tuple-typed values

The pass explicitly skips tuple types.
A future port should preserve that boundary unless its own oracle and repair machinery grow a multivalue story first.

## Negative family 2: ordered atomics and synchronization-sensitive accesses

The pass refuses to replace loads or related sites whose memory order is not `Unordered`.
A future port must keep that barrier explicit.

## Negative family 3: “known value, wrong emitted type” cases

A very easy beginner mistake is assuming that if GUFA proves the value, it can always emit it.
The `global.get` / `ref.func` type-mismatch bailout is the clearest counterexample.

## Important analysis dependencies

The most important helper dependencies are:

- `ContentOracle` / `PossibleContents` in `possible-contents.h`
- `Properties` for memory-order and constant-expression gates
- `ReFinalize`
- `EHUtils::handleBlockNestedPops`
- `PassRunner` for the optimizing variant's nested reruns

This pass does **not** primarily depend on:

- CFG liveness walkers
- branch-threading helpers
- local-graph SSA analyses

That difference matters for future Starshine architecture decisions.

## What a future Starshine port must preserve

A correct port should preserve nine boundaries:

1. module-wide closed-world analysis plus per-function rewrite
2. narrow directly materializable replacement surface
3. side-effect preservation through dropped-child wrappers
4. ordered-atomic bailout
5. tuple bailout
6. dedicated `ref.eq` / `ref.test` / `ref.cast` logic
7. mandatory refinalization and EH nested-pop repair
8. distinct `gufa-optimizing` rerun contract
9. distinct `gufa-cast-all` cast-insertion contract

## Most important beginner correction

If someone says:

- “GUFA is Binaryen's whole-program constant folder”

that is too weak to be accurate.

A much better sentence is:

- “GUFA is Binaryen's whole-program contents oracle plus a narrow rewrite surface for unreachable, exact values, and reference-type checks.”

That is the main durable teaching value of this dossier.

## Sources

- [`../../../raw/binaryen/2026-04-24-gufa-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-primary-sources.md)
- [`../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md`](../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md`](../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md)
