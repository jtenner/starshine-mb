---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../binaryen/2026-04-23-inlining-primary-sources.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining/starshine-strategy.md
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../../../src/passes/optimize.mbt
---

# `inlining` port-readiness follow-up

## Question

The plain `inlining` folder already had a source-backed dossier, but it was still easy for a future implementer to infer the first Starshine slice from scattered pages. What exact Starshine implementation order and validation ladder should connect Binaryen's whole-module inliner to the current boundary-only local status?

## Method

- Re-read repo docs and wiki schema.
- Reviewed the existing living `docs/wiki/binaryen/passes/inlining/` folder and neighboring `inlining-optimizing`, `inline-main`, `monomorphize`, and `duplicate-function-elimination` pages.
- Rechecked official Binaryen current-main source and tests through `docs/wiki/raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md`.
- Rechecked current Starshine registry/request-guard code in `src/passes/optimize.mbt`.

## Findings

- No teaching-relevant current-main drift was found from the 2026-04-23 tagged `version_129` dossier.
- Plain `inlining` remains a whole-module function-boundary pass, not a HOT peephole.
- The safe Starshine first slice is not “inline every small function.” It is a registry-honest module pass skeleton with one reduced direct-call shape, exact callee-local remap, declaration/root preservation, and a negative test proving `inlining` does not run `inlining-optimizing`'s cleanup suffix.
- `return_call` / `return_call_ref`, nondefaultable locals, split inlining, no-inline flags, rooted helper survival, and dead-helper deletion should be staged after the first direct-call copy/rewrite proof.
- The existing Starshine registry currently tracks `inlining` as boundary-only in `pass_registry_boundary_only_names()` and rejects active HOT pipeline requests in `run_hot_pipeline_expand_passes(...)`; no `src/passes/inlining.mbt` owner exists.

## Durable wiki changes made

- Added `docs/wiki/binaryen/passes/inlining/starshine-port-readiness-and-validation.md` as the dedicated future-port bridge.
- Refreshed the `inlining` overview to link the new port-readiness page and current-main manifest.
- Refreshed `starshine-strategy.md` to point readers from the current boundary-only status to the staged validation plan.
- Appended index/log entries for the new durable page and raw source manifest.

## Validation ladder for a future implementation

1. Registry/request behavior: keep `inlining` boundary-only until a module dispatcher path exists.
2. First positive shape: direct `call` to a one-use, private, defaultable-local callee.
3. First negative shapes: exported/start/ref.func/tabled callee survival and no accidental `inlining-optimizing` suffix.
4. Repair shapes: callee-local remap, return-as-block-value repair, label retargeting, unreachable result typing, and nondefaultable local handling.
5. Tail-call shapes: `return_call` only after ordinary calls are stable.
6. Policy shapes: `no-inline`, `no-full-inline`, `no-partial-inline`, and clone-survival behavior.
7. Split shapes: top-of-function conditional split families.
8. Neighborhood replay: `inline-main`, `monomorphize`, `duplicate-function-elimination`, and `inlining-optimizing` fixtures.
9. Fuzz/parity: `bun scripts/pass-fuzz-compare.ts --pass inlining ...` once the harness has a module-pass lane for this pass.

## Uncertainty

- The future Starshine landing zone is still an implementation decision: either a new module-pass dispatcher beside existing module passes or a broader boundary scheduler.
- Exact line anchors in `src/passes/optimize.mbt` are unstable because there are unrelated local edits in the worktree; the living page therefore names functions and files instead of pretending a stable line number is guaranteed.
