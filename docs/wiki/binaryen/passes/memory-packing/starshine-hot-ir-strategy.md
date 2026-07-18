---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md
  - ../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./parity.md
  - ../remove-unused-module-elements/index.md
  - ../once-reduction/index.md
---

# Starshine `memory-packing` strategy today

This page is the current in-tree code map. It is intentionally separate from the upstream algorithm in [`binaryen-strategy.md`](binaryen-strategy.md): Starshine is a module-pass implementation with useful active and passive slices, but it is not a literal port of Binaryen `MemoryPacking.cpp`.

## Short version

Starshine currently supports:

- exactly one memory, including one **imported** memory when `HotPipelineOptions.zero_filled_memory` is true;
- constant i32/i64 active offsets, profitable active zero-run splitting, top-byte startup-trap preservation, and sorted-span overlap rejection;
- active `memory.init` / `data.drop` simplification with operand-effect preservation;
- passive zero-range splitting for supported constant-source `memory.init` users, `memory.fill` replacement, `data.drop` expansion, and lazy drop-state globals;
- conservative no-split handling for GC `array.new_data` / `array.init_data`, plus data-index, data-name, and `data_count` repair;
- `__llvm*` no-split handling, segment-count limiting, `trapsNeverHappen`, and active-only user-scan elision.

The important v131 boundary is Binaryen's released imported-memory overlap exception. Starshine still rejects **all** active overlaps, even when imported memory is known zero-filled and the ranges are in allocation. That is a parity gap, not a safety justification for broadening local behavior without the upstream source-order and bounds proof. See [`../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md).

## Why this remains a module pass

The historical filename says `starshine-hot-ir-strategy`, but this pass is deliberately module-scoped. A correct rewrite needs the complete memory/import shape, every data segment and its source order, all segment users, index/name/data-count repair, and output validity limits. The module driver is [`memory_packing_run_module_pass(...)`](../../../../../src/passes/memory_packing.mbt); [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches the public spelling.

## Code map

| Concern | Current owner | What it proves |
| --- | --- | --- |
| Public summary and rewrite entry point | [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) | `memory_packing_summary()` promises active-and-passive packing; `memory_packing_run_module_pass(...)` owns the module rebuild. |
| Imported/defined memory shape and initial-byte size | `mp_imported_mem_count`, `mp_defined_mem_count`, `mp_memory_size_bytes` | A single imported memory is eligible only with `zero_filled_memory`; initial limits feed active trap preservation. |
| Active offsets and ranges | `mp_parse_base_offset`, `mp_active_rewrite*`, `mp_collect_ranges`, `mp_merge_small_zero_ranges` | Exact i32/i64 constants only; range splitting uses the local fixed threshold and preserves shifted offsets. |
| Startup trap preservation | `mp_should_preserve_trap`, `mp_preserve_trapping_top_byte` | A dropped zero tail cannot erase an observable active-segment out-of-bounds trap. |
| Whole-module active legality | `mp_can_optimize`, `mp_active_spans_are_disjoint` | Memory index must be zero, offsets must be exact, arithmetic must not wrap, and all active spans must be disjoint. |
| Segment users and passive planning | `mp_collect_data_usages`, passive split/replacement helpers | Supported passive `memory.init` / `data.drop` paths are rewritten; GC data users remain conservative no-split boundaries. |
| Output repair | segment-plan/remap/name/data-count helpers | Rebuilt data segments preserve surviving data-index users, names, and `data_count` semantics. |
| Registry and presets | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | `memory-packing` is an active module pass in the early `optimize` and `shrink` module prefix. |
| Focused behavior | [`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt) | Locks positive active/imported/passive paths, traps, remapping, and conservative boundaries. |

## Current legality model

For a beginner, read the local gate in this order:

1. **One memory only.** A defined or imported memory is allowed, but more than one is not.
2. **Imported memory needs an explicit host contract.** If the memory is imported, `zero_filled_memory` must be true before Starshine can omit zero writes.
3. **Each active segment needs memory index 0 and a literal offset.** The local pass recognizes exact `i32.const` / `i64.const`, not a symbolic expression.
4. **Multiple active spans must be disjoint.** The local sorted-span test rejects any overlap before range packing.
5. **A rewritten active segment must retain an observable startup trap.** If the original final write can exceed the declared initial memory, the local pass retains the top byte unless `trapsNeverHappen` is set.

The fourth rule is deliberately stricter than Binaryen v131. Upstream's narrow released exception is not merely an alternate span predicate: it neutralizes earlier bytes trampled by later segments and proves that the imported segment fits within its declared allocation. Starshine does neither today.

## Concrete local shapes

### Imported memory: option-gated positive

```wat
(import "env" "memory" (memory 1))
(data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC")
```

- With default options, Starshine preserves the segment because the host's imported memory is not known zero-filled.
- With `HotPipelineOptions::new(zero_filled_memory=true)`, it can keep `ABC` at offset `9`.
- The focused test is [`memory-packing packs imported memory when zero-filled memory is known`](../../../../../src/passes/memory_packing_test.mbt).

### Active overlap: intentional current local bailout

```wat
(memory 1)
(data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC")
(data (i32.const 5) "ZZ")
```

Starshine leaves this module unchanged. Even an apparently removable zero range can be semantically affected by the later write. The focused [`memory-packing bails out when active segments overlap`](../../../../../src/passes/memory_packing_test.mbt) test locks that current safe subset.

## Validation and signoff guidance

- Use the focused test file first when changing a local behavior boundary: `src/passes/memory_packing_test.mbt`.
- For a real pass change, add a red-first case to the implementing file and `src/cmd/cmd.mbt` / active dispatcher surface as required by [`AGENTS.md`](../../../../../AGENTS.md).
- Then run the project validation ladder and direct `compare-pass` signoff with a freshly built native binary; see [`./parity.md`](parity.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).
- Do not call a normalized mismatch safe merely because the output validates. For imported-overlap work, inspect source-order effects, in-bounds proof, and memory32/memory64 overflow behavior explicitly.

## Current gaps versus Binaryen

The local pass has substantial passive support, but these boundaries remain material:

- **Released v131 imported overlap:** no `zeroOutTrampledData(...)` equivalent; no source-order-aware overlap handling; all overlaps bail out.
- **Imported in-allocation proof:** local imported-memory option support does not implement Binaryen v131's overlap-specific checked page/byte proof.
- **Broader symbolic layouts:** dynamic active offsets and multimemory remain unsupported.
- **Any unmodeled upstream surface:** use the upstream strategy and parity page before assuming the local module driver is a faithful source port.

## Read next

1. [`binaryen-strategy.md`](binaryen-strategy.md) for the upstream phase model and released v131 overlap behavior.
2. [`wat-shapes.md`](wat-shapes.md) for positive and negative module examples.
3. [`parity.md`](parity.md) for current evidence and the explicit parity-gap classification.
4. [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) and [`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt) for the executable contract.
