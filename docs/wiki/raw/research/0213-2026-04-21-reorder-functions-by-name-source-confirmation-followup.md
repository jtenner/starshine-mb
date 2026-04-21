# Binaryen `reorder-functions-by-name` source-confirmation follow-up

Date: 2026-04-21
Status: source-confirmed follow-up for an existing upstream-only dossier
Pass: `reorder-functions-by-name`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/ReorderFunctions.cpp` is unchanged on the reviewed surface

## Why this follow-up exists

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/reorder-functions-by-name/` folder

The tracker no longer had an obvious remaining `none` target, so this thread needed either a new justified expansion or a real follow-up gap inside an existing dossier.

I chose an already-covered follow-up for `reorder-functions-by-name` because the folder was accurate but still had one real teaching gap:

- its module-order examples were still described partly as source-comparator inference instead of being anchored compactly to the dedicated official lit file
- the tiny but exact public contract deserved one source-confirmed page that put the comparator, the four shipped permutation proofs, the declaration-only boundary, and the no-drift result in one place

This is therefore a justified small-but-real source-confirmation follow-up, not a new tracker expansion.

`agent-todo.md` still has **no dedicated `reorder-functions-by-name` slice**.

## Official source set reviewed

### Core implementation and registration

- Binaryen `version_129` `src/passes/ReorderFunctions.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`

### Dedicated official test surface

- Binaryen `version_129` `test/lit/passes/reorder-functions-by-name.wast`

### Freshness check

- Binaryen current `main` `src/passes/ReorderFunctions.cpp`

## Executive summary

The real `version_129` contract is even smaller and cleaner than the existing folder already suggested:

- `reorder-functions-by-name` is a standalone public pass in the shared `ReorderFunctions.cpp` file
- it overrides `requiresNonNullableLocalFixups() = false` because it only reorders declarations
- its entire algorithm is one `std::sort(module->functions.begin(), module->functions.end(), ...)`
- the comparator is exactly `a->name < b->name`
- the dedicated lit file proves the pass over four concrete declaration permutations of `$a`, `$b`, and `$c`, and every case normalizes to the same ascending lexical order
- the pass does not inspect bodies, direct calls, start, exports, element segments, or any other count-like surface
- current `main` is unchanged on this reviewed surface

So the safest beginner summary is:

- Binaryen alphabetizes the module's function declaration list by internal function name and leaves everything else alone.

## Exact implementation facts

## 1. The public pass is truly separate from `reorder-functions`

`pass.cpp` registers two different public pass names from the same owner file:

- `reorder-functions`
- `reorder-functions-by-name`

The description string for the by-name sibling is:

- useful for debugging

That description is not fluff.
It is the clearest public statement of intent upstream gives this pass.

## 2. The whole algorithm is one comparator

In `ReorderFunctions.cpp`, `ReorderFunctionsByName::run(Module* module)` does just this:

- call `std::sort` over `module->functions`
- compare two entries with `a->name < b->name`

There is no preprocessing step and no repair step.

That also means the sibling's public contract is stricter than broad phrases like “reorder functions lexically” can imply:

- it is not a stable-preserve-original-order pass for ties
- it is not a source-text pretty-printer
- it is not a count-based heuristic with a name fallback

It is simply ascending `Name` comparison over the declaration vector.

## 3. The declaration-only boundary is explicit

The pass also overrides:

- `requiresNonNullableLocalFixups() = false`

That matters because it matches the actual mutation surface.
The pass does not change locals, bodies, or value types.
It only reorders the module's function declaration list.

That declaration-only boundary should be taught explicitly alongside the comparator itself.

## Exact official proof surface from the lit file

The dedicated lit file is stronger than the older folder made fully explicit.
It does not just say “lexical order happens somewhere.”
It checks four concrete module permutations and always expects the same final order.

## Module 1: reverse order normalizes to `$a`, `$b`, `$c`

Input declaration order:

- `$c`
- `$b`
- `$a`

Checked output order:

- `$a`
- `$b`
- `$c`

## Module 2: already sorted order stays `$a`, `$b`, `$c`

Input declaration order:

- `$a`
- `$b`
- `$c`

Checked output order:

- `$a`
- `$b`
- `$c`

## Module 3: middle permutation normalizes to `$a`, `$b`, `$c`

Input declaration order:

- `$b`
- `$a`
- `$c`

Checked output order:

- `$a`
- `$b`
- `$c`

## Module 4: another mixed permutation normalizes to `$a`, `$b`, `$c`

Input declaration order:

- `$c`
- `$a`
- `$b`

Checked output order:

- `$a`
- `$b`
- `$c`

That proves three durable facts directly from shipped upstream tests:

1. ascending lexical order is the intended result
2. already-sorted modules are no-ops
3. the pass is about declaration order only; the checked bodies are the same simple constants before and after

## What the source and tests do **not** show

The reviewed surface also makes the non-goals unusually clear.

It does **not**:

- count direct `call`s
- count `start`
- count exports
- count element-segment function names
- mention `ref.func`
- inspect body complexity
- run a legality or repair phase

Those surfaces belong to the sibling `reorder-functions` dossier, not this pass.

## The real beginner-facing shape story

Because the test surface is so small, the best honest module-shape page should anchor its positive examples to the exact four lit permutations and treat other remarks as source-derived boundaries.

The most important correction is therefore not algorithmic but pedagogical:

- the folder should stop presenting the core positive examples only as comparator inference
- it should present them as directly proven by the dedicated official lit file

## Freshness result

The checked current-`main` `ReorderFunctions.cpp` still matches `version_129` on the reviewed surface.

So the durable conclusion here is:

- `version_129` remains a reliable oracle for this pass today
- no drift note is needed beyond recording that the surface was checked and unchanged

## What this follow-up changes in the living dossier

This follow-up should leave the pass choice unchanged but sharpen the teaching contract:

- add one focused page for the exact comparator, the declaration-only boundary, the four lit-backed permutation proofs, and the no-drift result
- refresh the landing page to point to that page
- refresh `binaryen-strategy.md`, `implementation-structure-and-tests.md`, and `module-shapes.md` so they stop understating the dedicated lit proof surface
- update tracker/index/log entries so future campaign threads can see that this source-confirmation gap is now closed

## Sources

- Local repo context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
  - `src/passes/optimize.mbt`
- Existing dossier input:
  - `docs/wiki/raw/research/0180-2026-04-21-reorder-functions-by-name-binaryen-research.md`
- Official Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderFunctions.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-functions-by-name.wast>
- Current-main freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderFunctions.cpp>
