# Binaryen `constant-field-null-test-folding` / upstream `cfp-reftest` research

Date: 2026-04-21

## Scope

This note widens the Binaryen pass wiki campaign to cover the local Starshine boundary-only registry entry `constant-field-null-test-folding`, which corresponds to Binaryen's public pass name `cfp-reftest`.

Why this pass is eligible now:

- the original no-DWARF / saved `-O4z` queue is already dossier-covered
- the first tracker-expansion wave is also dossier-covered
- `src/passes/optimize.mbt` still names `constant-field-null-test-folding` as a boundary-only pass
- the existing `constant-field-propagation` dossier already documents `cfp-reftest` as a real public sibling, but it does not yet give that local registry entry its own canonical landing page
- official Binaryen `version_129` sources still expose this as a separate pass name with distinct behavior and a dedicated lit file

So this is an explicit tracker expansion, not a claim that `cfp-reftest` belongs to the current canonical no-DWARF `-O` / `-Os` default path.

## Candidate selection result

Chosen pass: `constant-field-null-test-folding` / upstream `cfp-reftest`

Why this is a fair expansion target:

- it is already a named local boundary-only registry entry
- it has an official Binaryen `version_129` public registration in `pass.cpp`
- it has behavior that is narrower and easier to misunderstand than the parent `cfp` dossier implies
- it sits directly beside already-documented closed-world GC/type neighbors like `constant-field-propagation`, `remove-unused-types`, and `gsi`
- it fills a real documentation gap: the wiki already says `cfp-reftest` exists, but the local registry name `constant-field-null-test-folding` still had no dedicated dossier explaining what the variant actually does and does *not* do

## Backlog slice check

`agent-todo.md` has **no dedicated `constant-field-null-test-folding` or `cfp-reftest` slice**.

That is worth recording explicitly because the pass already matters to nearby docs:

- the `constant-field-propagation` dossier already says there is a real more-aggressive sibling
- the closed-world GC/type cluster docs already place `cfp` / `cfp-reftest` in the same neighborhood between `remove-unused-types` and `gsi`
- the local registry already treats `constant-field-null-test-folding` as a tracked future pass surface

So the repo already recognizes the name, but it did not yet have a canonical page for the actual implementation contract.

## Sources reviewed

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129` sources

- `src/passes/ConstantFieldPropagation.cpp`
- `src/passes/pass.cpp`
- `src/ir/possible-constant.h`
- `src/ir/struct-utils.h`
- `test/lit/passes/cfp-reftest.wast`
- `test/lit/passes/cfp.wast`
- `test/lit/passes/gto_and_cfp_in_O.wast`

### Inference boundary

I rely on the freshly reviewed upstream files above for the core contract.
Where I connect this pass to neighboring closed-world scheduling notes from existing local living docs, that scheduler wording is an inference grounded in those local docs plus the reviewed `pass.cpp` registration surface.

## Main findings

## 1. The local registry name and the upstream public name are different

`src/passes/optimize.mbt` records the future pass surface as:

- `constant-field-null-test-folding`

But Binaryen `pass.cpp` registers the actual public upstream pass name as:

- `cfp-reftest`

That means a future Starshine port needs to preserve a real name split:

- **local registry name:** `constant-field-null-test-folding`
- **upstream public pass name:** `cfp-reftest`

This is not just a cosmetic mismatch.
The local name suggests a generic null-test optimizer, but the upstream implementation is much narrower.

## 2. This is not a separate engine; it is a stricter mode of `ConstantFieldPropagation`

`pass.cpp` creates:

- plain `cfp` with `ConstantFieldPropagation(false)`
- `cfp-reftest` with `ConstantFieldPropagation(true)`

So the variant reuses the same main machinery:

- closed-world GC gating
- field-write scanning
- exact-vs-inexact subtype propagation
- copy fixed point
- read rewriting

The extra behavior is selected by one boolean mode, not by a totally different analysis pipeline.

That means the safest teaching rule is:

- `cfp-reftest` is a **variant of CFP**, not a separate optimization family
- but it is still a **real public pass contract**, not just an undocumented internal flag

## 3. The variant does exactly one extra important thing: two-value subtype splitting with `ref.test`

The parent `cfp` pass tracks one field fact as:

- one literal constant
- one immutable global
- or unknown

When more than one bucket appears, plain `cfp` stops being able to replace the read.

The `cfp-reftest` variant adds one additional rescue path.
If the implementation sees exactly two constant buckets and they line up with a narrow subtype split, it may rewrite the later read as a `select` guarded by `ref.test`.

So the real beginner summary is:

- this pass is **not** generic null-test folding
- it is **CFP plus one narrow subtype-classification rewrite using `ref.test`**

## 4. The name “null test folding” is broader than the real implementation

The local name can mislead a reader into expecting:

- arbitrary `ref.test` simplification
- general null-check elimination
- broader cast or test canonicalization
- generic field-read branching on null versus non-null

That is not what the reviewed source does.

The `optimizeUsingRefTest(...)` helper in `ConstantFieldPropagation.cpp` only fires after the normal constant-field analysis has already proven a very particular situation:

- exactly two possible field values remain
- those values map cleanly onto a testable subtype partition
- one side can be selected by testing the reference against a specific heap type
- both sides are still expressible as legal constants or immutable-global reads

So the better local explanation is:

- **field-read two-bucket subtype splitting**
- not generic null-test folding

## 5. The key matcher is subtype-based, not null-based

The critical helper walks the possible values for a field and tries to find a subtype that can separate them.
The source looks for a `candidateSubType` whose created-type set lets one bucket be identified by `ref.test` and the other bucket act as the else side.

Important implications:

- this is about **dynamic heap-type partitioning**
- null is only one possible ingredient inside the value buckets
- the winning condition is not “one side is null” but “one side can be isolated by one legal subtype test”

This is why the local name is easy to overread.

## 6. The variant is deliberately narrow and often refuses to synthesize a test

The reviewed source and tests show several deliberate bailouts.
`cfp-reftest` does not create a `ref.test`-guarded `select` just because two values exist.
It wants a very specific shape.

The important conservative rules are:

- **exactly two** value buckets
- a single candidate subtype must distinguish them cleanly
- the testable subtype must itself be usable as the `ref.test` discriminator
- if more than two buckets exist, or the subtype split is ambiguous, the variant gives up
- if atomic ordering or other existing CFP safety rules block the rewrite, the variant also gives up

So a future port must preserve the fact that this is a **small extra optimization surface**, not a large new search space.

## 7. The pass still lives inside the same closed-world GC/type cluster as CFP

The existing local scheduler notes and the reviewed `pass.cpp` public registration surface line up on the same practical story:

- `cfp` / `cfp-reftest` are explicit upstream passes
- they are not part of the open-world no-DWARF default optimize path documented in this repo
- they belong to the closed-world GC/type neighborhood around `remove-unused-types`, optional `gto`, and `gsi`

So this dossier belongs in the tracker's expanded upstream-only registry section, not in the main no-DWARF parity table.

## 8. The implementation still inherits all the hard CFP safety boundaries

Because `cfp-reftest` is not a separate engine, it inherits the ordinary CFP constraints as well:

- it is GC-only
- it is closed-world-only
- it tracks exact and inexact references separately
- it depends on write scanning and copy propagation
- it preserves null traps and impossible-read behavior
- it must preserve packed-field reconstruction and atomic ordering rules

This is important for future Starshine work.
A port that implements only the `ref.test` / `select` shape without the ordinary CFP analysis underneath would not match Binaryen.

## 9. The positive shapes are field-read replacements, not generic branch simplifications

The most important beginner-facing positive shape is:

- a later `struct.get` whose possible values are split between two subtype classes
- where one subtype class always carries one constant value
- and the complementary class always carries the other constant value
- so Binaryen can emit `select(v_if_test_true, v_if_test_false, ref.test(...))`

That is the central rewrite family.

A second useful positive family is the null/trap-preserving version:

- if the original read would still null-trap on a null base reference, the rewrite keeps the original base evaluation and only replaces the successful-read payload logic

So even the positive shapes are still really **field-read rewrites**.
They are not generic control-flow simplifications.

## 10. The dedicated lit file confirms the intended contract

`test/lit/passes/cfp-reftest.wast` is especially valuable because it shows this variant as a first-class public surface rather than a hidden implementation footnote.
The file demonstrates that Binaryen expects:

- the pass to be invoked explicitly as `--cfp-reftest`
- select-with-`ref.test` synthesis on narrow two-value field-read families
- no rewrite when the subtype partition or stored-value partition does not line up

That dedicated test file is the cleanest official source-backed reason to give this local registry entry its own folder instead of leaving it buried inside the parent CFP notes.

## 11. Important beginner misunderstandings to avoid

### 11a. “This folds null tests.”

Not generally.
It synthesizes a subtype test only in one narrow field-read optimization family.

### 11b. “This is separate from constant-field propagation.”

Not really.
It is the same CFP engine with one extra mode bit and one extra rewrite family.

### 11c. “Any two values can become a `select`.”

No.
The two values must align with a single subtype discriminator that Binaryen can legally test.

### 11d. “This belongs in the normal default optimize path.”

No.
Like CFP generally, it belongs in the closed-world GC/type cluster and not in the repo's current open-world no-DWARF top-level path.

## 12. What a future Starshine port must preserve

A correct future port must preserve all of the following:

- the **name split** between local `constant-field-null-test-folding` and upstream `cfp-reftest`
- the fact that this is a **CFP variant**, not a separate pass engine
- the same hard **GC + closed-world** gate
- the ordinary CFP fixed-point and subtype machinery before any variant-only rewrite happens
- the narrow **exactly-two-bucket** requirement
- the need for a **single legal subtype discriminator** for `ref.test`
- the existing null-trap, packed-field, and atomic-safety boundaries
- the scheduler reality that this is an **upstream-only closed-world registry candidate**, not part of the repo's default parity path today

## 13. Why this deserved its own dossier even though CFP already mentioned it

The existing `constant-field-propagation` folder already had good notes about `cfp-reftest`, but that was not enough for one important repo-facing reason:

- the local registry tracks a separate named pass surface, `constant-field-null-test-folding`

Without a dedicated landing page, the local name remained easy to misread as a broad null-test optimizer.
This new dossier fixes that by making the real contract explicit:

- the local name is descriptive but imprecise
- the upstream public name is `cfp-reftest`
- the implementation is the normal CFP engine plus one narrow subtype-test-based read rewrite

## Living wiki work to file back

This research should produce:

- a new living folder `docs/wiki/binaryen/passes/constant-field-null-test-folding/`
- tracker expansion so this local registry pass no longer hides as an undocumented alias under the parent CFP dossier
- index updates that make the local-vs-upstream naming split searchable without reopening chat history

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
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
