# 0945 - Heap-store-optimization block-wrapped call_indirect old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is a `block (result i32)` wrapping `call_indirect`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root counterpart to `0944`'s block-wrapped `call_indirect` old-field store-root boundary.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-block-call-indirect-old-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(block (result i32)
  (call_indirect (type $sig) (i32.const 0))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-indirect-old-growth.wat \
  -S -o .tmp/hso-probe-block-call-indirect-old-growth.opt.wat

grep -n "call_indirect\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-indirect-old-growth.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
15:     (call_indirect $0 (type $sig)
23:   (memory.grow
27:  (struct.set $pair 0
38:   (struct.new $pair
40:     (call_indirect $0 (type $sig)
48:   (table.grow $0
53:  (struct.set $pair 0
```

## Finding

Binaryen preserves the block-wrapped `call_indirect`, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because that would drop or move the overwritten indirect-call old-field effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps block-wrapped call_indirect old fields before unrelated growth roots` passed immediately and asserts that `call_indirect`, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for block-wrapped `call_indirect` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `block(call_indirect)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0944`, branch/catch wrappers, descriptor interactions, direct `return_call_ref`, arbitrary typed-function-reference roots, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'block-wrapped call_indirect old fields before unrelated growth roots'
# Total tests: 311, passed: 311, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
