# Binaryen `reorder-globals-always` source-confirmation follow-up

Date: 2026-04-21
Status: source-confirmed follow-up for an existing upstream-only dossier
Pass: `reorder-globals-always`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/ReorderGlobals.cpp` is unchanged on the reviewed surface

## Why this follow-up exists

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/reorder-globals-always/` folder

The tracker no longer had an obvious remaining `none` target, so this thread needed either a new justified expansion or a real follow-up gap inside an existing dossier.

I chose an already-covered follow-up for `reorder-globals-always` because the folder was accurate but still had one real teaching gap:

- it described the sibling split correctly, but it still did not put the exact `< 128` cutoff removal, the exact smooth scoring formula, the strongest shipped lit-backed proof families, the explicit `GlobalStructInference` nested caller, and the current-`main` no-drift result into one compact source-confirmed page
- the closest neighboring `reorder-globals` dossier already had a focused mechanics/proof page, so the sibling dossier still felt one step less explicit even though its contract is also small and sharp

This is therefore a justified source-confirmation follow-up, not a new tracker expansion.

`agent-todo.md` still has **no dedicated `reorder-globals-always` slice**.

## Official source set reviewed

### Core implementation and registration

- Binaryen `version_129` `src/passes/ReorderGlobals.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/passes.h`

### Explicit internal caller

- Binaryen `version_129` `src/passes/GlobalStructInference.cpp`

### Dedicated official test surface

- Binaryen `version_129` `test/lit/passes/reorder-globals.wast`
- Binaryen `version_129` `test/lit/passes/reorder-globals-real.wast`

### Freshness check

- Binaryen current `main` `src/passes/ReorderGlobals.cpp`

## Executive summary

The real `version_129` contract is compact and now source-confirmed in one place:

- `reorder-globals-always` is a separate registered public/test pass name, but it reuses the same `ReorderGlobals.cpp` engine as ordinary `reorder-globals`
- it differs from production mode in two exact ways:
  1. it does **not** take the `globals.size() < 128 && !always` early return
  2. its cost model in `computeSize(...)` is exactly `counts[indices[i]] * (1.0 + (i / 128.0))`
- it still keeps the same dependency-preserving topological sort, imports-first rule, and original-index tie break inside `TopologicalSort::minSort(...)`
- the strongest direct internal proof of why the sibling matters is `GlobalStructInference.cpp`, which literally runs nested `reorder-globals-always` after it adds helper globals
- the shipped lit files prove both the sibling-specific small-module behavior and the contrast with production `reorder-globals`
- current `main` is unchanged on the reviewed `ReorderGlobals.cpp` surface

So the safest beginner summary is:

- Binaryen uses the same global-layout algorithm as `reorder-globals`, but this sibling forces it to run on tiny modules and scores later positions with a smooth fake per-index penalty so the ordering logic becomes visible and useful for tests and fixups.

## Exact implementation facts

## 1. The small-module cutoff really is only removed, not replaced

In `ReorderGlobals.cpp`, the ordinary production early exit is:

- if there are fewer than `128` globals **and** `always` is false, return immediately

That means the by-name distinction is not “different search logic for small modules.”
It is literally the same pass continuing past a bailout that the ordinary production variant takes.

This also explains the shape of the tests:

- the sibling can demonstrate behavior in tiny modules
- the production pass needs `128+` globals before a reorder becomes visible under the real stepped ULEB model

## 2. The smooth scoring formula is exact and tiny

The dossier already taught the smooth model conceptually, but the source is even sharper than that summary implied.
In `computeSize(...)`, `always` mode does:

- iterate the chosen order
- multiply the original true-use count for each global by `1.0 + (i / 128.0)`
- sum those fractional costs

That exact formula matters because the shipped lit comments explain examples using the same `1`, `129/128`, and `130/128` progression.
So the wiki should teach this as a direct source-and-test-confirmed contract, not just a paraphrase.

## 3. The legality rules stay exactly the shared ones

The sibling does **not** relax correctness.
Inside the shared `TopologicalSort::minSort(...)` comparator it still applies these rules in order:

1. imported globals before non-imported globals
2. higher guiding count before lower guiding count
3. original order by original index as the tie break

And all of that still happens under the dependency DAG built from initializer `global.get` traffic.

So `always` means “skip the profitability cutoff,” not “ignore imports or dependencies.”

## 4. The public identity is real even though the engine is shared

`pass.cpp` registers `reorder-globals-always` as its own pass name, with the description that it sorts globals by access frequency even when there are few.
`passes.h` exposes `createReorderGlobalsAlwaysPass()` beside `createReorderGlobalsPass()`.
`ReorderGlobals.cpp` then implements the split as:

- `createReorderGlobalsPass() -> new ReorderGlobals(false)`
- `createReorderGlobalsAlwaysPass() -> new ReorderGlobals(true)`

That is the exact upstream pattern a future local port should preserve.

## 5. The strongest real-world caller is explicit

`GlobalStructInference.cpp` contains the direct nested-use proof:

- when `addedGlobals` is true, Binaryen constructs a nested `PassRunner`
- it adds `reorder-globals-always`
- it marks the runner nested and executes it

The nearby comment says the purpose is to sort the globals so that added ones appear before their uses.

That is stronger and cleaner than the older folder phrasing because it gives a direct source-backed answer to “why does this sibling exist if the ordinary pass already exists?”

## Exact official proof surface from the lit files

## `reorder-globals.wast` proves the sibling-specific small-module behavior

The dedicated sibling-heavy lit file directly proves these families on tiny modules:

- `global.get` heat can move a hotter independent global earlier
- `global.set` traffic counts too
- initializer dependencies beat raw popularity
- mixed independent-plus-chain layouts can move only the independent hot global
- equal-cost cases keep the earlier/original candidate
- the comments and checks explicitly reason in the same smooth `1`, `129/128`, `130/128` model that `computeSize(...)` implements

That makes the file much more than a vague smoke test; it is the direct proof surface for the smooth-score sibling.

## `reorder-globals-real.wast` proves the contrast with production mode

The production lit file explicitly says it needs `128+` globals to see changes.
It then proves two crucial contrast cases:

- a `129`-global case where greedy is not optimal under the real stepped LEB model
- a neighboring case where greedy is optimal and the independent `other` global should move first

That contrast matters for the sibling dossier because it proves what `reorder-globals-always` is *not*:

- it is not the default late-tail profitability surface
- it is the small-module/test/internal-fixup sibling of that surface

## Current-main drift result

I compared the reviewed `version_129` `src/passes/ReorderGlobals.cpp` surface with current `main` on 2026-04-21.
On the reviewed surface there is **no drift**: the file contents match exactly.

That means the current durable teaching contract remains:

- the `< 128` cutoff removal
- the exact smooth formula `1.0 + (i / 128.0)`
- the same imports-first and original-index tie break
- the same shared-engine constructor split

## What this follow-up changes in the living dossier

This follow-up should not change which pass is tracked; it sharpens how the folder teaches the pass:

- add one focused page for the exact cutoff removal, exact smooth scoring formula, lit-backed proof families, explicit nested `GlobalStructInference` caller, and no-drift result
- refresh the landing page to point to that page
- refresh `binaryen-strategy.md` and `implementation-structure-and-tests.md` so they cite the sharper proof surface instead of only the broad sibling summary
- update tracker/index/log entries so future campaign threads can see that this specific source-confirmation gap is now closed

## Sources

- Local repo context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
  - `src/passes/optimize.mbt`
- Existing dossier input:
  - `docs/wiki/raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`
- Official Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderGlobals.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalStructInference.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-globals-real.wast>
- Current-main freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderGlobals.cpp>
