---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0792-2026-06-20-heap-store-optimization-unreachable-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# HSO unreachable boundary final wording

Question: can `[O4Z-AUDIT-HSO-H]` treat the unreachable constructor/set-value boundary as source-backed and covered, while still keeping the local direct-root set-value fixture caveat visible?

## Answer

Yes. Binaryen `version_130` keeps `heap-store-optimization` from folding constructor/store pairs when the constructor or moved `struct.set` value is typed unreachable. It leaves those shapes for later DCE instead of rewriting fields or repairing types inside HSO.

A fresh local probe with direct root `unreachable` operands confirmed the observable release-oracle behavior:

- `$unreachable_ctor`: Binaryen preserves a `struct.set` after the unreachable constructor side.
- `$unreachable_set_value`: Binaryen preserves a `struct.set` whose set value is direct `unreachable`.

Starshine already has focused boundary coverage from `0792`:

- `heap-store-optimization leaves unreachable constructors to later DCE`
- `heap-store-optimization leaves unreachable set values to later DCE`

Those tests assert that the optimized function still contains `unreachable`, `struct.set`, and the relevant original constants. They are coverage-only guards for the no-fold boundary; no implementation behavior changed in this slice.

## Local fixture caveat

The Starshine set-value test still uses a block-valued `unreachable` operand rather than the exact direct-root `unreachable` spelling. The direct-root set-value fixture limitation remains a local HOT/test-surface limitation, not a semantic HSO non-goal and not permission to diverge from Binaryen. Reopen this wording if exact lit-shape replay becomes necessary, if the HOT/decode surface grows enough to express the direct-root fixture cleanly, or if Binaryen starts folding unreachable constructor/set pairs in HSO.

## Probe command

```sh
cat > .tmp/hso-probe-unreachable-direct.wat <<'EOF'
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (func $unreachable_ctor (result i32)
    (local $x (ref null $pair))
    unreachable
    struct.new $pair
    local.set $x
    local.get $x
    i32.const 10
    struct.set $pair 0
    i32.const 0)
  (func $unreachable_set_value (result i32)
    (local $x (ref null $pair))
    i32.const 1
    i32.const 2
    struct.new $pair
    local.set $x
    local.get $x
    unreachable
    struct.set $pair 0
    i32.const 0)
)
EOF
wasm-opt --all-features .tmp/hso-probe-unreachable-direct.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-unreachable-direct.opt.wat
```

Observed grep summary of the optimized WAT retained both `struct.set` roots plus the relevant `unreachable` roots. This matches `0792`'s focused Starshine no-fold tests and closes the final unreachable wording piece of HSO-H.

## Validation

No Moon tests were rerun for this docs/probe-only wording slice. The existing focused tests from `0792` remain the executable Starshine coverage. No native rebuild or direct compare was required because no implementation behavior or test expectation changed.

## Remaining HSO-H work

HSO-H still remains open for exact-cast local surface limits, the descriptor `br_on_non_null` HOT CFG/verifier surface limit, and the direct-root unreachable set-value fixture limitation. Generic DSE/load-forwarding is covered separately by `0867`; array-store boundaries are covered by `0790`.
