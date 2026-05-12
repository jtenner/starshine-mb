---
kind: research
status: supported
last_reviewed: 2026-05-12
sources:
  - ../binaryen/2026-04-23-inlining-primary-sources.md
  - ../binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../../../src/passes/inlining.mbt
  - ../../../../src/passes/inlining_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
  - ../../../../CHANGELOG.md
---

# `inlining` / `inlining-optimizing` wiki overhaul

## Question

The inlining dossiers were source-rich but stale in one important local respect: they still mixed older boundary-only Starshine status with the 2026-05-11 / 2026-05-12 active partial module-pass implementation. What durable wiki shape should future agents use for Binaryen `inlining` / `inlining-optimizing` and the current Starshine `INL` frontier?

## Sources read

- Existing living pages in `docs/wiki/binaryen/passes/inlining/` and `docs/wiki/binaryen/passes/inlining-optimizing/`.
- Raw Binaryen manifests:
  - `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`
  - `docs/wiki/raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`
  - `docs/wiki/raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`
  - `docs/wiki/raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md`
- Research notes:
  - `0161-2026-04-21-inlining-binaryen-research.md`
  - `0121-2026-04-20-inlining-optimizing-binaryen-research.md`
  - `0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md`
  - `0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md`
  - `0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md`
  - `0391-2026-04-26-inlining-port-readiness.md`
- Current Starshine implementation/status files:
  - `src/passes/inlining.mbt`
  - `src/passes/inlining_test.mbt`
  - `src/passes/optimize.mbt`
  - `src/passes/pass_manager.mbt`
  - `agent-todo.md`
  - `CHANGELOG.md`
- Mature dossier patterns from `rse`, `code-folding`, `dae-optimizing`, `vacuum`, and `tuple-optimization`.

## Durable findings

### 1. Binaryen contract is still the shared `Inlining.cpp` engine

The safe tagged-oracle statement remains:

- `inlining` and `inlining-optimizing` share the same upstream `Inlining.cpp` pass class.
- The public split is the `optimize` flag.
- Plain `inlining` scans, classifies, plans, rewrites, repairs, and removes helpers, then stops.
- `inlining-optimizing` performs the same rewrite and then calls the post-inline useful-pass helper: prepend `precompute-propagate`, then rerun the default function-optimization pipeline on changed functions.

### 2. The direct-call planner correction remains important

The reviewed `version_129` contract should continue to teach actual chosen inline actions as reachable direct `call` / `return_call` sites. `ref.func`, `call_ref`, `call_indirect`, and `return_call_ref` still matter, but in different ways:

- `ref.func` and element/table-like uses keep boundaries alive.
- `call_ref` / `call_indirect` forms inside copied code can require tail-call/return repair.
- Older research notes spoke more broadly about precise `call_ref` inlining; the living pages should prefer the stricter 2026-04-23 / 2026-04-25 source-corrected wording unless a later upstream ingest proves a wider planner.

### 3. Starshine is no longer boundary-only for these names

Current local code has an active module-pass owner:

- `src/passes/inlining.mbt` owns both pass summaries and `inlining_run_module_pass(...)`.
- `src/passes/optimize.mbt` registers both `inlining` and `inlining-optimizing` as module passes.
- `src/passes/pass_manager.mbt` dispatches plain `inlining` with `optimize=false` and `inlining-optimizing` with `optimize=true` and trace enabled.
- `src/passes/inlining_test.mbt` has focused public-pipeline coverage for the first slice.

The correct local status is **partial active module pass**, not unimplemented/boundary-only.

### 4. Current Starshine subset

The current implementation covers:

- iterative direct `call` and `return_call` rewrite waves;
- tiny and one-use private defined callee eligibility;
- parameter/body-local appending and local-index remapping into the caller;
- callee `return` to wrapper-block `br` rewriting for the simple subset;
- private helper removal when surviving references disappear;
- function-index rewrites after helper removal;
- an optimizing-mode nested-cleanup approximation with trace evidence;
- exact-`unreachable` private-helper retention/trim predictions, including the shadowed void-cycle result-helper representative refinement.

### 5. Current Starshine gaps

Keep `[INL]001` and `[INL]002` active. The current implementation does **not** have full Binaryen parity:

- no full trivial-instruction-class heuristic parity;
- no flexible/O3 policy parity;
- no no-inline flag handling;
- no partial Pattern A / Pattern B splitter;
- incomplete nested `return_call*` repair;
- no multi-result inlined wrapper typing;
- incomplete label/name collision and annotation/name-section repair;
- no exact Binaryen action filtering / repeated-work caps / giant-function guard parity;
- no exact touched-function-filtered `precompute-propagate` + default function-pipeline scheduler.

### 6. Latest evidence to preserve

The parent-thread artifact is now the current wiki evidence:

- `.tmp/pass-fuzz-inlining-shadow-void-cycle-final`
- command family: `--count 10000 --seed 0x5eed --pass inlining-optimizing --max-failures 200 --keep-going-after-command-failures`
- `9975 / 10000` compared
- `9960` normalized matches
- `15` normalized mismatches
- `0` validation failures
- `0` generator failures
- `25` ignored Binaryen/tool parse/canonicalization command failures:
  - `22` `binaryen-rec-group-zero`
  - `1` `binaryen-bad-section-size`
  - `1` `binaryen-table-index-out-of-range`
  - `1` `binaryen-invalid-tag-index`

The user preference is explicit: Binaryen parse/canonicalization failures are ignored oracle/tool failures, not Starshine semantic failures.

## Wiki changes made

- Reframed both pass landing pages around mature dossier patterns: role, why it matters, beginner summary, current takeaways, evidence, page map, maintenance rule.
- Rewrote Starshine status pages from boundary-only future-port text into current partial active implementation/status pages.
- Added a dedicated `inlining-optimizing/starshine-port-readiness-and-validation.md` page so the optimizing sibling now has a validation/status bridge like mature pass dossiers.
- Updated WAT-shape pages with both Binaryen conceptual shapes and current Starshine subset/gap shapes.
- Updated catalog/log surfaces so future agents do not rediscover the same status correction.

## Uncertainty

- The upstream oracle remains Binaryen `version_129` plus the 2026-04-25/2026-04-26 current-main spot checks. Refresh current upstream before implementing large missing families.
- The remaining 15 mismatches are summarized from the parent-thread artifact; this docs-only overhaul did not rerun compare-pass.
- Exact line anchors in `src/passes/optimize.mbt` / `pass_manager.mbt` are intentionally avoided because the files move frequently; living pages name functions and pass names instead.
