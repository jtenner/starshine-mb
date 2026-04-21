# Binaryen `reorder-functions` source-confirmation follow-up (`version_129`)

- Date: 2026-04-21
- Researcher: OpenAI Codex via recursive wiki campaign
- Scope: verify whether the existing `reorder-functions` dossier already taught the full real `version_129` contract well enough, and if not, close the remaining source-confirmed gap with a compact owner / boundary / omission follow-up.

## Why this follow-up was worth doing

The pass tracker no longer has obvious `none` targets, so the campaign now needs either a justified upstream-only expansion or a justified major-gap follow-up inside an already-covered dossier.

`reorder-functions` already had a decent upstream-only dossier, but it still benefited from one more source-confirmed pass over the exact implementation file because three beginner-relevant details were still too easy to blur together:

1. **where the whole contract really lives** — almost all of it is one tiny `ReorderFunctions.cpp` file plus two registration lines in `pass.cpp`;
2. **what the exact counted surfaces are, and why they are split the way they are** — direct `call` traffic is gathered in a function-parallel walker, while start/export/element uses are added later in a serial module pass step;
3. **what Binaryen explicitly does *not* do yet** — `ref.func` and declaration-section mentions are still TODOs in the release oracle, so a future Starshine port should not silently over-implement them while claiming `version_129` parity.

That gap was large enough to justify one compact source-confirmation follow-up page rather than leaving the folder as a small but easy-to-misremember dossier.

## Canonical local context checked first

I re-read the repo guidance and current pass maps before re-opening the pass:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

Result: `agent-todo.md` still has **no dedicated `reorder-functions` slice**, which is worth recording explicitly again because this remains a research-only / boundary-only dossier update rather than an active implementation-plan slice.

## Official sources reviewed

### Release oracle

- Binaryen `version_129` `src/passes/ReorderFunctions.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/reorder-functions-by-name.wast`

### Freshness check

- Binaryen `main` `src/passes/ReorderFunctions.cpp`

## Source-confirmed findings

### 1. The real implementation owner is still one tiny file

The actual `reorder-functions` implementation in `version_129` is almost entirely inside `src/passes/ReorderFunctions.cpp`.

That file contains:

- the top-of-file raw-size vs gzip-size comment,
- the `CallCountScanner` helper,
- the `ReorderFunctions` pass,
- the `ReorderFunctionsByName` sibling,
- and the two pass-constructor functions.

So the honest ownership story is not “a broader pass family spread across many helpers.”
It is “one small file with one tiny counting helper and two tiny orderers.”

### 2. The pass explicitly advertises a raw-size goal with a gzip caveat

The file header still says the pass sorts functions by static use count to reduce wasm binary size, and just as importantly warns that the new order may **increase gzip size**.

That warning is part of the real contract because it tells future readers what Binaryen thinks this pass is optimizing for:

- **smaller encoded function-index references in raw wasm**, not
- general runtime speed, or
- universally better compressed output.

### 3. The only body-side counting surface is direct `Call`

`CallCountScanner` is a `WalkerPass<PostWalker<CallCountScanner>>` that is function-parallel and reports `modifiesBinaryenIR() == false`.

Its only visit hook is:

- `visitCall(Call* curr)`

and that hook increments only `curr->target`.

So the body-side count model is exactly:

- **direct `call` targets only**

not:

- `call_ref`
- `call_indirect`
- `ref.func`
- inferred dynamic callgraph traffic

### 4. Pre-seeding the count map is part of the algorithm, not just incidental setup

Before the parallel call scan runs, `ReorderFunctions::run(Module*)` seeds a `NameCountMap` entry for every function already present in `module->functions`.

That matters because `visitCall(...)` asserts that the target is already present in the map before incrementing it.
So the release oracle depends on this exact split:

- first, create one count slot per function name,
- then, run the direct-call scanner in parallel,
- and only increment existing entries.

This is a tiny detail, but it is part of why the implementation stays safe and simple without concurrent map growth.

### 5. Non-body count sources are added later and are only three kinds

After the direct-call scan, the pass adds three serial module-level sources:

1. `module->start`
2. function exports (`ExternalKind::Function` only)
3. function names found by `ElementUtils::iterAllElementFunctionNames(...)`

This confirms the count model precisely:

- direct `call`
- start
- function export
- element-segment function name

and **nothing else**.

### 6. The two TODO omissions are still part of the release contract

The same `version_129` file still contains these explicit TODOs immediately after the element-segment count step:

- count all `RefFunc` as well
- count the declaration section as well, which adds another mention

These TODOs are important because they define the current omission boundary. A faithful `version_129` port should preserve the fact that those surfaces are *not* counted yet unless the port deliberately chooses to diverge and documents that divergence.

### 7. The comparator is exactly “descending count, then descending name”

The pass sorts `module->functions` with a comparator that:

- prefers larger counts first,
- and on equal counts prefers lexicographically larger names first.

So the stable rule is:

- primary key: descending static-use count
- tie-breaker: descending internal function name

That tie-break is easy to understate, but it matters for deterministic parity.

### 8. The pass explicitly says it does not need local fixups

`ReorderFunctions` overrides `requiresNonNullableLocalFixups()` and returns `false`.
The sibling `ReorderFunctionsByName` does the same.

That is a compact but useful source-confirmed signal:

- these passes reorder function declarations only,
- they do not mutate function contents,
- and Binaryen does not treat them as passes that can create new nondefaultable-local repair obligations.

### 9. Public registration is still just two honest lines in `pass.cpp`

`pass.cpp` still registers:

- `reorder-functions-by-name` as “sorts functions by name (useful for debugging)”
- `reorder-functions` as “sorts functions by access frequency”

That wording remains the best user-facing summary of the family split:

- lexical debugging order vs
- static-use-count layout order

### 10. Current `main` still matches the reviewed `version_129` file

A direct raw-source comparison of `version_129` and current `main` `src/passes/ReorderFunctions.cpp` found no implementation drift.

That means the release-oracle explanation in the living dossier still matches current upstream on the reviewed surface.

## What changed in the living wiki

This follow-up is being absorbed into the `reorder-functions` folder by:

- adding a dedicated focused page on exact count surfaces, ordering, omissions, and non-fixup boundaries;
- refreshing the landing page and strategy page so that compact source-confirmed boundary summary is easier to find;
- updating the shared tracker and indexes so future threads can see that this particular follow-up gap is now closed.

## Durable conclusions

- Binaryen `version_129` `reorder-functions` is still a **tiny declaration-order pass** centered almost entirely in `ReorderFunctions.cpp`.
- The real count model is still just four surfaces:
  - direct `call`
  - start
  - function export
  - element-segment function name
- `ref.func` and declaration-section mentions are still **explicit TODO omissions**.
- Determinism depends on **descending-name tie breaks** when counts are equal.
- The pass advertises a **raw wasm size** goal while explicitly warning about possible **gzip regressions**.
- Both reorder-functions siblings explicitly say they **do not require nonnullable-local fixups**, reinforcing that they only reorder declarations rather than mutating bodies.
- `agent-todo.md` still has **no dedicated `reorder-functions` slice**.

## Sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- Binaryen `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
- Binaryen `main` freshness check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
