---
kind: research
status: supported
created: 2026-06-07
sources:
  - ../../binaryen/passes/memory-packing/index.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../binaryen/passes/memory-packing/binaryen-strategy.md
  - ../../binaryen/passes/memory-packing/segment-op-rewrites-and-traps.md
  - ../../binaryen/passes/memory-packing/starshine-hot-ir-strategy.md
  - ../../binary/data-element-and-datacount-sections.md
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/memory_packing_test.mbt
  - ../../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MemoryPacking.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing_traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing_zero-filled-memory.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing_zero-filled-memory64.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing_memory64-high-addr.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory-packing-gc.wast
related:
  - ./0700-2026-06-03-memory-packing-o4z-audit.md
  - ./0714-2026-06-07-o4z-behavior-parity-inventory.md
  - ../../binaryen/passes/memory-packing/parity.md
---

# Memory Packing Behavior-Parity Gap Audit

## Question

Identify the remaining behavior-parity gaps between Starshine `memory-packing` and Binaryen `MemoryPacking.cpp`.

This is a source/documentation audit, not a fresh fuzz/signoff run. The current environment has no shell command runner, so no new `moon`, `wasm-opt`, or `bun scripts/pass-fuzz-compare.ts` lane was executed here.

## Current Starshine subset that should stay credited

Current Starshine `src/passes/memory_packing.mbt` implements a useful module-pass subset:

- one-memory-only conservative legality;
- no imported-memory optimization;
- constant i32/i64 active offset parsing;
- sorted active span overlap bailout;
- active zero/nonzero range splitting with a fixed small-zero threshold;
- fast active one-kept-range/all-zero handling;
- default startup-trap top-byte retention;
- passive segment deletion when the only users are `data.drop`;
- data-index remapping for surviving passive `memory.init`, `data.drop`, `array.new_data`, and `array.init_data` users after active segment count changes;
- existing `data_count` repair when the section was already present.

The 2026-06-03 evidence remains relevant: direct `memory-packing` compare was green on all successfully compared cases, and the saved O4z active-segment artifact slot was green. That evidence does not close the broader Binaryen behavior surface.

## Remaining behavior-parity gaps

### 1. Active segment operation cleanup is missing

Binaryen runs an early `optimizeSegmentOps(...)` phase before splitting. Starshine does not have an equivalent code-rewrite phase.

Missing Binaryen families:

- active `data.drop` cleanup to `nop`;
- active `memory.init` source-range trap rewrites that still evaluate operands;
- zero-size active `memory.init` destination-bounds behavior preservation;
- refinalization/repair after those instruction rewrites.

Starshine currently only rewrites code for passive data-index remapping or `data.drop` -> `nop` when it deletes a drop-only passive segment.

### 2. Full passive segment splitting is missing

Binaryen can split passive segments when every relevant `memory.init` source offset/size is constant and no conservative blocker applies. Starshine keeps any passive segment with a non-`data.drop` user intact.

Missing Binaryen families:

- passive leading/trailing/interior zero-run profitability analysis;
- distinct passive overhead thresholds instead of the active-only fixed threshold;
- emission of split passive survivor segments;
- reuse/suffixing of segment names for split survivors.

### 3. Passive `memory.init` replacement planning is missing

Binaryen makes passive splitting behavior-preserving by replacing each original `memory.init` with a sequence over the split survivors.

Missing Binaryen families:

- `memory.init` for nonzero survivor slices;
- `memory.fill` zero-slice insertion;
- destination offset arithmetic for each slice;
- temp-local creation when a dynamic destination expression must be reused;
- memory64-address handling in the generated replacement sequence;
- zero-size `memory.init` replacement checks after splitting.

Starshine has no replacement planner because it does not split live passive segments.

### 4. Split passive `data.drop` expansion and lazy drop-state globals are missing

After splitting a passive segment, Binaryen rewrites `data.drop old` to drop every surviving split segment and, only when required, set a synthetic drop-state global. Binaryen also checks that global when a rewritten `memory.init` sequence would begin with `memory.fill`, because `memory.fill` does not trap on an already-dropped source segment.

Missing Starshine families:

- `data.drop` expansion over split passive survivors;
- lazy synthetic mutable drop-state global creation;
- explicit dropped-segment checks before fill-first or otherwise checkless replacement sequences;
- global-name conflict handling for that synthetic global.

### 5. Imported-memory `zeroFilledMemory` mode is missing

Binaryen can optimize imported memory only when its `zeroFilledMemory` option says the host-provided memory is known zero-filled. Starshine always bails out if any memory is imported.

This is conservative under Binaryen's default mode, but it is a behavior-parity gap for Binaryen lanes that pass the zero-filled-memory assumption.

### 6. `trapsNeverHappen` sensitivity is missing

Binaryen's range analysis can stop preserving some trap effects when `trapsNeverHappen` is enabled. Starshine's module pass receives no pipeline options and always preserves startup-trap top-byte writes.

This is safe but size/transform-losing versus Binaryen under TNH-enabled optimize lanes.

### 7. Segment-count limiting is missing

Binaryen stops or merges splitting when emitting every range would exceed `WebLimitations::MaxDataSegments`. Starshine has no equivalent guard.

This is a validity-oriented gap: extreme alternating active data can make Starshine produce too many data segments, while Binaryen caps or merges to stay valid.

### 8. Data name / `__llvm*` segment-name behavior is missing

Binaryen's per-segment legality checks avoid splitting data segments whose names begin with `__llvm`, and split emission preserves/reuses/suffixes segment names.

Starshine currently reconstructs the module with `name_sec=mod_.name_sec` unchanged after data segments are split or removed. Consequences:

- no `__llvm*` no-split gate;
- split segments do not get Binaryen-style data names;
- removed/reindexed data segments can leave data-name maps stale or out of range for Starshine validation.

The last point is a validity/metadata gap rather than a wasm runtime semantic gap, but it still matters for pass output validity and parity with Binaryen's named-segment behavior.

### 9. High-address / overflow edge policy is incomplete

Binaryen uses checked/saturating offset arithmetic for high-address and overflow cases, including memory64-oriented test coverage. Starshine has only focused low-address memory64 active coverage and inherits narrower arithmetic behavior:

- active i32 offset shifting uses wrapping-style unsigned addition in `mp_shift_base_offset(...)`;
- the sorted-span overflow guard is skipped for one-data-segment modules because `mp_can_optimize(...)` returns early for `datas.length() <= 1`;
- passive `memory.init` high-bit source-offset behavior is not implemented because passive replacement is not implemented.

This is the highest-risk semantic gap found by static inspection: a single high-address active segment that gets split could produce wrapped shifted offsets instead of Binaryen's trap-preserving saturated/high-address behavior.

### 10. Official GC data-user conservatism is only partly proven

Starshine now remaps `array.new_data` / `array.init_data` data indices after active segment count changes, and a passive segment with such a non-drop user is preserved because all live passive segments are preserved.

What is still missing is source-backed, explicit Binaryen-parity coverage for the official GC no-split boundary itself and its data-count/name-section side effects. This is narrower than the full passive rewrite gap: it is mostly a proof/coverage gap, not an observed transform mismatch.

## Not currently classified as gaps

- Active constant-offset zero splitting and default trap-preserving top-byte retention are implemented locally.
- Overlapping active segments correctly cause a module-level bailout.
- Drop-only passive segment cleanup and data-index remapping are implemented for the current local subset.
- The current direct compare evidence remains green on successfully compared cases, but the generators/harness did not prove the missing passive/user/option/name-limit surfaces above.

## Suggested execution order

1. Add focused red tests for the high-address single-active overflow case and data-name remap/removal validity. These are small and can expose real Starshine output-invalid or semantic-risk behavior without first porting the passive engine.
2. Add option plumbing or an explicit non-goal decision for `trapsNeverHappen` and `zeroFilledMemory`.
3. Implement active segment-op cleanup (`active data.drop`, active/zero-size `memory.init`) before full passive splitting; it is source-owned by Binaryen and independent of the large passive replacement planner.
4. Implement passive splitting and replacement as a separate module-pass sub-pipeline: referrer collection, per-segment `canSplit`, range/profitability, split emission, replacement planning, data-drop expansion, lazy drop-state globals, and name/data-count repair.
5. Add `MaxDataSegments` limiting before enabling broad splitting on generated inputs.

## Fresh signoff needed after fixes

Before closing `[O4Z-AUDIT-MP]`, rerun the final pass closeout lane from the pass skill, not just the ordinary 10k lane:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file memory_packing_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Also add targeted Binaryen lit-shape replays for `memory-packing_all-features`, `memory-packing_traps`, `memory-packing_zero-filled-memory*`, `memory-packing_memory64-high-addr`, and `memory-packing-gc` once the corresponding families are implemented.
