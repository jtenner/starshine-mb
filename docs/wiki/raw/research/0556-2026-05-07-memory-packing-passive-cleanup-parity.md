---
kind: research
status: current
last_reviewed: 2026-05-07
sources:
  - ../../../../agent-todo.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/memory_packing_test.mbt
  - ../../../../.tmp/recheck-memory-packing-current/result.json
  - ../../../../.tmp/pass-fuzz-memory-packing-keepgoing/result.json
related:
  - ./0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../binaryen/passes/memory-packing/parity.md
---

# Close `[MP]001` after conservative passive cleanup and index-remap parity work

## Question

Can `[MP]001 - Empty-Segment And Dead Passive-Segment Normalization` be closed on current head?

## Method

Implemented two focused `memory-packing` additions:

- conservative passive-segment cleanup for passive data segments with no non-`data.drop` referrers
- passive data-index remapping (plus `data.drop` -> `nop`) when active segment count changes or dead passive segments are removed

Added focused tests for:

- drop-only passive segment cleanup
- passive `memory.init` index remapping after active segment splitting

Then reran the saved smoke lane and the standard direct compare lane:

- `bun scripts/pass-fuzz-compare.ts --pass memory-packing --count 100 --seed 0xA11D --max-failures 5 --out-dir .tmp/recheck-memory-packing-current`
- `bun scripts/pass-fuzz-compare.ts --pass memory-packing --count 10000 --seed 0x5eed --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-memory-packing-keepgoing`

## Results

### Focused tests

`src/passes/memory_packing_test.mbt` now covers:

- active profitable zero-range splitting
- trap-preserving top-byte retention
- overlap bailout
- dead passive segment removal when only `data.drop` remains
- passive `memory.init` index remap after active splitting

### Saved repro lane

`.tmp/recheck-memory-packing-current/result.json` recorded:

- compared cases: `100 / 100`
- normalized matches: `100`
- mismatches: `0`
- command failures: `0`

So the exact saved mismatch family from `0555` no longer reproduces on current head.

### Direct 10k lane

`.tmp/pass-fuzz-memory-packing-keepgoing/result.json` recorded:

- requested cases: `10000`
- compared cases: `9975 / 10000`
- normalized matches: `9975`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `25`

The remaining failures were all Binaryen/tool-side command-failure classes already seen elsewhere in the repo's direct-pass lanes:

- `binaryen-rec-group-zero`: `21`
- `binaryen-bad-section-size`: `2`
- `binaryen-table-index-out-of-range`: `1`
- `binaryen-invalid-tag-index`: `1`

No semantic `memory-packing` mismatches remained.

## Conclusion

Yes. `[MP]001` can be closed.

Current-head Starshine `memory-packing` is still not a full Binaryen `MemoryPacking.cpp` port, but the specific backlog slice from `0555` is now done:

- saved dead-passive normalization repros are green again
- focused regression coverage exists in-tree
- the direct 10k lane is semantically green on all successfully compared cases
- the remaining non-green noise is Binaryen/tool command-failure noise, not `memory-packing` mismatches

## Remaining boundaries

The pass still does **not** implement the broader passive-segment rewrite engine:

- no passive zero-splitting with replacement `memory.init` / `memory.fill`
- no drop-state global machinery
- no imported-memory `zeroFilledMemory` mode
- no GC passive-referrer conservatism beyond index tracking
- no `MaxDataSegments` limiting behavior

Those remain broader parity gaps, but they are no longer the active `[MP]001` blocker.
