# Binaryen `constant-field-null-test-folding` / `cfp-reftest` source-confirmation follow-up

Date: 2026-04-21

## Why this follow-up exists

The tracker no longer has an obvious remaining `none` target.
That means a continuing recursive pass-wiki thread now needs to do one of two things:

- justify another tracker expansion, or
- close a real major gap inside an already-dossier folder.

This thread chose the second route.

Chosen pass: `constant-field-null-test-folding` / upstream `cfp-reftest`

Why this was still a fair target even though it already had a dossier:

- the existing folder already taught the high-level sibling split from plain `cfp`,
- but it still left a real source-confirmation gap around **how Binaryen's exact-two-bucket matcher actually proves the rewrite is legal**, and
- that gap mattered because the local name `constant-field-null-test-folding` still invites a misleading mental model like “generic null-test simplifier,” while the real `version_129` contract is much narrower and more mechanical.

In particular, the old folder did not yet make all of these source-backed points explicit in one place:

- the matcher requires `values.values.size() == 2`, not “some small set of values”
- both value buckets must correspond to exactly one heap type each, not arbitrary mixed-type sets
- one of those types must be a subtype of the other so one `ref.test` can partition the buckets
- the generated test may need `ref.as_non_null`, and Binaryen rejects the rewrite when that would require nonnullable-type `ref.test` support the module does not have
- the dedicated `cfp-reftest.wast` file proves a very small public proof surface: positive two-subtype partitioning plus nearby bailout families, not a broad control-flow optimization contract

So this follow-up is a source-confirmation refresh, not a new tracker-expansion wave.

## Backlog slice check

`agent-todo.md` still has **no dedicated `constant-field-null-test-folding` or `cfp-reftest` slice**.

That remains worth recording because the pass is already named in the local boundary-only registry and sits in a source-backed closed-world GC/type cluster beside:

- `constant-field-propagation`
- `remove-unused-types`
- optional `global-type-optimization`
- `global-struct-inference`

## Sources reviewed for this follow-up

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129`

- `src/passes/ConstantFieldPropagation.cpp`
- `src/passes/pass.cpp`
- `src/ir/possible-constant.h`
- `src/ir/struct-utils.h`
- `test/lit/passes/cfp-reftest.wast`
- `test/lit/passes/cfp.wast`
- `test/lit/passes/gto_and_cfp_in_O.wast`
- Binaryen `version_129` release page

## Main source-confirmed findings

## 1. The variant is gated by an exact two-bucket check

The crucial helper in `ConstantFieldPropagation.cpp` is `optimizeUsingRefTest(...)`.
The first important thing it does is reject any case where the field summary does not have **exactly two possible values**.

This is stronger than the looser teaching phrase “two-ish possible values.”
The real contract is literally:

- if the tracked value list is not size `2`, bail out.

That means:

- plain `cfp` handles the one-bucket case,
- `cfp-reftest` handles one narrow two-bucket rescue case,
- and `3+` buckets are out of scope.

This is the first big reason the pass is not a generic null-test optimizer.

## 2. Each bucket must correspond to one concrete heap type set the matcher can reason about cleanly

After the two-bucket check, Binaryen computes the possible dynamic heap types associated with each value bucket.
The reviewed code rejects cases where either side does not boil down to exactly one candidate type.

That is another strong narrowing rule.
The pass does **not** accept:

- one bucket that itself contains multiple unrelated created-type populations,
- or a vague “else” side whose runtime type set is still structurally mixed in a way the matcher cannot express.

So the public mental model should be:

- the pass wants **two value buckets and two single-type classifier buckets**,
- not “two values somewhere in the lattice.”

## 3. The classifier is a subtype relation, not a generic null predicate

The implementation next checks whether one of the candidate types is a subtype of the other.
Only then can it treat the smaller type as the `ref.test` discriminator and the larger/sibling side as the else bucket.

That means the actual classification proof is:

- “one legal heap-type test partitions the dynamic instances in the same way the two field-value buckets are partitioned.”

It is **not**:

- “one side is null”
- “one side merely has a different constant”
- “there are two reachable field values so a select must exist”

Null may appear as a value on one side, but null is not the defining proof mechanism.
The proof mechanism is a subtype partition.

## 4. Binaryen explicitly rejects null-valued classifier buckets for this transformation

The reviewed matcher rejects any case where either tracked bucket value is itself the null reference in the way the helper would need to classify.
That is another clue that the pass is not implemented as a broad “null versus non-null” simplifier.

The real transformation wants:

- two representable replacement payloads,
- classified by one subtype test,
- not one bucket that is simply “null happened here.”

So the local name `constant-field-null-test-folding` remains an over-broad teaching handle.
The upstream name `cfp-reftest` is materially safer.

## 5. The generated test may require `ref.as_non_null`, and Binaryen feature-gates that case

One of the most important newly confirmed details is the nullable-base handling.
When the original field read uses a nullable base reference, Binaryen may synthesize:

- `ref.as_non_null(base)`
- followed by `ref.test` against a nonnullable reference type

But the matcher does **not** assume that is always legal.
It checks whether the result would require nonnullable-type `ref.test` support and bails out unless the module features include the relevant GC nonnullable locals support.

This is a very important beginner-facing detail because otherwise the rewrite can look deceptively simple in WAT.
The actual contract is:

- the pass is willing to insert `ref.as_non_null` to keep the test well-typed,
- but only when the feature set supports the required nonnullable test form.

So a future Starshine port must preserve **both** of these together:

- nullable-base repair via `ref.as_non_null`
- feature-sensitive rejection when that repair would be invalid

## 6. The resulting shape is literally `select(then, else, ref.test(...))`

The rewrite builder in `ConstantFieldPropagation.cpp` constructs the output directly as a `select` over the two bucket payloads and the synthesized `ref.test` condition.
It is not modeled as:

- a rewritten `if`
- a control-flow split
- a cast plus later simplification

That confirms the pass belongs with the CFP field-read family, not with branch optimizers or cast optimizers.

The visible public shape is small:

- old read: `struct.get ...`
- new read result: `select(v1, v2, ref.test(...))`

Everything else that matters is the proof that the two values and the subtype partition line up.

## 7. The dedicated lit file proves a tiny public surface

The dedicated `cfp-reftest.wast` file is short, and that is informative.
It shows the real proof surface is small and deliberate.
The directly visible tested families include:

- a positive two-subtype family where one `ref.test` selects between two constant results,
- a nullable-base variant where the generated condition uses `ref.as_non_null` before `ref.test`,
- and nearby bailouts where the subtype lattice or value partition does not support the rewrite.

So the official test evidence matches the code-level reading:

- Binaryen is proving one very specific extension to CFP,
- not a wide class of null-test or branch simplifications.

## 8. The variant still inherits the tiny possible-constant lattice from ordinary CFP

The pass continues to rely on `possible-constant.h`.
That means the replacement payloads still come from the same tiny representable domain as plain CFP:

- one literal constant,
- one immutable global,
- or unknown.

The `cfp-reftest` sibling does not widen that payload domain.
It only widens the *classifier* used to choose between two already-representable payloads.

This distinction is important.
A future port that widens both the payload lattice and the classifier at the same time would no longer match Binaryen's actual contract.

## 9. The variant remains downstream of the full CFP analysis, not a syntax peephole

Nothing in the reviewed source suggests a standalone tree-pattern matcher over arbitrary `struct.get` plus nearby tests.
Instead, the control flow is still:

1. run the ordinary closed-world struct-field scan and propagation
2. compute field facts per type hierarchy
3. try ordinary single-value replacement first
4. only then try the `ref.test`-based two-bucket rescue case

So the safest porting lesson remains:

- implement plain CFP first,
- then add the narrow variant,
- never start from a local `struct.get` peephole and hope to recover the same semantics later.

## 10. The local tracker wording should be more explicit about the source-confirmed matcher

Before this follow-up, the folder already said “exact-two-bucket subtype discriminator.”
That was directionally right, but the newly reviewed source makes the stronger statement worth recording explicitly:

- exact two tracked values,
- exact one heap-type set per bucket,
- one subtype relation between those sets,
- optional `ref.as_non_null` repair,
- and a feature gate for nonnullable `ref.test` forms.

That is the major gap this thread closes.

## Practical beginner summary after the follow-up

A better beginner summary than the local registry name is:

> `cfp-reftest` is plain closed-world constant-field propagation plus one extra rule: if a field read has exactly two provable constant/global outcomes and one subtype test can separate which outcome applies, Binaryen rewrites the read to `select(..., ..., ref.test(...))`.

That summary is much closer to the actual source than “constant-field null-test folding.”

## What a future Starshine port must preserve

- the local-vs-upstream name split: `constant-field-null-test-folding` vs `cfp-reftest`
- the fact that this is **one mode bit inside the ordinary CFP engine**, not a separate pass engine
- the exact `values.size() == 2` gate
- the requirement that each side map to one classifier heap-type set the matcher can use
- the requirement that one side be a subtype of the other for the chosen discriminator
- the inherited tiny payload lattice from ordinary CFP
- the optional `ref.as_non_null` repair and its feature-sensitive bailout
- the fact that the public output shape is a `select(ref.test(...))` read replacement, not a general branch transformation

## Wiki work filed back from this follow-up

This follow-up should refresh the existing dossier by adding a dedicated mechanics page focused on:

- exact-two-bucket matching
- subtype partition proof
- nullable-base repair with `ref.as_non_null`
- nonnullable-type `ref.test` feature gating
- dedicated `cfp-reftest.wast` positive and bailout families

It should also refresh the tracker and index wording so future recursive threads can see that this source-confirmation gap is no longer open.

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129`

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
- <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
