---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap-store-optimization/index.md
  - ../precompute/index.md
---

# Binaryen `pick-load-signs` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.
A refreshed immutable source manifest for the 2026-05-05 current-main bridge lives at [`../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md); the older `version_129` primary-source manifest remains the semantic oracle at [`../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md`](../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md).

Primary files:

- `src/passes/PickLoadSigns.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/properties.h`

Most important helper dependency visible in the implementation:

- `ExpressionStackWalker`
- `Properties::getSignExtValue(...)`
- `Properties::getSignExtBits(...)`
- `Properties::getZeroExtValue(...)`
- `Properties::getZeroExtBits(...)`

The shipped dedicated lit surface is also part of the contract:

- `test/lit/passes/pick-load-signs_sign-ext.wast`

A source-confirmed file/test map now lives on the dedicated companion page:

- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)

A helpful neighboring source is:

- `test/lit/passes/optimize-instructions-sign_ext.wast`

because it shows the broader i64 sign-extension cleanup surface that does **not** belong to `pick-load-signs` itself.

## High-level intent

Binaryen uses `pick-load-signs` to change the signedness of some narrow loads when later code is obviously extending or masking the loaded value anyway.

But the real contract is much smaller than that sentence sounds.

The pass only works when it can prove all of these:

1. the producer is an exact non-tee `local.set(load ...)`
2. every `local.get` use is recognized in a very small AST window
3. all recognized uses agree on the needed width for each sign family
4. the chosen width matches the candidate load width
5. the load is not atomic

If any of those checks fail, Binaryen leaves the load alone.

## Where the pass runs

In `pass.cpp`, the default no-DWARF function pipeline inserts `pick-load-signs`:

- after `optimize-instructions`
- after `heap-store-optimization`
- before `precompute` / `precompute-propagate`

The gate is:

- `options.optimizeLevel >= 2 || options.shrinkLevel >= 2`

That placement is meaningful:

- earlier instruction cleanup can simplify obvious sign-ext noise first
- `pick-load-signs` then flips a small remaining local-written load family
- `precompute` and later cleanup reruns can see the simpler opcode choice

## Nested reruns matter

`opt-utils.h` shows that `optimizeAfterInlining(...)` reruns the default function-optimization stack after inlining-related boundary rewrites.

So `pick-load-signs` can run again inside later optimizing reruns, not just in its top-level slot.

The local saved `-O4z` debug log confirms that practical story:

- the saved run contains `18` `pick-load-signs` executions in total

## Phase 0: per-function state is tiny

The implementation keeps just two pieces of state:

- `std::vector<Usage> usages`
  - indexed by local index
- `std::unordered_map<Load*, Index> loads`
  - mapping each candidate load node to the local it feeds

The `Usage` struct tracks:

- `signedUsages`
- `signedBits`
- `unsignedUsages`
- `unsignedBits`
- `totalUsages`

That is the whole data model.

This is a good beginner signal:

- upstream `pick-load-signs` is not doing heavy whole-function analysis
- it is just collecting local usage counts and widths

## Phase 1: `doWalkFunction(...)`

The function entry does three things:

1. return immediately if the module has no memories
2. resize `usages` to the local count
3. walk the function, then call `optimize()`

That no-memory gate is a real pass rule, not just an incidental micro-optimization.

## Phase 2: candidate discovery in `visitLocalSet(...)`

`visitLocalSet(...)` only records a candidate when:

- the set is **not** a tee
- the set's value is exactly a `Load`

So the pass does **not** try to peek through:

- `local.tee`
- wrapper nodes around the load
- arbitrary value-producing producer trees

That is one of its most important scope limits.

## Phase 3: usage recognition in `visitLocalGet(...)`

Every `local.get` increments `usage.totalUsages`.
Then Binaryen checks up to two ancestor positions on the expression stack:

- parent
- grandparent

Why only two?

Because the file comment explicitly says the relevant patterns may have:

- one level of nesting, like `x & mask`
- or two levels of nesting, like `(x << K) >> K`

This is another big beginner correction.

The pass is not asking:

- “what does this local eventually become after arbitrary dataflow?”

It is asking:

- “does this exact `local.get` sit inside one of the allowed parent/grandparent sign or zero-extension shapes right now?”

## The actual helper-driven recognition surface

### Sign extension

`Properties::getSignExtValue(...)` recognizes only these i32 shapes here:

- `i32.extend8_s x`
- `i32.extend16_s x`
- `(i32.shr_s (i32.shl x K) K)` with equal nonzero shifts

`Properties::getSignExtBits(...)` then reports:

- `8`
- `16`
- or `32 - K`

### Zero extension

`Properties::getZeroExtValue(...)` recognizes only this i32 family here:

- `(i32.and x MASK)` where `MASK` is a low-bit mask and `Bits::getMaskedBits(mask) != 0`

`Properties::getZeroExtBits(...)` reports the low-bit width extracted from that mask.

### Most important inference

Because those helpers bail out unless `curr->type == Type::i32`, the released upstream pass is effectively **i32-only**.

That is a source-backed inference, not just a guess from the test file.

## Phase 4: conflicting widths poison a sign family

When a recognized sign family appears for the first time, the pass stores that width.
If the same family later appears with a different width, the pass zeroes out the remembered width for that family.

That does not immediately abort the pass.
Instead it lets `optimize()` later reject the rewrite via width mismatch.

So the implementation is small, but still carefully defensive.

## Phase 5: final decision in `optimize()`

For each candidate load/local pair, `optimize()` refuses to rewrite when:

- there are no uses at all
- not all uses were recognized as signed or unsigned evidence
- signed evidence exists but does not match `load->bytes * 8`
- unsigned evidence exists but does not match `load->bytes * 8`
- the load is atomic

If the candidate survives those checks, Binaryen chooses:

- signed if `signedUsages * 2 >= unsignedUsages`
- unsigned otherwise

The source comment explains the weighting:

- a signed-use shift pair can remove two instructions
- so signed evidence is worth more than a naive one-vote tally

## Subtlety: per-local evidence, per-load width check

The evidence table is keyed by local index.
But the width check is performed per candidate load.

That means:

- multiple same-width producers for one local can all flip together
- mixed-width producers for one local do **not** automatically all flip together

Only the candidate loads whose own width matches the local's recognized usage width can change.

That is a small but important source detail.

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no CFG reasoning
- no effect analysis
- no local graph or liveness analysis
- no arbitrary arithmetic proof
- no proof through branches, selects, or merges
- no `local.tee` producer handling
- no atomic signedness flipping
- no i64 sign/zero-extension recognition in upstream `version_129`

## Why the dedicated lit file matters so much

`pick-load-signs_sign-ext.wast` only covers two cases:

1. a positive `i32.load8_u -> i32.load8_s` rewrite when the only use is `i32.extend8_s`
2. a negative case where a `br_if` value use makes the load ineligible

That tiny file is not a weakness in itself.
It is actually a clue.

It tells you that the pass's real contract is narrow enough that two carefully chosen i32 cases explain a lot of it:

- exact positive recognition
- exact negative “some other use exists” bailout

## Why `optimize-instructions-sign_ext.wast` is the key neighboring source

The broader official i64 sign-extension cleanup examples live there instead.

That matters because it shows the difference between:

- what Binaryen as a whole can optimize in this area
- what `pick-load-signs` itself is responsible for

The correct beginner takeaway is:

- Binaryen does broader i64 sign-extension cleanup,
- but not in this pass.

## Current freshness note

A narrow 2026-05-05 current-main recheck found no visible drift here:

- `PickLoadSigns.cpp` is identical on `version_129` and current `main`
- `pick-load-signs_sign-ext.wast` is also identical

So there is no current-main correction story to maintain for this dossier.

## What a future port must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- exact non-tee `local.set(load ...)` producers only
- all uses must be recognized, not just “most uses”
- the recognition surface is only the small parent/grandparent helper surface
- the upstream helper story here is effectively i32-only
- atomic loads are always skipped
- the signed side wins ties because of the two-shift savings model
- nested reruns matter because this pass lives inside `optimizeAfterInlining(...)` too

If local code intentionally broadens any of those rules, keep that as an explicit documented divergence.
