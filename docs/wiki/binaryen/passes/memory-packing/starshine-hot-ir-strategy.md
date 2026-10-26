---
kind: concept
status: supported
last_reviewed: 2026-10-15
sources:
  - ../../release-horizon-and-oracles.md
  - ./index.md
  - index.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/memory_packing_nested_operands_regression_wbtest.mbt
  - ../../../../../src/passes/memory_packing_rebuild_wbtest.mbt
  - ../../../../../src/passes/memory_packing_encoded_cost_regression_wbtest.mbt
  - ../../../../../src/cmd/memory_packing_rebuild_wbtest.mbt
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

> **Comparison baseline:** New comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Earlier sources, commands, artifacts, and results retain their historical versions and do not establish v133 signoff.

This page is the current in-tree code map. It is intentionally separate from the upstream algorithm in [`binaryen-strategy.md`](binaryen-strategy.md): Starshine is a module-pass implementation with useful active and passive slices, but it is not a literal port of Binaryen `MemoryPacking.cpp`.

## October 15 packing after the Directize finish

The full-preset Directize finish checks for profitable passive packing after
InliningOptimizing, RemoveUnusedModuleElements and Vacuum. This placement
permits removal of the last dynamic copy-helper user before packing. A
red-first immutable-table/indirect-call fixture keeps 130 passive bytes with
early packing; the late finish reduces this to two bytes. Explicit short
presets retain their existing scheduling. See [preset owner](../../../../../src/passes/optimize.mbt)
and [late-packing regression](../../../../../src/passes/late_memory_packing_regression_test.mbt).

## October 15 memory64 trap-before-write review

The frozen 10,000-case lane has 1,330 dynamic memory64 structural differences.
Its retained modules do not export or call their functions, so successful
instantiation alone does not exercise the rewritten bodies. Review-only copies
added exports after optimization without changing any other section. Original
and Starshine behavior matched source-based expected results in every call.

Nine retained boundary cases expose a correctness benefit over the Binaryen 133
shape. A one-page memory receives a passive copy whose full destination ends at
byte 65,537. WebAssembly checks the full `memory.init` source and destination
ranges before the first write. Original and Starshine trap with memory
unchanged. Binaryen's split copy writes the leading nonzero byte, fills the zero
range, and then traps on the final byte. Six of those safe Starshine outputs are
larger, so this is a measured correctness and size tradeoff, not a general size
win.

The bounded regression `memory-packing memory64 split traps before its first
destination write` uses a profitable 130-byte split. Its evaluator aborts on
any memory write; the out-of-bounds destination must reach the explicit full
range trap first. This locks the existing destination preflight order without
requiring Starshine to preserve an unprofitable unsplit form. The export-only
replay covers retained families only and does not turn the campaign's 1,284
blocked active-start traps into successful semantic observations.

## Short version

Starshine currently supports:

- exactly one memory, including one **imported** memory when `HotPipelineOptions.zero_filled_memory` is true;
- constant i32/i64 active offsets, profitable active zero-run splitting, top-byte startup-trap preservation, sorted-span overlap detection, and source-order trampling cleanup;
- active `memory.init` / `data.drop` simplification with operand-effect preservation;
- passive zero-range splitting for supported constant-source `memory.init` users, `memory.fill` replacement, `data.drop` expansion, and lazy drop-state globals;
- conservative no-split handling for GC `array.new_data` / `array.init_data`, plus data-index, data-name, and `data_count` repair;
- `__llvm*` no-split handling, segment-count limiting, `trapsNeverHappen`, and active-only user-scan elision.

The important v131 boundary is Binaryen's released imported-memory overlap exception. Starshine now matches it: defined-memory overlaps are neutralized in source order, while imported-memory overlaps require `zero_filled_memory` and a proof that every active segment fits within the declared minimum. The proof compares page counts instead of overflowing maximal memory64 byte sizes and admits only the exact `2^64` endpoint special case. See [`index.md`](index.md).

The September 22 input-ownership repair copies the data-segment array before
source-order overlap cleanup. The pass can zero entries in that copy without
changing the caller's original module; the adjacent regression calls the pass
and checks the original segment bytes afterward.

The October 7 code-rebuild repair records data-operation use for each function
during the existing preflight. A function without data operations keeps its
original body and is excluded from changed-body comparisons. A focused module
with one `data.drop` function and 128 unaffected functions now rebuilds one
body instead of 129. The 48 owner tests and dispatcher regression pass.
On a 1,025-function fixture, the saved pre-fix native CLI took 135 µs median
pass-local time across ten warm samples; the rebuilt CLI took 44.5 µs, with
identical raw output SHA-256
`667ab7577168b0b02d0f22f3c784ae59f0494d00b39312cae992406a9866d335`.
The post-fix verified-v133 sweep measured 0.049 ms Starshine pass time versus
0.258 ms Binaryen. The verified-v133 10,000-case aggregate retained the
previous 7,288 exact / 2,712 residual counts and zero validation, property,
generator, or command failures. Its residuals remain the documented active
zero-length and dynamic Memory64 families; this repair does not alter them.

## Why this remains a module pass

The October 14 size guard treats active and passive range thresholds as
candidate admission. A changed candidate must reduce the complete encoded
module, including retained data names, rewritten code, and section framing.
If code or globals invalidate compiler facts, the comparison excludes those
facts from both sides. Removing stale facts cannot pay for data growth.
Equal-size candidates and encoding failures retain the original module;
unchanged paths do not run the size comparison. Focused
[`encoded-cost regressions`](../../../../../src/passes/memory_packing_encoded_cost_regression_wbtest.mbt)
cover named active and passive losses, profitable controls, and fact removal.
This guard does not establish new Binaryen-v133 fuzz or performance signoff.

Positive tests now fund dynamic destination guards, temporary locals, and split
names with 128 zero bytes while still requiring those rewrites and strict
complete-byte savings. The small trailing startup-trap boundary retains its
original segment: a verified-v133 replay measured 26 original bytes, 32 for the
old Starshine split, and 35 for the oracle split. Identity retains the same
instantiation trap. The enlarged positive still requires the split and its
out-of-bounds final byte. Named passive comparison retains names on both sides;
the old reduced case tied at 100 bytes, while the enlarged case fell from 199
to 102 bytes in both Starshine and the oracle with names retained.

Proven source traps also omit consumed constant source/length operands and a
constant destination. Dynamic destination evaluation stays in order, including
its side effects and traps. Three independently encoded valid candidate bodies
reduced the old trap outputs by nine, six, and nine bytes respectively. Final
native build and test validation remain separate from these candidate checks.

The historical filename says `starshine-hot-ir-strategy`, but this pass is deliberately module-scoped. A correct rewrite needs the complete memory/import shape, every data segment and its source order, all segment users, index/name/data-count repair, and output validity limits. The module driver is [`memory_packing_run_module_pass(...)`](../../../../../src/passes/memory_packing.mbt); [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches the public spelling.

## Code map

| Concern | Current owner | What it proves |
| --- | --- | --- |
| Public summary and rewrite entry point | [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) | `memory_packing_summary()` promises active-and-passive packing; `memory_packing_run_module_pass(...)` owns the module rebuild. |
| Imported/defined memory shape and bounds | `mp_imported_mem_count`, `mp_defined_mem_count`, `mp_sole_memory_type`, `mp_provably_in_bounds` | A single imported memory is eligible only with `zero_filled_memory`; overflow-safe page-count proofs feed overlap admission and active trap preservation. |
| Active offsets and ranges | `mp_parse_base_offset`, `mp_active_rewrite*`, `mp_collect_ranges`, `mp_merge_small_zero_ranges` | Exact i32/i64 constants only; range splitting uses the local fixed threshold and preserves shifted offsets. |
| Startup trap preservation | `mp_should_preserve_trap`, `mp_preserve_trapping_top_byte` | A dropped zero tail cannot erase an observable active-segment out-of-bounds trap. |
| Whole-module active legality | `mp_can_optimize`, `mp_active_spans_are_disjoint`, `mp_zero_out_trampled_data` | Memory index must be zero and offsets exact; overlap is detected with overflow-aware spans, then earlier bytes are zeroed in source order in a copied data array. Imported overlap additionally requires every active segment to be in bounds. |
| Segment users and passive planning | `mp_collect_data_usages`, `mp_passive_user_scan`, passive split/replacement helpers | Supported passive `memory.init` / `data.drop` paths are rewritten; referrer counts reproduce Binaryen's `2 + 19 * memory.init + 3 * data.drop` interior threshold and `9 * memory.init` edge threshold; GC data users remain conservative no-split boundaries. |
| Safe and cheap code traversal | `mp_module_segment_op_preflight` | One recursive preflight proves every flattened `memory.init` operand boundary before mutation and records data-index use per function; the rewrite keeps unaffected function bodies. |
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
7. **Passive zeroes must pay for their replacement operations.** Interior runs use Binaryen's segment-metadata plus referrer-operation estimate; leading and trailing runs use the cheaper edge estimate. A legal split that would grow the module stays unchanged.
8. **User rewrites are preflighted before segment mutation.** If a flattened `memory.init` destination cannot be reconstructed exactly, the entire pass returns unchanged. Decoded legacy `try` bodies and every typed or catch-all handler participate in the same scan.

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


## October 16 report task 39: duplicate passive-data sharing experiment

**Decision: accept the restricted no-drop hypothesis; defer production
integration. Reject blind index substitution across independent drop states.**
The [bounded experiment](../../../../../src/passes/passive_data_sharing_experiment_wbtest.mbt)
is test-only. It admits exactly two equal passive payloads with flat,
explicitly supported read-only users, and excludes metadata, module expression
users, imports, structured control and unknown instructions. It rewrites data
index 1 to 0, removes the duplicate record and updates `data_count`. No
production pass, dispatcher or preset changed.

Without any `data.drop`, both segments retain the same immutable byte length
and contents for the whole instance lifetime. Their `memory.init` source
bounds and copied bytes therefore agree for every source offset and length;
keeping destination operands and memory indices also keeps destination bounds
and trap-before-write behavior. The candidate adds **zero globals, locals or
instructions**. Exact encoded module sizes, also reproduced by wasm-tools
1.260.0, are:

| Equal payload bytes per original segment | Original | Shared candidate | Saved |
| --- | ---: | ---: | ---: |
| 0 | 94 B | 92 B | 2 B |
| 1 | 96 B | 93 B | 3 B |
| 64 | 223 B | 156 B | 67 B |
| 128 | 353 B | 222 B | 131 B |

The 64-byte case saves one additional data-section framing byte. The retained
negative example also shrinks, 256 to 189 bytes, but is incorrect: after dropping
segment 0, an initialization from the still-live segment 1 succeeds in the
original and traps after blind sharing. The reverse direction also differs.
This includes a zero-length initialization with source offset 1: a dropped
segment has length zero, so an empty copy can still expose the wrong lifetime.
Typing and smaller output do not establish equivalence.

Node v26.11.1 compares **96** original/candidate observations across four
payload lengths, both users, normal and zero-length copies, source and
destination endpoints, unsigned high bits and trap-before-write cases. All
agree. Eight independent-drop observations expose **four** differences from
the deliberately wrong shared candidate. Starshine validates all constructed
modules; wasm-tools independently validates all ten exported original/candidate
binaries, including the well-typed but incorrect drop candidate. A direct-IR
`array.new_data` control locks the experiment's intentional GC-user exclusion;
it does not claim that every no-drop GC sharing case is unsafe.

The positive test fails with the initial absent candidate. After implementing
the fixture-scoped builder, all four focused tests pass with `--include-skipped`
(the fourth test exports the runtime fixtures). Default tests do not write those
files. An initial GC text fixture hit a parser boundary and was replaced with
direct IR. The experiment does not establish artifact frequency, compiler
runtime, peak memory, arbitrary nested/GC user coverage, metadata remapping or
full pass parity. A general drop-aware design must preserve separate logical
lifetimes and measure the added state and guards before a production decision.
No such production design or cost claim is made here.

Commands, from the repository root:

```sh
flock /tmp/starshine-moon.lock moon test --package jtenner/starshine/passes --file passive_data_sharing_experiment_wbtest.mbt --include-skipped
/home/dev/.local/share/mise/installs/node/26.11.1/bin/node .tmp/report-optimization-20261016/passive-data-sharing/runtime.mjs
```

Local evidence: `.tmp/report-optimization-20261016/passive-data-sharing/`,
including `red-ready.log`, `red-final.log`, `green-export.log`,
`runtime-results.json`, `encoded-artifacts.json`, and
`independent-encoder-sizes.json`. This experiment is not a new Binaryen parity
signoff; historical comparison versions above retain their original scope.
