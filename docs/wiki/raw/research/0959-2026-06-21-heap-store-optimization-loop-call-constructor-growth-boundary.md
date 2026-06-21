# 0959 - Heap-store-optimization loop-wrapped call constructor growth boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a branchless `loop (result i32)` wrapping an ordinary direct `call` as a fresh `struct.new` constructor operand when an unrelated growth root appears before a later `struct.set` to another field?

This is the growth-root counterpart to `0958`. It does not cover loop backedges, branch-containing loop bodies, indirect calls, `call_ref`, descriptor interactions, or arbitrary wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-loop-call-constructor-growth.wat`.

Both functions build a fresh `$pair` where field 0 is produced by:

```wat
(loop (result i32)
  (call $callee)
)
```

Then they execute either an unrelated `memory.grow` or `table.grow`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-loop-call-constructor-growth.wat \
  -S -o .tmp/hso-probe-loop-call-constructor-growth.opt.wat

grep -n "call\|loop\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-loop-call-constructor-growth.opt.wat
```

Observed grep summary:

```text
6: (func $callee (type $sig) (result i32)
12:   (struct.new $pair
13:    (loop (result i32)
14:     (call $callee)
20:   (memory.grow
24:  (struct.set $pair 1
35:   (struct.new $pair
36:    (loop (result i32)
37:     (call $callee)
43:   (table.grow $0
48:  (struct.set $pair 1
```

## Finding

Binaryen preserves the loop-wrapped direct call constructor operand, the unrelated `memory.grow` / `table.grow`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand call across an unrelated growth root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps loop-wrapped call constructor operands before unrelated growth roots` passed immediately and asserts that the loop-wrapped call, the intervening growth root, and the later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branchless loop-wrapped direct-call constructor operands before unrelated growth roots.
- Adds HSO-G wrapper/no-swap evidence for `loop(call)` constructor operands before unrelated `memory.grow` and `table.grow` roots.
- Does not generalize to store roots beyond `0958`, old-field boundaries beyond `0952` / `0953`, loop backedges, branch/catch wrappers, indirect calls, `call_ref`, descriptor interactions, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'loop-wrapped call constructor operands'
# Total tests: 325, passed: 325, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
