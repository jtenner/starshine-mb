# 0960 - Heap-store-optimization loop-wrapped call_indirect constructor store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping `call_indirect` as a fresh `struct.new` constructor operand when an unrelated store root appears before a later `struct.set` to another field?

This extends the constructor-operand wrapper sweep beyond the block-wrapped `call_indirect` cases in `0938` / `0939` and the direct-call loop constructor cases in `0958` / `0959`. It does not cover loop backedges, branch-containing loop bodies, ordinary direct calls, `call_ref`, descriptor interactions, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-indirect-constructor-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_indirect (type $sig) (i32.const 0))
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-indirect-constructor-store.wat \
  -S -o .tmp/hso-probe-loop-call-indirect-constructor-store.opt.wat

grep -n "call_indirect\|loop\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-indirect-constructor-store.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_indirect $0 (type $sig)
22:  (i32.store
26:  (struct.set $pair 1
37:   (struct.new $pair
38:    (loop (result i32)
39:     (call_indirect $0 (type $sig)
46:  (table.set $0
50:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped `call_indirect` constructor operand, the unrelated `i32.store` / `table.set`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand indirect call across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_indirect constructor operands before unrelated stores` passed immediately and asserts that the loop-wrapped indirect call, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped `call_indirect` constructor operands before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_indirect)` constructor operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0961`, old-field boundaries beyond `0954` / `0955`, loop backedges, branch/catch wrappers, direct calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_indirect constructor operands'
# Total tests: 327, passed: 327, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
