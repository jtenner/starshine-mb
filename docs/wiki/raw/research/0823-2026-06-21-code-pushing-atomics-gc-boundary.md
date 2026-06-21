---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../binaryen/passes/code-pushing/wat-shapes.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/ir/hot_core.mbt
  - ../../../../src/ir/pkg.generated.mbti
---

# Code Pushing Atomics / GC Boundary

## Question

Continue the `[O4Z-AUDIT-CP]` parity audit on the `version_130` `code-pushing-atomics.wast` family: can Starshine safely move a nontrapping GC `struct.get` across linear-memory atomic operations, and where is the store boundary?

## Binaryen oracle

The official `version_130` lit file `test/lit/passes/code-pushing-atomics.wast` is the primary source. It uses a shared struct type and shared memory:

```wat
(type $struct (shared (struct (field (mut i32)))))
(memory $mem 1 1 shared)
```

It records four cases:

1. `allowed`: a GC `struct.get` of a non-null shared struct is pushed past `i32.atomic.load acqrel` into the sole consuming `if` arm.
2. `disallowed`: the same GC read is **not** pushed past `i32.atomic.store acqrel` into an `if` arm.
3. `allowed_segment`: the same GC read is pushed past `i32.atomic.load acqrel` and a later `if` push point for suffix use after the `if`.
4. `disallowed_segment`: the same GC read is **not** pushed past `i32.atomic.store acqrel`, even when the use is after the later `if` push point.

Local confirmation used reduced WAT probes with the official shared type and `wasm-opt --all-features --code-pushing -S`:

```sh
for name in into-if-load into-if-store segment-load segment-store; do
  wasm-opt --all-features --code-pushing -S \
    .tmp/cp-atomics-${name}-probe.wat \
    -o .tmp/cp-atomics-${name}-probe.opt.wat
  grep -n "struct.get\|atomic\|local.set\|if" \
    .tmp/cp-atomics-${name}-probe.opt.wat
done
```

The reduced shared probes matched the official lit expectations: load cases moved, store cases stayed before the atomic store.

A misleading intermediate probe without the shared struct type moved across stores; that shape is **not** the lit/source-backed release-gating boundary for this slice.

## Starshine implementation slice

Starshine's WAT surface could not parse the official shared-GC WAT syntax during this slice, so the regression tests build the HOT fixture directly.

Changes:

- `src/ir/hot_core.mbt` exposes `pub fn HotOp::atomic_op() -> HotOp` so pass tests can construct exact HOT atomic nodes without opening the read-only `HotOp::Atomic` constructor from the test package.
- `src/ir/pkg.generated.mbti` records that public API addition.
- `src/passes/code_pushing_test.mbt` adds a HOT fixture containing:
  - param 0: a non-null exact struct reference;
  - param 1: an `i32` condition;
  - local 2: an `i32` temporary;
  - a `Heap` node with exact `StructGet` from `local.get 0`;
  - an `Atomic` node with exact `i32.atomic.load` or `i32.atomic.store` payload and memarg side-table entry.
- The tests cover the four official-shape expectations:
  - load may sink into the sole consuming `if` arm;
  - store remains a boundary for into-`if` sinking;
  - load may move before a suffix-use segment after an `if` push point;
  - store remains a boundary for segment movement.
- `src/passes/code_pushing.mbt` now recognizes only a narrow nontrapping heap-read value:
  - live `HotOp::Heap`;
  - exact `StructGet`, `StructGetS`, or `StructGetU`;
  - exactly one child;
  - child is a `local.get`;
  - child type is non-nullable ref.
- Crossing checks for this heap-read family reject intervening source-local writes and reject call/throw/global-state/memory-write/table-write effects. That admits atomic loads and blocks atomic stores.

## Validation

Focused native tests:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*atomic*'
moon test src/passes/code_pushing_test.mbt --target native
moon fmt
moon info
```

Results:

```text
Total tests: 4, passed: 4, failed: 0.
Total tests: 56, passed: 56, failed: 0.
Finished. moon: ran 3 tasks, now up to date
Finished. moon: ran 2 tasks, now up to date (3 warnings, 0 errors)
```

The `moon info` warnings are pre-existing unused-value / unused-helper warnings outside this slice.

## Follow-ups

- The HOT fixture is an approximation because Starshine does not yet expose the exact shared GC type syntax through WAT. If/when shared-GC parsing/lowering is added, replace or supplement these tests with WAT-level coverage mirroring `code-pushing-atomics.wast`.
- This slice does **not** implement general GC/reference movement. It admits only non-null struct reads from a local source.
- This slice does **not** implement general Binaryen `Effects::orderedBefore`; it adds a bounded effect predicate sufficient for the official atomics load/store proof surface.
- `[O4Z-AUDIT-CP]` remains active; EH, broader GC/reference expressions, switch positives, `br_on_*`, branch-value conditional branches, trap-option widening, and final 10000-case pass-local signoff remain open.
