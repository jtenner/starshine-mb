---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ./0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/optimize-added-constants/index.md
  - ../../binaryen/passes/optimize-added-constants/starshine-port-readiness-and-validation.md
---

# `optimize-added-constants` port-readiness follow-up

## Question

The plain `optimize-added-constants` dossier was source-correct but still stopped at a status / port-map page. What should a future Starshine implementation slice actually do first, and which exact local code surfaces must be connected to Binaryen's direct-address contract?

## Findings

- The chosen pass is plain `optimize-added-constants`, not `optimize-added-constants-propagate`.
- The current-main Binaryen recheck did not reveal teaching-relevant drift from the 2026-04-24 `version_129` contract.
- Binaryen's plain pass remains a memory-address canonicalizer:
  - hard-require `--low-memory-unused`,
  - inspect `Load` / `Store` pointer operands,
  - fold `base + small_const` and `small_const + base` into `MemArg.offset`,
  - require the added constant and merged total offset to stay below `LowMemoryBound`,
  - normalize constant pointer plus offset only when unsigned overflow is impossible,
  - leave local-pair propagation to the sibling pass.
- Starshine currently keeps `optimize-added-constants` in `pass_registry_removed_names()` and rejects it honestly.
- The local implementation-readiness hinge is already present in options and HOT memory infrastructure:
  - CLI / config: `src/cli/cli.mbt`, `src/cmd/cmd.mbt`.
  - registry status: `src/passes/optimize.mbt`.
  - HOT op surface: `src/ir/hot_core.mbt`, `src/ir/hot_side_tables.mbt`, `src/ir/hot_builders.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`.
  - payload / roundtrip / validation: `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/wast/lexer.mbt`, `src/wast/keywords.mbt`, `src/validate/typecheck.mbt`.

## Wiki changes made from this research

- Added `docs/wiki/raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/optimize-added-constants/starshine-port-readiness-and-validation.md`.
- Refreshed the plain pass overview, Binaryen strategy, shape catalog, Starshine strategy, pass index, tracker, top-level wiki index, and wiki log.

## Recommended future implementation ladder

1. Keep the removed-name behavior until a real pass owner and tests exist.
2. Add an analyzer-only slice that reports direct fold candidates without mutating.
3. Add direct `Load` / `Store` address folding for `i32.add(base, const)` and commuted forms.
4. Add existing-offset accumulation and strict merged-offset rejection.
5. Add constant-pointer normalization with separate memory32 / memory64 overflow checks.
6. Add Binaryen-oracle compare lanes using `--low-memory-unused` and no-memory / memory64 negatives.
7. Only after plain mode is stable, start the sibling `optimize-added-constants-propagate` local-pair analysis.

## Uncertainty

The only material local design question is whether Starshine should honor its configurable `low_memory_bound` for this pass or freeze Binaryen's `1024` cutoff in parity mode. Until that is decided, the validation bridge recommends matching Binaryen's constant for oracle comparisons and treating configurability as a project-specific extension.
