---
kind: concept
status: supported
last_reviewed: 2026-09-10
sources:
  - ../binaryen/release-horizon-and-oracles.md
  - ../binaryen/passes/safe-heap/index.md
  - ../wasm-linear-memory-threads-boundary.md
  - ../wasm-relaxed-atomics-boundary.md
  - https://github.com/WebAssembly/proposals
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests_wbtest.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/typecheck_negative_wbtest.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/ir/hot_lift.mbt
  - ../../../src/ir/hot_lower.mbt
  - ../../../src/ir/effects.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
related:
  - ./memory-instruction-authoring.md
  - ./memory-argument-authoring.md
  - ./gc-aggregate-instruction-authoring.md
  - ./resource-declaration-authoring.md
  - ../validate/resource-sections-and-limits.md
  - ../wasm-linear-memory-threads-boundary.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/module-validation-phases.md
  - ../wasm-relaxed-atomics-boundary.md
  - ../binaryen/passes/safe-heap/index.md
---


# Atomic Memory Instruction Authoring

Starshine targets Binaryen 132 for new comparisons. Linear-memory atomic
instructions now have WAST parsing, printing and lowering as well as core,
binary, validation and HOT support. This September 10 implementation supersedes
this page's previous “core yes, WAST text no” boundary. The
[upgrade record](../binaryen/version-132-upgrade.md) owns current signoff;
structural checks do not imply external-engine support for experimental orders.

## Text and binary contract

The text parser accepts all 66 linear-memory load/store/RMW/cmpxchg/notify/wait
operators and `atomic.fence`. Load/store/RMW/cmpxchg accept an optional memory
index or identifier before an optional order, followed by `offset=` and `align=`.
Alignment is in bytes in text and a base-two exponent in the core `MemArg`.
Memory64 changes the address width, not the access's natural alignment.

```wat
(module
  (memory $mem i64 1 2 shared)
  (func (result i64)
    (i64.atomic.store32 $mem relaxed offset=4 align=4
      (i64.const 0) (i64.const 7))
    (i64.atomic.load32_u $mem relaxed offset=4 align=4
      (i64.const 0))))
```

The accepted orders are `seqcst`, `acqrel`, and `relaxed`; `seq_cst` and `acq_rel`
remain accepted aliases and the printer's canonical spellings. Omission means
SeqCst. Linear RMW and cmpxchg take **one text order**. Their binary representation
uses matched order nibbles; enum ordinals are not binary encodings. Notify and
wait have no order immediate. A fence has no memory index, memory argument or
stack operands.

Memory declarations and imports preserve optional `i32`/`i64`, 64-bit memory64
limits and the trailing `shared` flag. Overflowing limit literals are rejected.
The WAST `MemoryType::new` constructor stores `min`, optional `max`, `shared`,
and `memory64` explicitly. Named and numeric atomic memory references resolve in
the ordinary imported-plus-defined memory index space.

[Parser and opcode mapping](../../../src/wast/atomic_memory.mbt),
[declarations](../../../src/wast/parser.mbt),
[lowering](../../../src/wast/lower_to_lib.mbt), and
[opcode/order byte fixtures](../../../src/wast/binaryen132_atomic_test.mbt)
cover these contracts. The matrix checks all linear opcode numbers and the
three order encodings, plus selected memory64 and import roundtrips.

## Aggregate atomic instructions

GC atomics use type/field indices rather than linear-memory `MemArg` values.
`struct.atomic.get`, `_s`, `_u`, `struct.atomic.set`, `array.atomic.get`, `_s`,
`_u`, and `array.atomic.set` accept one optional order before the type index.
Aggregate RMW and cmpxchg accept two matched orders before the type index;
mismatched orders are invalid. Omitted aggregate orders mean SeqCst.

The exact core carriers preserve the order through HOT lifting/lowering,
feature inference, type remapping and binary roundtrips. Stores have write and
trap effects. They remain atomic across the active pass regression sequences;
the new Relaxed order does not authorize replacing a store with an ordinary GC
write. See [shared-everything](../wasm-shared-everything-threads-boundary.md),
[store roundtrips](../../../src/ir/binaryen132_atomic_set_test.mbt), and
[pass ordering tests](../../../src/passes/binaryen132_atomic_set_test.mbt).

## Features, effects and execution

`--enable-acquire-release-atomics` / `--disable-acquire-release-atomics` and
`--enable-relaxed-atomics` / `--disable-relaxed-atomics` control separate
capabilities. GC atomics also infer `shared-everything`. These controls apply to
input and output validation, including copy-only CLI invocations. The default
continues accepting implemented forms; `--all-features` clears explicit proposal
disables. See [proposal validation](../../../src/validate/proposal_features.mbt).

Binaryen 132's Relaxed proposal is load-store ordered: an earlier atomic load
cannot move after a later atomic store, including across different heap classes.
Alias, traps, fences, acquire/release and sequential-consistency constraints also
apply. A single-thread execution comparison cannot establish this motion rule.
[Directional tests](../../../src/passes/binaryen132_effects_wbtest.mbt) and the
`binaryen132-atomic-orders` [GenValid generator](../../../src/validate/gen_valid_atomic_orders.mbt)
cover orders, shared/unshared heaps, memory64, stores, reads, RMW and fences.

Ordinary `MemArg` atomics validate against shared or unshared selected memories;
execution may distinguish them, particularly waits. Experimental GC and ordered
atomic forms require an engine that supports the matching proposal draft.
Runtime-unverified cases remain explicit. `safe-heap`, `de-align` and `pause`
are separate capability boundaries, not implied by these instruction carriers.
