# `multi-memory-lowering` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages  
_Primary raw source:_ [`../binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md`](../binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md)

## Question

The existing `multi-memory-lowering` dossier explained Binaryen's one-combined-memory transform, but it was still classified as `dossier` and future Starshine implementers had to infer the safe first slice and validation ladder from scattered overview, WAT-shape, and status text. This note asks:

- What is the smallest faithful Starshine implementation slice?
- Which local code surfaces already exist?
- Which Binaryen caveats must stay visible in the strategy pages?
- What health updates keep the pass internally consistent with neighboring memory docs?

## Findings

### Source recheck

A 2026-04-26 current-`main` recheck of official Binaryen `MultiMemoryLowering.cpp`, `pass.cpp`, `passes.h`, and the two dedicated lit files found no teaching-relevant drift from the 2026-04-25 / `version_129` dossier.

The important upstream contract remains:

- skip zero- or one-memory modules;
- require compatible memory properties before combining memories;
- preserve only first-memory import/export identity as a supported positive family;
- replace many memories with one combined memory;
- create mutable byte-offset globals for original memories after memory `0`;
- shift active constant data offsets;
- retarget scalar, SIMD, atomic, and bulk-memory operations to the combined memory;
- generate virtual `memory.size` and `memory.grow` helpers;
- move later memory ranges when a non-last memory grows;
- optionally add explicit virtual-bounds traps in the checked sibling;
- disable Binaryen's MultiMemory feature after lowering.

### Starshine status

Starshine currently treats both `multi-memory-lowering` and `multi-memory-lowering-with-bounds-checks` as unknown names: they do not appear in the active registry, boundary-only list, or removed-name list in `src/passes/optimize.mbt`.

Useful prerequisites exist:

- `src/lib/types.mbt` has `MemType`, `MemArg(..., MemIdx?, ...)`, and indexed memory instruction carriers;
- `src/binary/decode.mbt` and `src/binary/encode.mbt` preserve multi-memory bulk-memory indexes;
- `src/validate/typecheck.mbt` types memory operations through the selected memory;
- existing module passes prove Starshine can mutate module-level structures.

The main gaps remain:

- WAT lowering currently defaults several text memory operations to memory `0`, which makes convenient multi-memory text fixtures incomplete;
- no memory-section merge helper exists;
- no helper-global/helper-function generation policy exists for this pass;
- no feature/custom-section cleanup contract is exposed for this transform;
- no tests or backlog slice exist.

## Wiki updates made

- Added `docs/wiki/binaryen/passes/multi-memory-lowering/starshine-port-readiness-and-validation.md`.
- Updated the pass overview page to link the new port-readiness bridge and make the validation ladder less implicit.
- Updated Binaryen strategy and implementation/test-map pages with the 2026-04-26 current-main no-drift recheck.
- Updated WAT shapes with a first-slice caution that unchecked address/data/body lowering should precede helper and checked-sibling work.
- Updated Starshine strategy with a concrete staged implementation plan and exact local code surfaces.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Recommended future Starshine slice

1. Keep both names unknown until a real module pass exists, or add explicit boundary-only entries only if the CLI needs a clearer unsupported-pass diagnostic.
2. Add fixture support for two-memory WAT or build binary/IR fixtures directly.
3. Implement unchecked two-memory, memory32, unshared, unimported/unexported lowering with constant active offsets.
4. Add scalar load/store and simple `memory.init` / `memory.copy` / `memory.fill` retargeting.
5. Add virtual `memory.size` helpers.
6. Add last-memory `memory.grow` helpers.
7. Add non-last `memory.grow` movement and offset-global updates.
8. Add SIMD/atomic coverage.
9. Add checked-sibling traps and preserve the Binaryen overflow caveat explicitly.
10. Decide and test MultiMemory feature/custom-section cleanup.

## Open questions

- Should Starshine match Binaryen's hard unsupported-shape behavior, or produce clearer diagnostics for unsupported imports/exports/mismatched memory properties?
- Should feature cleanup be represented as an IR feature-set toggle, a custom-section rewrite, or both?
- Should WAT multi-memory syntax support land before the pass, or should the pass's first tests use binary fixtures to avoid frontend scope creep?
