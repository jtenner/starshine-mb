# 0949 - Heap-store-optimization if-wrapped call_indirect old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is an `if (result i32)` wrapping `call_indirect`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root counterpart to `0948`'s if-wrapped `call_indirect` old-field store-root boundary.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-if-call-indirect-old-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(if (result i32) (i32.const 1)
  (then (call_indirect (type $sig) (i32.const 0)))
  (else (i32.const 3))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-if-call-indirect-old-growth.wat \
  -S -o .tmp/hso-probe-if-call-indirect-old-growth.opt.wat

grep -n "call_indirect\|if\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-if-call-indirect-old-growth.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (if (result i32)
17:      (call_indirect $0 (type $sig)
29:   (memory.grow
33:  (struct.set $pair 0
44:   (struct.new $pair
45:    (if (result i32)
48:      (call_indirect $0 (type $sig)
60:   (table.grow $0
65:  (struct.set $pair 0
```

## Finding

Binaryen preserves the if-wrapped `call_indirect`, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because that would drop or move the overwritten indirect-call old-field effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps if-wrapped call_indirect old fields before unrelated growth roots` passed immediately and asserts that `call_indirect`, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for if-wrapped `call_indirect` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `if(call_indirect)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0948`, branch/catch wrappers, descriptor interactions, direct `call_ref` / `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'if-wrapped call_indirect old fields'
# Total tests: 315, passed: 315, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
