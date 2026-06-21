# 0955 - Heap-store-optimization loop-wrapped call_indirect old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is a branchless `loop (result i32)` wrapping `call_indirect`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root counterpart to `0954` and extends the old-field wrapper sweep beyond block-wrapped `call_indirect` growth cases in `0945` and if-wrapped `call_indirect` growth cases in `0949`. It does not cover loop backedges, branch-containing loops, or arbitrary indirect-call wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-indirect-old-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_indirect (type $sig) (i32.const 0))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-indirect-old-growth.wat \
  -S -o .tmp/hso-probe-loop-call-indirect-old-growth.opt.wat

grep -n "call_indirect\|loop\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-indirect-old-growth.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_indirect $0 (type $sig)
23:   (memory.grow
27:  (struct.set $pair 0
35: (func $table_grow (type $sig) (result i32)
38:   (struct.new $pair
39:    (loop (result i32)
40:     (call_indirect $0 (type $sig)
48:   (table.grow $0
53:  (struct.set $pair 0
```

## Finding

Binaryen preserves the loop-wrapped indirect call, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten indirect-call old-field effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_indirect old fields before unrelated growth roots` passed immediately and asserts that the loop-wrapped `call_indirect`, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branchless loop-wrapped `call_indirect` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_indirect)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0954`, loop backedges, branch/catch wrappers, direct calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_indirect old fields'
# Total tests: 321, passed: 321, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
