# `signature-refining` port-readiness follow-up

_Date:_ 2026-04-26  
_Status:_ filed back into living wiki pages

## Question

The `signature-refining` folder already had the standard overview, Binaryen strategy, transformed-shape catalog, implementation/test map, and Starshine status page. The remaining gap was practical: a future Starshine implementer still had to infer the first safe local slice, validation ladder, and exact local prerequisites from several pages.

## Sources checked

- `docs/README.md` and `AGENTS.md` for wiki rules.
- `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/raw/research/` for overlapping work.
- Existing `docs/wiki/binaryen/passes/signature-refining/` pages.
- Official Binaryen current-main sources captured in `docs/wiki/raw/binaryen/2026-04-26-signature-refining-port-readiness-primary-sources.md`.
- Starshine local surfaces:
  - `src/passes/optimize.mbt`
  - `src/lib/types.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/validate/env.mbt`
  - `src/validate/typecheck.mbt`
  - `src/binary/encode.mbt`
  - `src/binary/decode.mbt`
  - `src/ir/hot_core.mbt`
  - `src/ir/hot_lift.mbt`
  - `src/ir/hot_lower.mbt`

## Findings

- Binaryen current `main` still matches the 2026-04-24 `version_129` teaching contract for the important parts of `signature-refining`; no source-correction page was needed.
- The Starshine folder lacked a dedicated port-readiness bridge analogous to other recent deep-pass follow-ups.
- The first safe Starshine slice should be registry honesty plus a no-rewrite module analyzer, not a body rewrite.
- The first transformation slice should be a deliberately narrow, private, direct-call-only, no-table, no-import, no-tag, no-subtyping, no-`call_ref`, no-`call.without.effects` param-refinement subset.
- Result refinement, `call_ref`, `return_call_ref`, body fixup locals, and `call.without.effects` import cloning should be later slices because they require broader parser, validator, type-rewriter, and intrinsic infrastructure.
- Local Starshine has `CallRef` at the library/binary/validator/HOT layers but does not expose direct `call_ref` in the WAT AST/parser beside `return_call_ref`; this is a practical fixture gap for future parity tests.
- Local source search found no `call.without.effects` spelling under `src/`, so Binaryen's intrinsic-repair branch is currently a known parity blocker.

## Filed-back wiki updates

- Added `docs/wiki/binaryen/passes/signature-refining/starshine-port-readiness-and-validation.md`.
- Refreshed `docs/wiki/binaryen/passes/signature-refining/index.md` so the page map points at the new bridge.
- Refreshed `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md` so the status page links to the new first-slice / validation plan.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Unresolved questions

- Should Starshine implement direct `call_ref` text parsing before `signature-refining`, or use binary/library fixtures for the first `call_ref` parity slice?
- Should `call.without.effects` be modeled as an intrinsic import in the core IR, or should the first Starshine parity target explicitly exclude it and document the gap?
- Where should a shared nominal function-signature rewriter live so `signature-pruning`, `signature-refining`, and related type-cluster passes can share validation-safe rewrite machinery?

## Commit caveat

This run started with many unrelated local modifications in shared wiki index/log pages and source files. The changes were made, but an atomic commit should be withheld unless those pre-existing changes can be safely isolated.
