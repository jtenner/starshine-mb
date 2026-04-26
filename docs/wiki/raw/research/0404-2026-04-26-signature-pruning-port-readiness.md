---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-signature-pruning-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ./0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/signature-pruning/index.md
  - ../../binaryen/passes/signature-pruning/starshine-port-readiness-and-validation.md
related:
  - ../../binaryen/passes/signature-pruning/binaryen-strategy.md
  - ../../binaryen/passes/signature-pruning/starshine-strategy.md
---

# `signature-pruning` Starshine port-readiness follow-up

## Question

The existing `signature-pruning` dossier had good Binaryen strategy coverage and a Starshine status page, but future implementers still had to infer:

- what a safe first Starshine slice should include;
- what should remain boundary-only until closed-world type infrastructure exists;
- which local source files would be exercised by a real port;
- how to validate the direct-call slice before the harder `call_ref`, constant-actual, and localization families.

## Research performed

- Re-read `AGENTS.md`, `docs/README.md`, `docs/wiki/`, `docs/wiki/index.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, the existing `signature-pruning` folder, neighboring `signature-refining` and `dead-argument-elimination` pages, and the numbered research archive before choosing the pass.
- Rechecked official Binaryen current-main `SignaturePruning.cpp`, `signature-pruning.wast`, `pass.cpp`, and helper surfaces against the earlier `version_129` contract.
- Rechecked the local Starshine registry, type, call, validator, WAT, and binary-codec surfaces that a future port would touch.

## Findings

- No teaching-relevant Binaryen drift was found on 2026-04-26. The source-backed pass remains a closed-world, GC-gated, no-table module pass that prunes params per nominal function heap type.
- The most useful wiki improvement is a dedicated Starshine port-readiness and validation bridge, parallel to the existing `signature-refining` bridge.
- The first safe Starshine slice should not be a HOT peephole. It should stay boundary-only until Starshine has an explicit closed-world module pass able to rewrite `TypeSec`, `FuncSec`, direct calls, callee locals, and validation surfaces together.
- A narrow future first mutating slice can start with one private function heap type, no tables, no imports, no public exposure, no tags/continuations/JS intrinsic blockers, no `call_ref`, and direct `call` users only.
- `call_ref`, constant-actual promotion, delayed operand localization, sibling heap-type aggregation, and public/subtype blocker precision should be follow-up slices, not hidden in the first slice.
- The local WAT parser/lowerer status still needs a direct `call_ref` fixture check. The library and binary surfaces have `CallRef(TypeIdx)`, but future port tests should not assume direct `call_ref` text fixtures are enough until that path is verified.

## Files updated

- Added [`../../binaryen/passes/signature-pruning/starshine-port-readiness-and-validation.md`](../../binaryen/passes/signature-pruning/starshine-port-readiness-and-validation.md).
- Refreshed the `signature-pruning` overview and Starshine strategy pages so the bridge is discoverable.
- Updated the main wiki index, pass folder map, tracker, wiki log, and changelog.

## Follow-up risks

- A faithful port needs a shared closed-world signature/type rewrite engine. Implementing only argument deletion in function bodies would create invalid nominal type and call-site mismatches.
- `call_ref` is semantically central upstream, but the safest Starshine test path may initially be library/binary rather than WAT text until direct text lowering is confirmed.
- Constant-actual promotion and delayed localization can expose second-cycle removals. If Starshine chooses a smaller first slice, the docs and tests must call that out instead of claiming full Binaryen parity.
