---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-06-01-reorder-globals-current-main-recheck.md
  - ../../../raw/research/0689-2026-06-01-reorder-globals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md
  - ../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md
  - ../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../../../binary/leb128-and-integer-encoding.md
  - ../string-gathering/index.md
---

# `reorder-globals`: size model, dependency order, and the `always` variant

This page focuses on the part of `reorder-globals` that is easiest to misunderstand:

- what Binaryen is actually optimizing,
- how dependencies constrain the search,
- why the public pass often does nothing,
- and why `reorder-globals-always` exists anyway.

Reviewed on 2026-06-01 against the official Binaryen `version_129` owner/test surface plus a focused current-`main` freshness recheck; no teaching-relevant drift was found for the specific cost-model, dependency-order, or `always`-variant rules summarized here. The owner/helper/test map now lives in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## One mental model

`reorder-globals` is **not** one greedy sort.

It is closer to:

- build the legal declaration-order space,
- try a few smart ways to rank the currently legal choices,
- score the resulting orders on estimated encoded-index cost,
- keep the cheapest one.

If you keep that model in mind, most of the weird-looking test cases make sense.

## What counts as “cost” here

The pass is trying to shrink the bytes used to encode global indices. The byte-layer LEB contract, including why official-compatible overlong input decoding is separate from encoder size accounting, lives in [`../../../binary/leb128-and-integer-encoding.md`](../../../binary/leb128-and-integer-encoding.md).

In ordinary production mode, the important encoder-size thresholds are:

| Global index range | Estimated encoded size |
| --- | --- |
| `0..127` | `1` byte |
| `128..16383` | `2` bytes |
| later ranges | more bytes as needed |

So moving a frequently used global from index `130` to index `10` can matter.
Moving a global from index `10` to index `40` does not change the real encoded size at all, because both are still one-byte ULEBs under the encoder-size model.

That is why the production pass has a hard cutoff at `128` globals.

## Why the public pass bails out below `128`

The first large behavior fork in `ReorderGlobals.cpp` is:

- if there are fewer than `128` globals and the pass is not in `always` mode, return immediately

Binaryen’s reasoning is simple:

- if every global index still fits in one byte, then a pure size-driven reorder cannot help

This is one of the most important negative facts in the dossier.

A lot of first guesses about the pass are wrong because they silently assume:

- “if order changes, the pass will reorder”

But the actual public Binaryen rule is closer to:

- “if order changes but the real index encoding cost does not, the public pass may deliberately do nothing”

## The important TODO hidden inside that early return

The source comment on that early return also says:

- Binaryen still needs to sort here to fix dependencies sometimes

That sentence matters.
It means the public pass today is not “the always-correct global-order fixer.”
It is specifically the public size-driven late reorder, and that sometimes conflicts with the need to repair declaration validity on tiny modules.

## Why `reorder-globals-always` exists

`reorder-globals-always` removes the public cutoff and uses a smooth synthetic size model.

Its main jobs are:

- make small test modules visibly reorder,
- make internal callers able to repair global order even when the public pass would no-op.

The source comment says the `always` mode is mainly useful for testing.
But `GlobalStructInference.cpp` shows a real internal use too: after adding helper globals, it runs `reorder-globals-always` in a nested pass runner so the new globals appear before their users.

So the best mental model is:

- `reorder-globals` = public late size pass
- `reorder-globals-always` = test/internal helper that still sorts small modules

## The real-vs-`always` size formulas

## Real production formula

For each global in the candidate order, Binaryen multiplies:

- the true observed use count of that global
- by the current estimated LEB byte size of that index

Then it sums those values.

So if a global is used a lot, later positions get expensive faster.

## `always` formula

In `always` mode, Binaryen uses:

- `1.0 + i / 128.0`

That means later indices become gradually more expensive even before a real LEB jump would happen.
The pass comment explicitly says this is unrealistic but smooth.

A useful beginner summary is:

- public mode uses the real step-function cost model
- `always` mode uses a fake smooth model to make testing and internal fixups practical

## Dependency order: what must stay before what

Binaryen builds dependencies only from `GlobalGet` inside non-imported global initializers.

If one global initializer reads another global, then the read target must appear earlier.
For example:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (global.get $a))
```

`$b` may be hotter than `$a`, but `$b` still cannot move before `$a`.

That is why the pass is fundamentally a **topological sort problem with a cost model on top**, not just a declaration popularity sort.

## The four candidate ranking strategies

Binaryen generates candidate orders using four different ranking stories.

| Candidate | Custom count idea | Why Binaryen tries it |
| --- | --- | --- |
| zeroes | treat all globals as equally hot | preserve original order when profitability is unclear |
| raw counts | sort by actual observed heat | simple greedy baseline |
| summed dependents | add full dependent counts to a prerequisite | reward globals that unlock very hot dependents |
| exponential dependents | add discounted dependent counts with factor `0.095` | reward unlocks, but more conservatively |

Important detail:

- these custom counts only guide the search
- the final winner is still judged on the true observed counts

## Why Binaryen needs more than raw greed

Imagine four globals:

- `$a`
- `$b` depends on `$a`
- `$c` depends on `$b`
- `$other` is independent

Suppose:

- `$other` is hotter than `$a`
- but `$c` is much hotter than everything else

A raw greedy policy might emit `$other` first because it is the hottest currently legal choice.
But a less greedy strategy can emit `$a` first, then `$b`, then `$c`, which may reduce the overall encoded-index cost more.

That is exactly the kind of case the shipped lit tests exercise.

## Original-ish order is a real optimization option, not a fallback accident

Binaryen’s first candidate sets all counts to zero.
That means it keeps the closest dependency-valid version of the original order.

Why bother?

Because sometimes the more aggressive candidates do not actually improve the true cost.
And when the final estimated cost is equal, Binaryen prefers the original-ish order to avoid pointless churn.

So “keep the old order” is part of the intended search space, not just what happens when nothing changes.

## Imports-first is absolute

The comparator used in `doSort(...)` always puts imported globals before defined globals.

Even if a defined global is much hotter, Binaryen will not move it above an imported global in IR order.
The source comment also notes that the binary writer would enforce imports first anyway, but doing it in the IR makes the final layout visible sooner.

That means there are two separate hard ordering rules before profitability even starts:

- import prefix ordering
- initializer dependency ordering

Only after those rules are satisfied does heat begin to matter.

## Original order is also the tie-break inside each candidate sort

Inside `doSort(...)`, once Binaryen has filtered down to two currently legal globals with equal custom counts, it breaks ties using the original indices.

So the pass is stable in two different ways:

- inside each candidate, equal-ranked choices preserve original order
- across candidates, equal final sizes preserve the earliest candidate, which is the original-ish one

That is why the pass tends to avoid unnecessary churn when profitability is ambiguous.

## What the lit tests most clearly demonstrate

## `reorder-globals.wast`

This file mostly uses `--reorder-globals-always` and therefore isolates the sorting logic without needing 128+ globals.

It clearly demonstrates:

- raw heat moving an independent global earlier
- `global.set` contributing to heat
- dependencies blocking otherwise-hot moves
- mixed independent-plus-dependent cases
- imports staying first
- original-order tie preference
- sum-based non-greedy wins

## `reorder-globals-real.wast`

This file proves the actual public cutoff behavior.

It clearly demonstrates:

- a 129-global module where production `reorder-globals` really reorders
- a 129-global module where greedy ordering really is best
- a 127-global module where the public pass intentionally leaves the order unchanged

That last case is especially important for future Starshine parity work.

## One unresolved test-surface gap

The source computes an exponential dependent-count candidate.
I did not find a shipped test that cleanly says:

- “this exact case is why the exponential candidate exists”

So the safest summary is:

- the exponential candidate is a real source-level contract,
- but the lit tests I found more clearly justify the zero/raw/sum/public-cutoff behavior than they isolate an exponential-only win.

## How this differs from `string-gathering`

`string-gathering` also moves globals, but for a narrower reason:

- put defining string globals before users so the module validates

`reorder-globals` is different:

- optimize the final declaration order for index-encoding cost, subject to the hard ordering constraints

A beginner-friendly summary is:

- `string-gathering` = validity-first local reorder
- `reorder-globals` = late profitability reorder

## What a future Starshine port should preserve from this subtopic

A future port should keep all of these distinctions intact:

- public pass vs `always` helper are not the same thing
- below `128` globals, public Binaryen may do nothing at all
- dependencies come before profitability
- imports come before profitability
- raw heat is only one candidate heuristic, not the whole algorithm
- original order is deliberately preserved on ties

If Starshine chooses to deviate from any of those, the deviation should be documented explicitly as policy rather than presented as if it were Binaryen parity.

## Sources

- [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md)
- [`../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`](../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md)
- [`../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md`](../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
