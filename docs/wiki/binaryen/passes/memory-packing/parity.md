---
kind: comparison
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../release-horizon-and-oracles.md
  - ./index.md
  - ../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md
  - ../ssa-nomerge/index.md
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
- Current Starshine covers the core active and passive segment-user rewrite families plus Binaryen v131 source-order overlap semantics: conservative dead passive cleanup, passive zero-range splitting, `memory.init` replacement with `memory.fill`, split-passive `data.drop` expansion, active segment-op cleanup, lowered active/split-passive `memory.init` operand side-effect preservation, data-name repair, `__llvm*` no-split handling, source-order trampling cleanup, imported all-active-segments in-bounds admission, active-only scan elision, and a fast path for common one-kept-range active segments.
- The saved generated-artifact `-O4z` slot `3` is already green, which shows the local subset is useful and exercised by that artifact.
- The 2026-05-07 saved dead-passive normalization family from `.tmp/recheck-memory-packing/` is now retired on current head.
- Focused tests now cover the released v131 overlap path in addition to imported-memory `zeroFilledMemory`, TNH trap elision, GC data-user conservatism, segment-count limiting, split-name suffixes, constant out-of-range passive source traps, and operand side-effect/trap preservation for lowered active/split-passive `memory.init` paths.

## Current in-tree status

- The explicit implementation lives in [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt).
- Focused coverage lives in [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt).

The current Starshine subset covers:

- exactly one defined memory, or one imported memory with `zero_filled_memory`
- constant i32 or i64 active offsets
- profitable active zero-range trimming
- trap-preserving top-byte retention
- source-order overlap cleanup, with imported overlap gated by an all-active-segments in-bounds proof
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

## Binaryen v131 closeout

`[V131-MP]001` is closed for the released representable surface. The implementation now:

- zeroes bytes in earlier active segments that later source-order segments trample;
- admits defined-memory overlap because partially applied initialization is unobservable outside a failed instantiation;
- admits imported-memory overlap only with `zero_filled_memory` and only when every active segment is provably in bounds of the declared minimum;
- computes bounds in pages to avoid maximal-memory64 byte-size overflow, including the exact range endpoint at `2^64`;
- preserves high memory64 startup traps rather than truncating offsets to 32 bits; and
- exposes `--zero-filled-memory` through the public CLI and repro-note forwarding path.

Focused tests pass `37/37`; command-layer tests pass `107/107`; full `moon test` passes `9439/9439`.

Explicit Binaryen v131 evidence uses `_build/native/release/build/cmd/cmd.exe` and `.tmp/binaryen-version-131-bin/bin/wasm-opt`:

- regular GenValid `.tmp/mp-v131-regular-10000`: `10000/10000` normalized, zero failures or mismatches;
- explicit wasm-smith `.tmp/mp-v131-wasm-smith-10000`: `9955` direct normalized matches, one unrelated `drop(unreachable)` output-shape residual, `44` Binaryen/tool command failures, and zero validation/property failures;
- broad random-all `.tmp/mp-v131-random-all-10000`: `10000/10000` normalized, zero failures or mismatches;
- exact defined-overlap fixture `.tmp/mp-v131-defined-overlap-compare`: canonical equality at `33` bytes, pass-local `0.017ms` Starshine versus `0.088ms` Binaryen;
- exact imported nonzero-trampler fixture `.tmp/mp-v131-imported-overlap-compare`: canonical equality at `46` bytes, pass-local `0.020ms` Starshine versus `0.102ms` Binaryen; and
- rebuilt O4z slot `.tmp/mp-v131-o4z-slot/direct`: exact canonical and normalized equality at `4,954,978` bytes, pass-local `101.821ms` Starshine versus `61.168ms` Binaryen (`1.66x`, inside the repo `2x` target), with whole-command `776.671ms` versus `520.314ms`.

The sole wasm-smith residual has no data section and differs only because Starshine retains one extra unreachable `drop`; it is agent-classified as generic representation drift outside `memory-packing`, not a pass semantic mismatch.

## Historical gap

The 2026-06-07 gap audit originally kept one main documented Binaryen gap around lowered `memory.init` operand side effects plus narrower option/validity gaps found by static inspection. The operand side-effect gap is now covered for the local rewrite surface: lowered active and split-passive constant-source/size `memory.init` rewrites evaluate and drop the original destination/source/size operands before the replacement `nop` or `unreachable`. A later closeout fixture also collapses trap-only destination debris to a single explicit trap when the destination operand is already an unconditional `unreachable` with only `drop`/`nop` debris.

The earlier option-surface conclusion was correct for the 2026-06-07 snapshot: local `wasm-opt --version` reported `version_130`, and the then-reviewed `main` source was byte-identical. It is no longer a current-main claim. Merged PR #8882 changed `MemoryPacking.cpp` on 2026-07-10 without adding a new pass option: when `zeroFilledMemory` is true and the sole memory is imported, Binaryen can handle a provably-in-allocation overlap by neutralizing earlier bytes trampled by later active segments before ordinary packing. See [`../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md).

This became a concrete released v131 parity gap and is now closed. Starshine's implementation follows the full source-order, checked bounds, fixed page-size, and memory64 proof rather than broadly permitting imported overlap. Existing v130 closeout evidence remains historical; the current signoff is the explicit-v131 closeout above.

## Current evidence

The 2026-04-22 source review did not change the upstream-teaching verdict.
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

The local focused suite now covers the main active, overlap, and passive families:

- active profitable zero-range splitting and startup-trap retention
- defined/imported source-order trampling, partial overlap, zero/nonzero tramplers, and imported out-of-bounds bailouts
- maximal and high-address memory64 bounds behavior
- drop-only passive cleanup and data-index remapping
- passive splitting, segment-op rewrites, GC boundaries, names, and segment-count validity

The 2026-06-03 audit expanded focused coverage with imported-memory bailout, empty active trapping offsets, memory64 active offset, passive `array.new_data` / `array.init_data` remapping, unordered active segment layouts, and trailing-trap preservation after a nonzero prefix.

Those tests are real, but still much smaller than the upstream lit surface.

The 2026-06-07 behavior-gap audit did not run fresh fuzz evidence, but refined the incomplete-upstream-coverage list with active segment-op cleanup, TNH/zero-filled-memory option behavior, data-name/`__llvm*` handling, high-address checked-offset behavior, and `MaxDataSegments` validity. The follow-up implementations added focused coverage for active segment-op cleanup, split-passive `memory.init`/`memory.fill`, split-passive `data.drop`, lazy drop-state globals, `__llvm*` no-split behavior, data-name repair and split-name suffixes, saturating high-address i32 active offset repair, GC data-user no-split behavior, `MaxDataSegments` guards, `trapsNeverHappen` active trap elision, zero-filled imported-memory packing, and constant out-of-range split-passive source traps. Fresh 2026-06-07 direct `memory-packing` compare evidence was mismatch-free after those changes: `.tmp/pass-fuzz-memory-packing-20260607-passive-source-10000` compared `7608/10000` with `7608` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures before the harness command-failure cap.

A later 2026-06-07 side-effect preservation slice added focused TDD for active out-of-range source traps with side-effecting destinations, zero-size active lowerings with trapping destinations, and split-passive out-of-range source traps with side-effecting destinations. The implementation now extracts the destination operand expression, emits operand evaluation plus `drop`s before active/split-passive `nop` or `unreachable` replacement, and uses a temp local for non-constant split-passive destinations that are reused by `memory.fill` / split `memory.init` replacement parts. Fresh direct compare evidence after this slice is mismatch-free: `.tmp/pass-fuzz-memory-packing-20260607-side-effects-10000` compared `7602/10000` with `7602` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures before the harness command-failure cap (`19` Binaryen empty-recursion-group, `1` Binaryen bad-section-size).

### 2026-06-07 final closeout evidence

Source/option refresh:

- Local oracle: `wasm-opt --version` -> `wasm-opt version 130 (version_130)`.
- Online source check: `version_130` and `main` were byte-identical on 2026-06-07. That is historical only: PR #8882 changed the imported-memory overlap path on 2026-07-10 and the change is included in released `version_131`. See [`../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md) and the v131 release-impact audit.

Validation and artifact replay:

- `moon info` still crashes with the known Moon panic: `index out of bounds: the len is 36 but the index is 8329485`.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file memory_packing_test.mbt` -> `30/30`.
- `moon test --package jtenner/starshine/passes --file memory_packing_wbtest.mbt` -> `1/1`.
- `moon test src/passes` -> `1965/1965`.
- `moon test` -> `5157/5157`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` unused-function warnings.
- Saved generated `-O4z` slot replay: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/02-slot02-remove-unused-module-elements/binaryen.wasm --memory-packing --out-dir .tmp/memory-packing-slot03-closeout-20260607-final --starshine-bin target/native/release/build/cmd/cmd.exe` produced canonical wasm equality and normalized WAT equality. Timings were Starshine wall `276.339 ms`, Binaryen wall `203.724 ms`, Starshine pass `40.624 ms`, Binaryen pass `23.634 ms`; the pass-local ratio remains within the repo `<= 2x Binaryen` target though not faster than Binaryen in this sample.

Final direct compare:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-final-100000-fix3 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `99751/100000` compared, `99745` normalized matches, `0` validation/property/generator failures, `249` command failures, and `6` normalized-output mismatches. Command failures were classified by the harness as `219` Binaryen empty-recursion-group, `12` Binaryen bad-section-size, `11` Binaryen command-failed, `6` Binaryen table-index-out-of-range, and `1` Binaryen invalid-tag-index. Agent classification: the six mismatches are the two narrow semantic-safe drift families listed below, not true `memory-packing` semantic mismatches.

## Practical signoff rule

The following was the v130 closeout disposition and remains historical evidence. It no longer closes the v131 audit:

- **green on the saved generated artifact** (`.tmp/memory-packing-slot03-closeout-20260607-final`, canonical wasm and normalized WAT equal)
- **green on true semantic behavior in the final 100000-case direct lane**, with six remaining normalized-output differences classified by inspection rather than treated as pass semantic failures
- **source-confirmed against Binaryen `version_130` for the reviewed historical option surface**, with `zeroFilledMemory` and `trapsNeverHappen` wired locally; released v131 imported-overlap parity remains open

The six final-lane differences are narrow:

- `case-023083`, `case-046375`, and `case-082547`: no-data/no-segment code-shape drift where Starshine output keeps unreachable `drop` debris that Binaryen canonical output omits. This is representation-only and outside `memory-packing` segment semantics.
- `case-036637`, `case-059023`, and `case-097023`: Starshine removes or remaps unreferenced passive/empty data segments more aggressively than Binaryen in modules with no remaining segment users. This is semantic-safe size-winning cleanup because no `memory.init`, `data.drop`, `array.new_data`, or `array.init_data` can observe those segments.

Keep these as reopening watchpoints only if future evidence shows observability; do not reclassify them as true behavior mismatches solely because raw normalized WAT differs.

## Sources

- [research note 0715](./index.md)
- [research note 0137](./index.md)
- [research note 0252](./index.md)
- [research note 0700](./index.md)
- [research note 0556](./index.md)
- Saved generated-artifact slot and Binaryen debug-log facts are copied into the committed O4z audit note [research note 0700](./index.md); any older `.artifacts` path is a local replay identifier, not a durable source link.
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
- Binaryen `version_130` pass source used for the 2026-06-07 gap audit: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MemoryPacking.cpp>
- Imported-overlap source refresh, now released in v131: [`../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md)
- Implementation: [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt)
- Focused tests: [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt)
