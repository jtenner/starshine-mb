---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-break-refresh.md
  - ./2026-07-13-flatten-version-130-mixed-try-tail-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue type as one concrete `Type` in both its `Break` and legacy `Try` paths. The branch payload is evaluated before the branch, stored through the named-target break temp, and removed from the branch. Concrete do/catch fallthrough results are independently stored by the try path. Prelude reconstruction then ensures branch-selected and fallthrough-selected values reach the final result without evaluating either producer twice.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-branch-target.wat` probe carries an `(i32, i64)` vector through a plain branch to a legacy-try label while the do fallthrough and catch fallthrough independently produce the same vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms ordered tuple construction before the branch, payload removal, void try output, per-region fallthrough routing, and a final shared result channel.

## Local interpretation

HOT repeats one tuple-valued node id across scalar payload/result slots, while function locals remain scalar. Starshine therefore admits a multivalue try-label branch only when the try has one exclusive outer result span, all result lanes are defaultable, every label use is a plain `br`, and each branch payload is either an exact independently scalar vector or one exact exclusively owned `TupleMake` repeated across every payload slot. Each tuple component must have a supported scalar origin with exact lane type. Components spill once in source order, the tuple shell is deleted, the branch payload is cleared, and the same typed scalar-local vector receives independently scalar or separately owned tuple-made fallthrough tails from either try region.

This does not admit conditional/table try exits, shared or mixed tuple branch ownership, nondefaultable lanes, arbitrary whole-tuple single producers, represented typed catch payloads, or exceptional transfers.
