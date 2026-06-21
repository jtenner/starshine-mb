# 0963 - Heap-store-optimization loop-wrapped call_ref constructor growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping typed-function-reference `call_ref` as a fresh `struct.new` constructor operand when an unrelated growth root appears before a later `struct.set` to another field?

This is the growth-root counterpart to `0962` and extends the constructor-operand wrapper sweep beyond the block-wrapped `call_ref` growth cases in `0941`, the direct-root `call_ref` growth case in `0933`, the direct-call loop constructor growth case in `0959`, and the `call_indirect` loop constructor growth case in `0961`. It does not cover store roots beyond `0962`, old-field operands, loop backedges, branch-containing loops, descriptor interactions, `return_call_ref`, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-ref-constructor-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_ref $callee (ref.as_non_null (local.get $f)))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-ref-constructor-growth.wat \
  -S -o .tmp/hso-probe-loop-call-ref-constructor-growth.opt.wat

grep -n "call_ref\|loop\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-ref-constructor-growth.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_ref $callee
25:   (memory.grow
29:  (struct.set $pair 1
40:   (struct.new $pair
41:    (loop (result i32)
42:     (call_ref $callee
52:   (table.grow $0
57:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped `call_ref` constructor operand, the unrelated `memory.grow` / `table.grow`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand `call_ref` across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_ref constructor operands before unrelated growth roots` passed immediately and asserts that the loop-wrapped typed call, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped `call_ref` constructor operands before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_ref)` constructor operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0962`, old-field boundaries beyond `0956` / `0957`, loop backedges, branch/catch wrappers, `return_call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_ref constructor operands before unrelated growth roots'
# Total tests: 329, passed: 329, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
