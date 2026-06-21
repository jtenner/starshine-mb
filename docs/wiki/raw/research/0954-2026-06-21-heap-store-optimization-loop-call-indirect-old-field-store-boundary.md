# 0954 - Heap-store-optimization loop-wrapped call_indirect old-field store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is a branchless `loop (result i32)` wrapping `call_indirect`, when an unrelated store root appears before the later same-field `struct.set`?

This extends the old-field wrapper sweep beyond block-wrapped `call_indirect` cases in `0944` / `0945` and if-wrapped `call_indirect` cases in `0948` / `0949`. It does not cover loop backedges, branch-containing loops, or arbitrary indirect-call wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-indirect-old-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_indirect (type $sig) (i32.const 0))
)
```

Then they execute either an unrelated `i32.store` or `table.set`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-indirect-old-store.wat \
  -S -o .tmp/hso-probe-loop-call-indirect-old-store.opt.wat

grep -n "call_indirect\|loop\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-indirect-old-store.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_indirect $0 (type $sig)
22:  (i32.store
26:  (struct.set $pair 0
37:   (struct.new $pair
38:    (loop (result i32)
39:     (call_indirect $0 (type $sig)
46:  (table.set $0
50:  (struct.set $pair 0
```

## Finding

Binaryen preserves the loop-wrapped indirect call, the unrelated `i32.store` / `table.set`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten indirect-call old-field effect across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_indirect old fields before unrelated stores` passed immediately and asserts that the loop-wrapped `call_indirect`, the intervening store root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branchless loop-wrapped `call_indirect` old fields before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_indirect)` old-field operands before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots beyond `0955`, loop backedges, branch/catch wrappers, direct calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_indirect old fields'
# Total tests: 321, passed: 321, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
