# 0957 - Heap-store-optimization loop-wrapped call_ref old-field growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose original value is a branchless `loop (result i32)` wrapping typed-function-reference `call_ref`, when an unrelated growth root appears before the later same-field `struct.set`?

This is the growth-root counterpart to `0956` and extends the old-field wrapper sweep beyond block-wrapped `call_ref` growth cases in `0943` and if-wrapped `call_ref` growth cases in `0951`. It does not cover loop backedges, branch-containing loops, or arbitrary typed-function-reference wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-ref-old-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (local.get $f)
  (ref.as_non_null)
  (call_ref $callee)
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, overwrite field 0 with a later same-field `struct.set`, and read field 0.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-ref-old-growth.wat \
  -S -o .tmp/hso-probe-loop-call-ref-old-growth.opt.wat

grep -n "call_ref\|loop\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-ref-old-growth.opt.wat
```

Observed grep summary:

```text
10:   (struct.new $pair
11:    (loop (result i32)
12:     (call_ref $callee
22:   (memory.grow
26:  (struct.set $pair 0
37:   (struct.new $pair
38:    (loop (result i32)
39:     (call_ref $callee
49:   (table.grow $0
54:  (struct.set $pair 0
```

## Finding

Binaryen preserves the loop-wrapped `call_ref`, the unrelated `memory.grow` / `table.grow`, and the later same-field `struct.set`. It does not fold the later store into `struct.new` because doing so would drop or move the overwritten typed-function-reference call old-field effect across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_ref old fields before unrelated growth roots` passed immediately and asserts that the loop-wrapped `call_ref`, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D old-field side-effect preservation coverage for branchless loop-wrapped `call_ref` old fields before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_ref)` old-field operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0956`, loop backedges, branch/catch wrappers, direct calls, `call_indirect`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_ref old fields'
# Total tests: 323, passed: 323, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
