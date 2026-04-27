# `type-finalizing` port-readiness bridge

_Date:_ 2026-04-27  
_Status:_ absorbed into living wiki pages  
_Related pass:_ `type-finalizing`

## Question

The existing `type-finalizing` dossier was source-correct, but it stopped at a status/strategy map. What should future Starshine work know before turning the local boundary-only name into a real module pass?

## Sources reviewed

- Existing wiki pages under `docs/wiki/binaryen/passes/type-finalizing/`.
- Existing raw manifest: `docs/wiki/raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`.
- New current-main source manifest: `docs/wiki/raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md`.
- Local source surfaces:
  - `src/passes/optimize.mbt`
  - `src/lib/types.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/wast/module_wast.mbt`
  - `src/validate/env.mbt`
  - `src/validate/typecheck.mbt`
  - `src/binary/encode.mbt`
  - `src/binary/decode.mbt`

## Findings

- Upstream current-main still matches the 2026-04-24 teaching contract: `type-finalizing` is GC-gated, module/type-section scoped, private-type-only, and leaf-only in finalizing mode.
- The body of the pass is still a tiny `GlobalTypeRewriter` subclass that toggles `setOpen(!finalize)` and updates the module globally.
- Binaryen's sibling spelling remains `type-unfinalizing`; Starshine's local registry spelling remains `type-un-finalizing`.
- Starshine already has final subtype representation and fixture support in parser/lowering/pretty-printer/validator/binary surfaces, but no owner pass and no coherent type-graph rewrite helper equivalent to Binaryen's `GlobalTypeRewriter`.
- The first useful Starshine bridge is a validation plan, not a HOT peephole plan.

## Durable wiki updates made

- Added `docs/wiki/binaryen/passes/type-finalizing/starshine-port-readiness-and-validation.md`.
- Updated the `type-finalizing` landing page and Starshine strategy page to point at the new validation bridge.
- Updated top-level and pass-specific wiki indexes plus the tracker/log so future agents do not treat the missing first-slice validation ladder as open.

## Recommended future implementation sequence

1. Keep direct requests rejected until a module pass exists.
2. Add a no-op analyzer/status slice only if the team wants harness plumbing before mutation.
3. Implement a narrow private-leaf finalization slice with explicit public/non-leaf negatives.
4. Reuse or create shared type-graph rewrite infrastructure instead of embedding a one-off remapper.
5. Add sibling-aware tests before deciding whether local `type-un-finalizing` should remain hyphenated or gain a Binaryen-spelling alias.

## Caveats

- This research did not define Starshine's final private-type visibility rule; it only states that the future rule must match Binaryen's observability boundary closely enough to pass oracle comparisons.
- The finality bit is simple, but the rewrite is not local: every dependent type reference must remain coherent after the type-section mutation.
