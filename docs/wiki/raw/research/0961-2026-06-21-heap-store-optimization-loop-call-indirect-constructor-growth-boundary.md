# 0961 - Heap-store-optimization loop-wrapped call_indirect constructor growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping `call_indirect` as a fresh `struct.new` constructor operand when an unrelated growth root appears before a later `struct.set` to another field?

This is the growth-root counterpart to `0960`. It does not cover loop backedges, branch-containing loop bodies, ordinary direct calls, `call_ref`, descriptor interactions, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-indirect-constructor-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call_indirect (type $sig) (i32.const 0))
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-indirect-constructor-growth.wat \
  -S -o .tmp/hso-probe-loop-call-indirect-constructor-growth.opt.wat

grep -n "call_indirect\|loop\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-indirect-constructor-growth.opt.wat
```

Observed grep summary:

```text
13:   (struct.new $pair
14:    (loop (result i32)
15:     (call_indirect $0 (type $sig)
23:   (memory.grow
27:  (struct.set $pair 1
38:   (struct.new $pair
39:    (loop (result i32)
40:     (call_indirect $0 (type $sig)
48:   (table.grow $0
53:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped `call_indirect` constructor operand, the unrelated `memory.grow` / `table.grow`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand indirect call across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call_indirect constructor operands before unrelated growth roots` passed immediately and asserts that the loop-wrapped indirect call, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped `call_indirect` constructor operands before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call_indirect)` constructor operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0960`, old-field boundaries beyond `0954` / `0955`, loop backedges, branch/catch wrappers, direct calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call_indirect constructor operands'
# Total tests: 327, passed: 327, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
