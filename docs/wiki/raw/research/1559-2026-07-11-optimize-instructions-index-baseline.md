---
kind: research
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
related:
  - ../../binaryen/passes/optimize-instructions/starshine-strategy.md
---

# Optimize-instructions reusable-index baseline

## Scope

This is the `[OI-INDEX]001` maintenance and performance baseline taken from reviewed `main` at `18ed47039562bad66304174f04432199cc5ce2b4`. It records implementation debt, not a behavior-gap count. Existing tests remain compatibility evidence; the measured matrix is not a template for new rules.

## Static inventory

A source scan of `src/passes/pass_manager.mbt` found:

- 104,839 total lines in the raw/HOT dispatcher file.
- 41 `RawOi*Fact::from_instrs(...)` definitions.
- 27 direct `RawOi*Fact::from_instrs(body...)` calls; additional calls consume renamed intermediate bodies or occur in helper pipelines.
- 46,567 lines in the idempotent-call raw admission block, from `RawOiIdempotentCallStackOperandKind` through the old `RawOiIdempotentCallSelfSelectFact::proves_hot_replay` implementation.
- 10 explicitly six/seven-operand helper definitions.
- 22 arity/signature-specific fact structs.
- 362 `RawOiIdempotentCallOperandAdmissionKind` variants.
- approximately 494 array-pattern matcher arms in that block.

The top-level raw OI bridge separately computes descriptor rewrites, scalar-memory-copy regions, lowered statistics, atomic/local-tee hazards, stack-bulk facts, memory/local-tee facts, stack call/binop facts, call-ref facts, GC forwarding/localization facts, idempotent-call admission, stack-carried effects, and const-offset-load/call facts. Several of those producers walk the same body independently.

## Existing reusable proof substrate

The HOT implementation already owns the semantic proof needed for idempotent calls:

- `OiIdempotentCallEqualityFact::from_nodes` compares same-callee calls and all dynamic operands.
- `OiIdempotentCallOperandTreeFact` recursively proves the represented operand tree is foldable.
- `OiConsecutiveInputEqualityFact` keeps structural equality separate from intervening-effect and invalidation proof.
- shared HOT use-def/effects overlays are revision-keyed through `HotAnalysisCache` and `hot_revision_current`.
- module context already caches function signatures, annotations, globals, and other module-level type information.

The raw matrix therefore acts primarily as admission around the stack-carried-effect skip. It should be replaced by broad indexed candidate discovery; HOT must continue to decide exact equality, typing, effects, removability, ordering, traps, and invalidation.

## First migration boundary

The first reusable index should be built once for the current function snapshot/revision and collect semantic anchors, initially direct call sites and select roots. The idempotent-call query may admit HOT when it finds at least two calls to the same annotated callee plus a compatible select root. This is candidate discovery only. It must not claim operand equality or safety.

After the generic path is compatibility-green, delete the 46,567-line raw matrix, its 362-way admission enum, arity-specific signatures, and precedence dispatch rather than preserving a fallback.

## Performance baseline

`src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` now contains a deterministic 1,200-repetition large flat OI fixture. It is intended to remain the before/after smoke benchmark while scanner work is migrated.

Both baseline compilation attempts failed to finish within 600 seconds on July 11, 2026:

- `moon test src/passes_perf_long` — timed out after 600 seconds while compiling the current wasm-gc/default target.
- `moon test --target native src/passes_perf_long` — timed out after 600 seconds while compiling the current native target.

Those timeouts include compilation and are not pass-local runtime measurements. They are nevertheless a concrete build-pressure baseline consistent with the generated matcher history. Runtime timing must be re-run after deleting the matrix, then supplemented with native CLI/Binaryen pass-local comparisons.

## Prioritized scanner migration order

1. Idempotent-call admission: largest code/matcher cost; HOT already owns the deep proof.
2. Shared function statistics and root anchors: used by coarse skip and candidate routing.
3. Stack-carried effect and direct-call/call_ref candidate families: share call positions, signatures, and stack provenance.
4. Memory/local-tee/bulk-memory families: share memory roots, local accesses, and effect summaries.
5. GC/descriptor families: share call sites, module type/annotation facts, and GC root kinds.

No new whole-body scanner should be added for a single behavior shape.

## First migration result

The first follow-up completed the idempotent-call deletion boundary:

- `RawOiFunctionRevisionFactIndex` now discovers call/select candidates once per immutable raw body snapshot.
- HOT remains the sole owner of dynamic operand equality and safety proof.
- direct 8/9-operand, middle-tree 8-operand, separated two-tree 9-operand, and mismatch fixtures match Binaryen v130.
- existing six-operand compatibility passes 128/128, seven-operand compatibility passes 7/7, and focused idempotent tests pass 24/24.
- the 46,567-line matrix, 362 admission variants, 22 arity-specific signature facts, and all explicit six/seven dispatch helpers are gone.
- `pass_manager.mbt` is 58,443 lines after the migration, down from 104,839.
- raw `from_instrs` definitions fell from 41 to 40 and direct body calls from 27 to 26.
- the focused 1,200-repetition fixture completes in 0.798 seconds on cached native execution and 8.237 seconds on the default target including rebuild work; the pre-deletion default and native package builds both exceeded 600 seconds.

These timings demonstrate the compile/build-pressure win and a usable runtime smoke floor. They do not replace the required native CLI/Binaryen pass-local comparison or broader scanner migration.