---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
related:
  - ./index.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `duplicate-function-elimination` Strategy

## Upstream Source Rule

- Primary source: Binaryen `version_129` `src/passes/DuplicateFunctionElimination.cpp`.
- The upstream pass is module-wide and hashes defined functions first, then exact-compares only inside each hash bucket.

## Merge Strategy

- Consider defined functions only.
- Group them by function hash.
- Inside each bucket, use stable first-survivor-wins selection.
- Exact equality is still required before replacement; hash equality only narrows the candidate set.
- After replacements are chosen, remove duplicates and rewrite surviving function references across the module.

## Iteration Budget

- Binaryen is not always single-round here.
- The pass has an internal iteration limit based on optimize or shrink level:
  - default direct explicit pass execution without optimize or shrink flags: one round
  - `optimizeLevel >= 2` without size bias: up to `10` rounds
  - `optimizeLevel >= 3` or `shrinkLevel >= 1`: effectively unbounded until no more replacements appear
- This matters because the no-DWARF `-O` / `-Os` pipeline runs with `shrinkLevel=1`, so each DFE slot can iterate more than the direct explicit pass does.

## Rewrite Surface

- After duplicate removal, upstream rewrites all surviving function-name references through `OptUtils::replaceFunctions(...)`.
- The pass itself does not do local peepholes or lifted-IR rewrites; it delegates to module-wide function-reference replacement after survivor selection.

## Practical Rule For This Wiki

- Keep explicit-pass research separate from no-DWARF optimize-path research.
- "Direct DFE parity" means matching the explicit pass surface.
- "Pipeline DFE parity" means also respecting Binaryen's larger option-dependent iteration budget inside the no-DWARF pathway.

## Sources

- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
- Binaryen `version_129` no-DWARF pipeline source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
