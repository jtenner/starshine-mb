---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../release-horizon-and-oracles.md
  - ./index.md
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
- constant i32/i64 active offsets, profitable active zero-run splitting, top-byte startup-trap preservation, sorted-span overlap detection, and source-order trampling cleanup;
- active `memory.init` / `data.drop` simplification with operand-effect preservation;
- passive zero-range splitting for supported constant-source `memory.init` users, `memory.fill` replacement, `data.drop` expansion, and lazy drop-state globals;
- conservative no-split handling for GC `array.new_data` / `array.init_data`, plus data-index, data-name, and `data_count` repair;
- `__llvm*` no-split handling, segment-count limiting, `trapsNeverHappen`, and active-only user-scan elision.

The important v131 boundary is Binaryen's released imported-memory overlap exception. Starshine now matches it: defined-memory overlaps are neutralized in source order, while imported-memory overlaps require `zero_filled_memory` and a proof that every active segment fits within the declared minimum. The proof compares page counts instead of overflowing maximal memory64 byte sizes and admits only the exact `2^64` endpoint special case. See [`../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-memory-packing-imported-overlap-current-main-refresh.md).

## Why this remains a module pass

The historical filename says `starshine-hot-ir-strategy`, but this pass is deliberately module-scoped. A correct rewrite needs the complete memory/import shape, every data segment and its source order, all segment users, index/name/data-count repair, and output validity limits. The module driver is [`memory_packing_run_module_pass(...)`](../../../../../src/passes/memory_packing.mbt); [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches the public spelling.

## Code map

| Concern | Current owner | What it proves |
| --- | --- | --- |
| Public summary and rewrite entry point | [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) | `memory_packing_summary()` promises active-and-passive packing; `memory_packing_run_module_pass(...)` owns the module rebuild. |
| Imported/defined memory shape and bounds | `mp_imported_mem_count`, `mp_defined_mem_count`, `mp_sole_memory_type`, `mp_provably_in_bounds` | A single imported memory is eligible only with `zero_filled_memory`; overflow-safe page-count proofs feed overlap admission and active trap preservation. |
| Active offsets and ranges | `mp_parse_base_offset`, `mp_active_rewrite*`, `mp_collect_ranges`, `mp_merge_small_zero_ranges` | Exact i32/i64 constants only; range splitting uses the local fixed threshold and preserves shifted offsets. |
| Startup trap preservation | `mp_should_preserve_trap`, `mp_preserve_trapping_top_byte` | A dropped zero tail cannot erase an observable active-segment out-of-bounds trap. |
| Whole-module active legality | `mp_can_optimize`, `mp_active_spans_are_disjoint`, `mp_zero_out_trampled_data` | Memory index must be zero and offsets exact; overlap is detected with overflow-aware spans, then earlier bytes are zeroed in source order. Imported overlap additionally requires every active segment to be in bounds. |
| Segment users and passive planning | `mp_collect_data_usages`, passive split/replacement helpers | Supported passive `memory.init` / `data.drop` paths are rewritten; GC data users remain conservative no-split boundaries. |
| Output repair | segment-plan/remap/name/data-count helpers | Rebuilt data segments preserve surviving data-index users, names, and `data_count` semantics. |
| Registry and presets | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | `memory-packing` is an active module pass in the early `optimize` and `shrink` module prefix. |
| Focused behavior | [`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt) | Locks positive active/imported/passive paths, traps, remapping, and conservative boundaries. |

## Current legality model

For a beginner, read the local gate in this order:

1. **One memory only.** A defined or imported memory is allowed, but more than one is not.
2. **Imported memory needs an explicit host contract.** If the memory is imported, `zero_filled_memory` must be true before Starshine can omit zero writes.
3. **Each active segment needs memory index 0 and a literal offset.** The local pass recognizes exact `i32.const` / `i64.const`, not a symbolic expression.
4. **Overlaps are interpreted in segment source order.** Later active segments trample earlier bytes, so Starshine zeroes those earlier bytes before ordinary zero-range packing.
5. **Imported overlap needs a no-trap proof.** With imported memory, every active segment must fit in the declared minimum so failed instantiation cannot expose a partially applied prefix.
6. **A rewritten active segment must retain an observable startup trap.** If the original final write can exceed the declared initial memory, the local pass retains the top byte unless `trapsNeverHappen` is set.

## Concrete local shapes

### Imported memory: option-gated positive

```wat
(import "env" "memory" (memory 1))
(data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC")
```

- With default options, Starshine preserves the segment because the host's imported memory is not known zero-filled.
- With `HotPipelineOptions::new(zero_filled_memory=true)`, it can keep `ABC` at offset `9`.
- The focused test is [`memory-packing packs imported memory when zero-filled memory is known`](../../../../../src/passes/memory_packing_test.mbt).

### Active overlap: source-order trampling

```wat
(memory 1)
(data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC")
(data (i32.const 5) "ZZ")
```

Starshine zeroes the first segment's bytes that are overwritten by the later segment, then packs the resulting zero ranges. For imported memory, the same rewrite is admitted only with `zero_filled_memory` and a complete in-bounds proof. Focused tests cover defined/imported overlaps, zero and nonzero tramplers, partial trampling, unrelated and trampler out-of-bounds bailouts, maximal memory64, and high memory64 startup traps.

## Validation and signoff guidance

- Use the focused test file first when changing a local behavior boundary: `src/passes/memory_packing_test.mbt`.
- For a real pass change, add a red-first case to the implementing file and `src/cmd/cmd.mbt` / active dispatcher surface as required by [`AGENTS.md`](../../../../../AGENTS.md).
- Then run the project validation ladder and direct `compare-pass` signoff with a freshly built native binary; see [`./parity.md`](parity.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).
- Do not call a normalized mismatch safe merely because the output validates. For imported-overlap work, inspect source-order effects, in-bounds proof, and memory32/memory64 overflow behavior explicitly.

## Current gaps versus Binaryen

The local pass has substantial passive support, but these boundaries remain material:

- **Broader symbolic layouts:** dynamic active offsets and multimemory remain unsupported.
- **Finer imported-overlap admission:** like Binaryen v131, Starshine uses the conservative all-active-segments in-bounds rule rather than proving only the source-order interval between a trampled byte and its trampler.
- **Any unmodeled upstream surface:** use the upstream strategy and parity page before assuming the local module driver is a faithful source port.

## Read next

1. [`binaryen-strategy.md`](binaryen-strategy.md) for the upstream phase model and released v131 overlap behavior.
2. [`wat-shapes.md`](wat-shapes.md) for positive and negative module examples.
3. [`parity.md`](parity.md) for current evidence and the explicit parity-gap classification.
4. [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) and [`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt) for the executable contract.
