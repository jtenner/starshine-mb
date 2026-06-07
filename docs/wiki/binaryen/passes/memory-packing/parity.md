---
kind: comparison
status: working
last_reviewed: 2026-06-07
sources:
  - ../../../raw/research/0715-2026-06-07-memory-packing-parity-gap-audit.md
  - ../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md
  - ../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/research/0556-2026-05-07-memory-packing-passive-cleanup-parity.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
---

# `memory-packing` Binaryen parity

## Durable conclusions

- Binaryen `version_129` `memory-packing` is a module-level segment-plus-segment-op rewrite pass, not just an active-segment splitter.
- Current Starshine still does not model every Binaryen option and validity guard, but it now covers the core active and passive segment-user rewrite families: conservative dead passive cleanup, passive zero-range splitting, `memory.init` replacement with `memory.fill`, split-passive `data.drop` expansion, active segment-op cleanup, lowered active/split-passive `memory.init` operand side-effect preservation, data-name repair, `__llvm*` no-split handling, sorted active-overlap checking, active-only scan elision, and a fast path for common one-kept-range active segments.
- The saved generated-artifact `-O4z` slot `3` is already green, which shows the local subset is useful and exercised by that artifact.
- The 2026-05-07 saved dead-passive normalization family from `.tmp/recheck-memory-packing/` is now retired on current head.
- That saved green slot is **not** proof that Starshine already covers every option-surface corner; focused tests now cover imported-memory `zeroFilledMemory`, TNH trap elision, GC data-user conservatism, segment-count limiting, split-name suffixes, constant out-of-range passive source traps, and operand side-effect/trap preservation for lowered active/split-passive `memory.init` paths.

## Current in-tree status

- The explicit implementation lives in [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt).
- Focused coverage lives in [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt).

The current Starshine subset covers:

- one defined memory only
- constant i32 or i64 active offsets
- profitable active zero-range trimming
- trap-preserving top-byte retention
- overlap bailout
- conservative removal of passive segments with no non-`data.drop` referrers
- passive data-index remapping after active or passive segment count changes
- passive segment splitting around profitable zero ranges for constant-source `memory.init` users
- replacement of split-passive zero slices with `memory.fill`
- temporary i32 locals for dynamic split-passive `memory.init` destinations
- split-passive `data.drop` expansion plus lazy drop-state globals for fill-first replacements
- active `data.drop` cleanup to `nop`
- active `memory.init` cleanup to `nop` or explicit `unreachable` when its constant source range is known in or out of bounds, preserving evaluated operands with drops before the replacement
- `data.drop` -> `nop` cleanup for removed passive segments
- data-count section updates after changed segment counts
- data-name repair after segment deletion/remapping
- Binaryen-style suffixed data names for split segments
- `__llvm*` data-name no-split handling
- conservative no-split behavior for passive segments with GC `array.new_data` / `array.init_data` users
- segment-count limiting to avoid exceeding `MaxDataSegments`
- `trapsNeverHappen` active trap-elision plumbing through the hot pipeline
- imported-memory packing when the hot pipeline marks memory as known zero-filled
- saturating high-address i32 active offset repair instead of wrapping into low memory
- active-only data modules avoid code-section data-usage scans
- many active segment legality checks use sorted spans instead of pairwise overlap scans
- common leading/trailing-zero active segments use a fast single-kept-range path while preserving traps
- lowered active and split-passive `memory.init` paths preserve destination/source/size evaluation before `nop` / `unreachable` replacement when the pass rewrites constant-source/size users

## Remaining gap

The 2026-06-07 gap audit originally kept one main documented Binaryen gap around lowered `memory.init` operand side effects plus narrower option/validity gaps found by static inspection. The operand side-effect gap is now covered for the local rewrite surface: lowered active and split-passive constant-source/size `memory.init` rewrites evaluate and drop the original destination/source/size operands before the replacement `nop` or `unreachable`.

The remaining documented gap is:

- no full option plumbing for Binaryen's entire pass option surface beyond the current `trapsNeverHappen` and `zeroFilledMemory` paths

So the honest parity rule is:

- current Starshine has **artifact-local parity on the exercised active subset** and focused coverage for the newly implemented active/passive segment-user families
- but not yet full official-surface parity with Binaryen `MemoryPacking.cpp` options beyond the current wired subset

## Current evidence

The 2026-04-22 raw primary-source capture did not change the upstream-teaching verdict.
The 2026-05-07 current-head follow-up sharpened the direct-status note: the narrow saved dead-passive normalization blocker from `[MP]001` was closed, and direct compare evidence was semantically green on all successfully compared cases.

The 2026-06-03 `[O4Z-AUDIT-MP]` refresh keeps that status and adds current direct evidence after pass-local performance work:

- `memory-packing` is still best described as artifact-green plus incomplete upstream coverage
- post-change `--count 1000 --seed 0x5eed` direct compare: `998 / 1000` compared, `998` normalized matches, `0` mismatches, `2` Binaryen/tool command failures
- post-change `--count 10000 --seed 0x5eed` direct compare without command-failure keep-going: `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, `20` Binaryen/tool command failures before the harness command-failure cap
- post-change `--count 10000 --seed 0x5eed --keep-going-after-command-failures` direct compare: `9975 / 10000` compared, `9975` normalized matches, `0` mismatches, `25` Binaryen/tool command failures
- agent classification: the observed failures were tool/Binaryen command failures, not semantic mismatches

The earlier source capture still made one freshness point explicit:

- the reviewed official Binaryen `version_129` release page still showed publish date **2026-04-01** on 2026-04-22
- the narrow `main` spot check did not surface a teaching-relevant drift from the released `memory-packing` contract on the reviewed source surfaces

## Saved generated-artifact audit

The saved `-O4z` audit reports slot `3` (`memory-packing`) as:

- canonical wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine runtime: `650.310 ms`
- Binaryen runtime: `225.872 ms`
- Starshine pass time: `12.684 ms`
- Binaryen pass time: `31.292 ms`

That is encouraging in two different ways:

- the local implementation already matches the artifact's exercised semantics
- the pass itself is not the local runtime bottleneck on that artifact; the wall-time gap is larger than the in-pass gap

The 2026-06-03 synthetic pass-local audit then targeted `memory-packing`'s own scalability cliffs:

| Fixture | Before Starshine median | After Starshine median | Binaryen median |
| --- | ---: | ---: | ---: |
| active-only large-code module | `511 us` | `12 us` | `4223.3 us` |
| many active segments | `4421 us` | `825 us` | `975.6 us` |

The pass-local conclusion is that the current implementation is now comfortably faster than Binaryen on the active-only code-scan stress and slightly faster than Binaryen on the many-active-segment stress, while keeping the same semantic subset.

## Saved Binaryen debug log

The saved Binaryen debug log shows one top-level `running pass: memory-packing` line.
That matches the documented scheduler story:

- this is a module pre-pass
- not a nested hot-rerun pass

## In-tree focused tests

The local focused suite currently covers five families:

- active profitable zero-range splitting
- active trap-preserving top-byte retention
- overlap bailout
- drop-only passive segment cleanup
- passive data-index remapping after active splitting

The 2026-06-03 audit expanded focused coverage with imported-memory bailout, empty active trapping offsets, memory64 active offset, passive `array.new_data` / `array.init_data` remapping, unordered active segment layouts, and trailing-trap preservation after a nonzero prefix.

Those tests are real, but still much smaller than the upstream lit surface.

The 2026-06-07 behavior-gap audit did not run fresh fuzz evidence, but refined the incomplete-upstream-coverage list with active segment-op cleanup, TNH/zero-filled-memory option behavior, data-name/`__llvm*` handling, high-address checked-offset behavior, and `MaxDataSegments` validity. The follow-up implementations added focused coverage for active segment-op cleanup, split-passive `memory.init`/`memory.fill`, split-passive `data.drop`, lazy drop-state globals, `__llvm*` no-split behavior, data-name repair and split-name suffixes, saturating high-address i32 active offset repair, GC data-user no-split behavior, `MaxDataSegments` guards, `trapsNeverHappen` active trap elision, zero-filled imported-memory packing, and constant out-of-range split-passive source traps. Fresh 2026-06-07 direct `memory-packing` compare evidence was mismatch-free after those changes: `.tmp/pass-fuzz-memory-packing-20260607-passive-source-10000` compared `7608/10000` with `7608` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures before the harness command-failure cap.

A later 2026-06-07 side-effect preservation slice added focused TDD for active out-of-range source traps with side-effecting destinations, zero-size active lowerings with trapping destinations, and split-passive out-of-range source traps with side-effecting destinations. The implementation now extracts the destination operand expression, emits operand evaluation plus `drop`s before active/split-passive `nop` or `unreachable` replacement, and uses a temp local for non-constant split-passive destinations that are reused by `memory.fill` / split `memory.init` replacement parts. Fresh direct compare evidence after this slice is mismatch-free: `.tmp/pass-fuzz-memory-packing-20260607-side-effects-10000` compared `7602/10000` with `7602` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures before the harness command-failure cap (`19` Binaryen empty-recursion-group, `1` Binaryen bad-section-size).

## Practical signoff rule

For now, treat `memory-packing` as:

- **green on the saved generated artifact**
- **green again on the direct saved-repro family and current direct compare lane, modulo known Binaryen/tool command-failure noise**
- **wider than the former active-only subset, but still not a full port of Binaryen `MemoryPacking.cpp`**

That is the honest status this dossier should preserve.

## Sources

- [`../../../raw/research/0715-2026-06-07-memory-packing-parity-gap-audit.md`](../../../raw/research/0715-2026-06-07-memory-packing-parity-gap-audit.md)
- [`../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md`](../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md)
- [`../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md`](../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md)
- [`../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md`](../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md`](../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md)
- [`../../../raw/research/0556-2026-05-07-memory-packing-passive-cleanup-parity.md`](../../../raw/research/0556-2026-05-07-memory-packing-passive-cleanup-parity.md)
- Saved generated-artifact slot and Binaryen debug-log facts are copied into the committed O4z audit note [`../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md`](../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md); any older `.artifacts` path is a local replay identifier, not a durable source link.
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
- Binaryen `version_130` pass source used for the 2026-06-07 gap audit: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MemoryPacking.cpp>
- Implementation: [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt)
- Focused tests: [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt)
