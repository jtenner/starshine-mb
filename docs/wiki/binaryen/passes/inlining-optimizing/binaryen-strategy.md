---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/binaryen-strategy.md
  - ../precompute-propagate/index.md
---

# Binaryen `inlining-optimizing` Strategy

## Source rule

Use Binaryen `version_129` as the tagged oracle; the public release horizon now reaches `version_125`, but the 2026-04-25 current-main implementation/test-map bridge still records no teaching-relevant drift for the optimizing suffix contract. The owner is the shared `src/passes/Inlining.cpp`; the unique optimizing suffix is in `src/passes/opt-utils.h`.

Primary URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>

## One-sentence contract

Binaryen `inlining-optimizing` is the shared whole-module inliner plus a filtered post-inline rerun that prepends `precompute-propagate` and then runs the default function optimization pipeline on touched functions.

## What it inherits from plain `inlining`

The optimizing variant inherits every core obligation from [`../inlining/binaryen-strategy.md`](../inlining/binaryen-strategy.md):

- module-wide function summaries;
- root/ref/use accounting;
- direct `call` / `return_call` chosen-action planning in reviewed `version_129`;
- layered tiny/one-use/trivial/flexible heuristics;
- optional narrow partial Pattern A/B splitting;
- structured callsite rewrite;
- local, label, return, tail-call, reachability, EH, and type repair;
- dead private-helper cleanup.

A port that only implements the suffix is not an inliner. A port that only implements the inliner is not `inlining-optimizing`.

## What `optimizing` adds

`OptUtils::optimizeAfterInlining(...)` / the useful-pass helper:

1. optionally validates before nested work in debug mode;
2. creates a filtered runner for changed functions;
3. marks the runner nested;
4. prepends `precompute-propagate`;
5. reruns the default function optimization pipeline;
6. optionally validates after nested work.

That suffix immediately cleans up debris from copied bodies:

- constant-exposed branches and scalar ops;
- redundant local traffic;
- dead branch shells;
- code-folding opportunities;
- merge-blocks opportunities;
- RSE opportunities;
- casts and heap/local cleanup exposed by inlining.

## Scheduler placement

In the canonical no-DWARF post-pass cluster, the relevant order is:

1. `dae-optimizing`;
2. `inlining-optimizing`;
3. `duplicate-function-elimination`;
4. `duplicate-import-elimination`;
5. `simplify-globals-optimizing` / late global cleanup;
6. `remove-unused-module-elements` and later tail cleanup.

The placement matters because `inlining-optimizing` changes the function graph before duplicate function/import and module-element cleanup.

## Saved `-O4z` nested evidence

Earlier repo-local debug-log review of the interval between top-level `inlining-optimizing` and top-level `duplicate-function-elimination` recorded repeated nested cleanup:

- `5` nested `ssa-nomerge`;
- `5` nested `code-folding`;
- `10` nested `local-cse`;
- `10` nested `merge-blocks`;
- `15` nested `precompute-propagate`.

The exact count is less important than the structural fact: one top-level pass includes a nested function-pipeline rerun, not merely a call rewrite.

## Strategy implications for Starshine

A faithful Starshine implementation needs two validated layers:

### Core inline layer

- full Binaryen eligibility and action filtering;
- direct-call planning baseline;
- partial split support;
- repair for returns/tail calls/labels/nondefaultable locals/multi-results;
- exact helper deletion behavior.

### Optimizing suffix layer

- exact touched-function set;
- real `precompute-propagate` equivalent first;
- default function pipeline rerun only on touched functions;
- no broad mutation of untouched functions;
- trace/evidence that distinguishes caller, callee, removed helper, and untouched functions.

Current Starshine has a partial core and an approximate suffix. That is why the page status is `working`, not `supported` or `accepted`.
