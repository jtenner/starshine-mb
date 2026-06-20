---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0783-2026-06-20-heap-store-optimization-swap-memory-and-pingpong.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` final-root no-swap coverage

Question: does Starshine preserve Binaryen `version_130`'s `trySwap(...)` boundary that refuses to swap a fresh-struct `local.set` with the final root in a block/list?

## Answer

Yes. Binaryen `version_130` source explicitly returns `false` in `trySwap(...)` when the blocker index is the last element of the list. The source comment gives two reasons: there is no later root after the final element that could match the desired `struct.set` pattern, and swapping a stack-producing final root with a void fresh-struct local assignment can change the surrounding stack shape.

This is a swap-legality no-op boundary, not a new optimization opportunity. The focused Starshine coverage locks the visible behavior: a fresh `struct.new_default` assigned to a local remains before a final `i32.const` result root.

## Binaryen probe

Probe input:

```wat
(module
  (type $pair (sub (struct (field (mut i32)))))
  (func (result i32)
    (local $x (ref null $pair))
    (local.set $x (struct.new_default $pair))
    (i32.const 42)
  )
)
```

Command:

```sh
mkdir -p .tmp/hso-final-element-probe
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-final-element-probe/final-element.wat \
  -o .tmp/hso-final-element-probe/final-element.opt.wat
```

Observed output keeps the fresh local assignment before the final value root:

```wat
(func $0 (type $1) (result i32)
 (local $x (ref null $pair))
 (local.set $x
  (struct.new_default $pair)
 )
 (i32.const 42)
)
```

## Local change

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization does not swap the fresh local.set with the final root`

The test uses the same source-backed shape and asserts that the printed optimized function still has `local.set` before the final `I32(42)` root.

A small local substring-index helper was added for this order assertion.

## Evidence

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 83, passed: 83, failed: 0.
```

No implementation code changed in this slice, so no native rebuild or direct 10000-case compare was required for behavior signoff. This is coverage for an intentionally unsupported swap boundary already present in Binaryen and Starshine.

## Remaining HSO-G work

This closes the specific final-root swap boundary coverage item. HSO-G remains open for broader swap legality review: additional constructor ping-pong variants, table combinations, broader operand/effect directionality, and HOT wrapper peeling/flattening drift still need inspection before final closeout.
