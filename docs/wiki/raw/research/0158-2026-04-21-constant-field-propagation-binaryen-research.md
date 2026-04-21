# 0158 - Binaryen `constant-field-propagation` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `reorder-types` upstream-only registry dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the main no-DWARF / saved-`-O4z` queue is fully dossier-covered and the tracker’s first upstream-only expansion queue was also closed, justify one more source-backed expansion into another upstream-only pass that is already named in the local registry and clearly connected to existing living docs.
- Create a new beginner-friendly but source-backed dossier for `constant-field-propagation`.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/constant-field-propagation/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

At that point:

- the main no-DWARF / saved-`-O4z` queue still had no pass with wiki status `none`
- the implemented-landing queue was already closed
- the prompt excluded the already-deepened parity dossiers plus the newer `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, `abstract-type-refining`, `unsubtyping`, `minimize-rec-groups`, and `reorder-types` dossiers
- the tracker explicitly said a future thread should either justify a major-gap fallback or widen the tracker with another genuinely eligible upstream-only pass after source-backed justification
- `src/passes/optimize.mbt` still listed `constant-field-propagation` as a local boundary-only registry name
- several freshly written closed-world GC/type dossiers already mentioned `cfp` / `cfp-reftest` as a real scheduler neighbor, but there was still no dedicated living folder for it
- `agent-todo.md` still had **no dedicated `constant-field-propagation` or `cfp` slice**, so there was no local backlog page that already taught the Binaryen contract

So this run needed an explicit second tracker expansion, not a parity-queue revisit.

I picked `constant-field-propagation` for seven source-backed reasons:

- It is already named in the local boundary-only registry in `src/passes/optimize.mbt`, so it is a real Starshine-facing pass name and not just an upstream tangent.
- Upstream `pass.cpp` registers the public CLI name `cfp` plus the variant `cfp-reftest`, which makes it a stable, externally visible Binaryen pass family.
- Existing living dossiers already point at it as a real closed-world scheduler neighbor:
  - `global-type-optimization` records `remove-unused-types -> cfp / cfp-reftest -> gsi`
  - `type-refining` records the same later optional neighbor
  - `signature-refining` also records the same later optional neighbor
- It sits in a very teachable place in the closed-world GC/type cluster:
  - after `global-refining`, optional `gto`, `remove-unused-module-elements`, and optional `remove-unused-types`
  - before `gsi`
- It had **no dedicated living folder at all** under `docs/wiki/binaryen/passes/`.
- The implementation is more interesting than the name suggests:
  - it is not generic constant propagation
  - it is a closed-world struct-field read-replacement pass driven by module-wide write facts plus copy propagation over the type hierarchy
  - it has a second ref-test-powered variant that deliberately trades speed and risk differently
- The official test surface is rich and beginner-useful, with positive and negative examples for:
  - impossible reads from never-created types
  - default-valued and literal-valued fields
  - immutable-global propagation
  - subtype and exactness boundaries
  - field-copy fixed points
  - packed fields
  - arrays-of-struct realistic itable shapes
  - atomics and synchronization limits

So this thread is not reopening an old parity item.
It is the first explicit living dossier for the closed-world-cluster `constant-field-propagation` pass that sits between the repo’s newer `remove-unused-types` / `global-type-optimization` docs and the existing `global-struct-inference` docs.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
- pass registration and default scheduler placement:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- helper surfaces that carry most of the real behavior:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/gc-type-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/bits.h>
- representative official test surface:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>

Narrow freshness check on current `main`:

- core pass file:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
- pass registration:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- dedicated lit file checked on the reviewed surfaces:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-`main` check on the most important reviewed surfaces while drafting the living pages.

Durable result:

- the checked `ConstantFieldPropagation.cpp` logic on `main` still matches the tagged `version_129` pass on the reviewed algorithmic surfaces that matter most here:
  - same GC gate
  - same hard `--closed-world` fatal
  - same `PCVScanner` and `FunctionOptimizer` split
  - same copy-fixed-point analysis structure
  - same `cfp` versus `cfp-reftest` behavior split
  - same atomic-acquire bailout rule
  - same impossible-read-to-`drop; unreachable` replacement
- the checked `pass.cpp` diffs on the reviewed `cfp` surfaces did not change the `cfp` / `cfp-reftest` registration or the closed-world scheduler slot reviewed here
- the checked `cfp.wast` surface still covered the same reviewed families

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable rule for the living wiki should be:

- use `version_129` as the normative algorithm oracle
- record later upstream drift explicitly if it matters
- do not invent a drift story when the checked current surfaces still match the reviewed release behavior

## Repo-local sources used for context

Starshine-side files that mattered while choosing and framing this dossier:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

Important local context conclusions:

- the current open-world no-DWARF page does **not** run `constant-field-propagation`
- the local registry tracks the pass with the full descriptive name `constant-field-propagation`
- upstream `pass.cpp` exposes the CLI alias `cfp` and the more aggressive sibling `cfp-reftest`
- the current living `global-type-optimization`, `type-refining`, and `signature-refining` docs already treat it as a real closed-world scheduler neighbor
- `agent-todo.md` has **no dedicated `constant-field-propagation` slice today**, so this note must say that explicitly instead of pretending a backlog slice already exists

## High-level conclusion

Binaryen `constant-field-propagation` is not generic constant propagation over arbitrary expressions.

The real `version_129` contract is narrower and more concrete:

1. require GC features and reject non-closed-world invocation
2. scan struct writes, defaults, reads, copies, and RMW sites across module code using shared `StructScanner` machinery
3. summarize each field as one possible constant literal, one immutable global, unknown, or unwritten
4. keep exact and inexact reference views separate
5. propagate written values down to subtypes and readable values back up to supertypes
6. propagate copied field values through a fixed point because copied reads feed later writes
7. treat packed fields carefully by masking or sign-extending copied/read values
8. replace `struct.get` / `ref.get_desc` with `drop(ref.as_non_null ref); constant` blocks when one constant value is provable
9. replace reads from never-written fields with `drop(ref); unreachable` because the pass assumes a closed world where such a read is logically impossible except via a trap path
10. deliberately avoid optimizing ordered atomic reads because the analysis cannot yet prove synchronization safety
11. optionally, in the `cfp-reftest` variant only, use a single `ref.test` plus `select` when there are exactly two constant values separable by one final subtype test
12. refinalize changed functions after rewriting

A better short summary is:

- **Binaryen `cfp` is a closed-world GC module-to-function pass family that replaces struct-field reads with a known constant or immutable global when module-wide write facts, subtype propagation, and copy propagation prove that all reachable dynamic instances agree.**

The four biggest beginner corrections are:

- the pass reasons about **fields of struct heap types**, not generic locals or expressions
- it is **closed-world-only** today and throws a fatal error without `--closed-world`
- it is **type-level and escape-insensitive** in a deliberate way, so dropping an allocation does not stop that allocation site from contributing facts
- `cfp-reftest` is a real sibling variant, not just a flag inside `cfp`, and it deliberately trades extra runtime work for more optimization opportunities

## Upstream naming and scheduler surface

`pass.cpp` registers the pass with the short public names:

- `cfp`
- `cfp-reftest`

and the summaries:

- `propagate constant struct field values`
- `propagate constant struct field values, using ref.test`

Those summaries are accurate, but too small.
They hide several central details:

- the pass only optimizes **struct field reads** today
- it is a **closed-world GC** pass family, not a generic peephole
- it can propagate **immutable globals** as well as literal constants
- it has an explicit **copy-propagation fixed point** in the middle of the analysis
- it has deliberate **atomic synchronization bailouts**
- the `cfp-reftest` variant is intentionally separate because it may add expensive `ref.test` work that only pays off if later passes capitalize on it

### Local naming mismatch that future docs must keep explicit

The local Starshine registry uses the fuller descriptive name:

- `constant-field-propagation`

while upstream `pass.cpp` uses the public CLI alias:

- `cfp`

and the sibling public variant:

- `cfp-reftest`

The new living folder should keep all three names visible instead of pretending only one is canonical across both codebases.

### Relation to nearby passes

The most useful mental model is:

- `type-refining` narrows field **types**
- `global-refining` narrows global **declaration types**
- `gto` can remove or freeze private struct **fields**
- `remove-unused-module-elements` and `remove-unused-types` can shrink the module before `cfp`
- `cfp` then cashes in on the simplified field world by replacing later reads with constants or immutable globals
- `gsi` and later passes can then reason over an even smaller, more explicit module

The dedicated lit file `gto_and_cfp_in_O.wast` makes that concrete:

- in open world, the struct field and helper function stay alive and the final `struct.get` stays
- in closed world `-O`, `gto` removes an unread `funcref` field
- that can make a helper function dead for later global cleanup
- and then later `cfp` can infer the remaining i32 field exactly, reducing the final read to a constant

So scheduler placement is not trivia.
It is part of the optimization payoff story.

### Scheduler placement

`cfp` is not part of the repo’s main open-world no-DWARF path.

In upstream `pass.cpp`, the relevant default global-prepass cluster is:

- if `wasm->features.hasGC()` and `options.optimizeLevel >= 2`
- and if `options.closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- then continue with:
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` or `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

The specific `cfp`/`cfp-reftest` split is:

- at optimize levels `2`, use plain `cfp`
- at optimize levels `>= 3`, use `cfp-reftest`

That teaches five durable things:

- `cfp` is a **closed-world post-`remove-unused-types`** GC/type cleanup step
- it belongs to the early global GC/type cluster, not the later function-pass cluster
- optimize level affects which public variant runs
- the default no-DWARF/open-world Starshine orientation page should not mention it today
- unlike some neighboring passes, the pass body itself **also** insists on `--closed-world`

## What the implementation actually looks like

The implementation is smaller than some neighboring passes, but it is still layered.

The pass divides into three big parts:

### 1. write/copy fact collection

`PCVScanner` extends the shared `StructUtils::StructScanner` helper.
It records:

- writes in `struct.new`
- writes in `struct.new_default`
- writes in `struct.set`
- reads that act as copy sources via `struct.get`
- unknownification on RMW/cmpxchg-style writes

The tracked value domain comes from `PossibleConstantValues`:

- no value observed yet
- one literal constant
- one immutable global name
- many / unknown

Important beginner point:

- this pass does **not** use richer value domains like “two constants” for normal `cfp`
- once normal `cfp` sees more than one differing constant, it becomes unknown
- only the later optional `cfp-reftest` read rewrite reasons about exactly-two-value splits

### 2. hierarchy and copy fixed point

After per-function collection, the pass combines facts across functions and runs a hierarchy-sensitive fixed point.

The main logic is:

- written values propagate **down** to subtypes
- readable values propagate **up** to supertypes
- copied fields create cycles because a read can feed another write
- so the pass uses a work queue over copy destinations until the propagated written/readable maps stabilize

That is the real center of the algorithm.

### 3. read replacement

`FunctionOptimizer` is a function-parallel walker that only mutates read operations:

- `struct.get`
- `ref.get_desc`

Positive outcomes are:

- impossible read -> `drop(ref); unreachable`
- one constant value -> `drop(ref.as_non_null ref); constant`
- in `cfp-reftest` only, two constant values split by one final subtype test -> `select(..., ref.test(...))`

Then changed functions are refinalized.

## Key source-backed subtleties

### The pass is intentionally escape-insensitive and type-level

The lit file explicitly says that a dropped allocation still contributes facts.
That is not a bug.
The pass is tracking what values a field can have in instances of a type, not proving object-by-object escape flow.

So this is a valid mental model:

- “If the module ever creates `$T` only with field `x = 42`, then any later readable `$T.x` may be optimized to `42`, even if the specific allocation we saw earlier is dropped.”

### Exactness matters

The analysis stores separate maps for:

- exact refs
n- inexact refs

That matters because writes through `(ref $super)` may target subtypes, while writes through `(ref (exact $super))` may not.

The same distinction also controls which reads are eligible for the `ref.test` variant:

- exact refs never need subtype splitting
- inexact refs may

### Packed fields are not free constants

`PossibleConstantValues::packForField(...)` masks or sign-extends i8/i16 packed fields.
If the tracked single value is an immutable global rather than a literal, packing currently degrades to unknown because the analysis does not track “global plus mask” together.

So some seemingly obvious packed/global wins intentionally do not happen.

### Atomics split into two cases

The pass does optimize reads that are known to trap because trapping accesses do not synchronize.
But it refuses to replace ordered atomic reads with constants, because the analysis does not yet prove absence of synchronization even when the value itself is constant.

That distinction is very easy to misunderstand if you only read the test outputs.

### `cfp-reftest` is deliberately narrow

The ref-test variant only fires when all of these hold:

- the ordinary constant path failed
- the reference is inexact
- all concrete created subtypes under the read type collapse to exactly two constant values
- one value set is represented by a single subtype with no further subtypes, so a simple final-ish `ref.test` can separate it

So `cfp-reftest` is not arbitrary pattern matching.
It is a very conservative two-bucket subtype classifier.

## Important WAT / IR shape families observed in the official tests

The official `cfp.wast` surface teaches these main families:

### Positive families

- never-created type reads become `drop(ref); unreachable`
- `struct.new_default` can justify constant zero reads
- one literal written everywhere to a field can replace later reads
- one immutable global written everywhere to a field can replace later reads with `global.get`
- subtype hierarchies can still optimize when all relevant reachable dynamic instances agree
- copy chains can propagate a constant/global fact from one field to another
- packed field reads can optimize after adding the right masking/sign extension
- realistic itable/array-of-struct shapes can become clearer for later passes even when `cfp` itself only optimizes part of the chain

### Negative or bailout families

- two different literals for the same readable field => plain `cfp` gives up
- mutable globals do not count as constants
- ordered atomic reads do not optimize
- subtype disagreement on a supertype read blocks plain `cfp`
- values that would validate in a parent field but not in a refined child field turn into `drop(value); unreachable` rather than invalid wasm
- no allocated concrete subtype facts means `cfp-reftest` ignores abstract types instead of guessing

## Biggest beginner-friendly conclusions to file into the living wiki

1. `constant-field-propagation` should be taught as a **closed-world struct-field read replacement pass**, not as generic constant propagation.
2. The real algorithm is **write facts + subtype propagation + copy fixed point + read rewrite**.
3. Plain `cfp` tracks only one constant/global or unknown; the exactly-two-value logic belongs only to `cfp-reftest`.
4. The pass is deliberately **type-level and escape-insensitive**.
5. Ordered atomics are a real bailout, but known-trapping reads still optimize.
6. Packed fields and subtype-refined children create non-obvious repair behavior that a future port must preserve.
7. Scheduler placement after `remove-unused-types` and before `gsi` is part of the actual optimization story, not just pipeline trivia.

## Concrete repo updates performed from this research

- Add a new living folder `docs/wiki/binaryen/passes/constant-field-propagation/`.
- Add at least:
  - `index.md`
  - `binaryen-strategy.md`
  - `implementation-structure-and-tests.md`
  - `copies-subtypes-ref-tests-and-atomics.md`
  - `wat-shapes.md`
- Update `docs/wiki/binaryen/passes/tracker.md` to widen the additional upstream-only registry table with `constant-field-propagation` / `cfp`, and mark it dossier-covered immediately in the same change.
- Update `docs/wiki/binaryen/passes/index.md` with the new dossier bullet.
- Update `docs/wiki/index.md` with the new living pages.
- Append this work to `docs/wiki/log.md`.

## Open questions and honest uncertainty

A few boundaries remain worth keeping explicit:

- I did not promote `cfp-reftest` to its own separate dossier because the source and scheduler surface present it as a sibling variant of the same pass family rather than a wholly separate conceptual pass. That is an interpretation from the reviewed sources, but it is still an interpretation.
- I did not widen the tracker with `constant-field-null-test-folding` in this same thread, even though it appears nearby in the local registry, because the current prompt required picking exactly one pass and `cfp` already had stronger explicit neighbor links in the freshly updated living docs.
- The pass header still contains the FIXME that multi-module wasm GC would require type-escaping checks; this dossier therefore treats closed-world-only behavior as the honest current boundary, not as a future-proof semantic truth.

## Bottom line

`constant-field-propagation` was an eligible and useful second tracker-expansion target because it was already named locally, already referenced by nearby GC/type dossiers, and still lacked a canonical living home.

The main durable result is:

- Binaryen `cfp` is a closed-world struct-field constant/global read replacer built on type-hierarchy reasoning and copy fixed points, with `cfp-reftest` as a narrower, more aggressive two-value subtype-splitting sibling variant.

That is the contract a future Starshine boundary-only port would need to preserve.
