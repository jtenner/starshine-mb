# 0964 - Heap-store-optimization branch-loop call constructor store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an ordinary direct call in a value-producing, branch-containing loop wrapper used as a fresh `struct.new` constructor operand when an unrelated store root appears before a later `struct.set` to another field?

This extends the direct-call constructor wrapper sweep beyond branchless loop wrappers in `0958`, block wrappers in `0936`, and direct-root store cases in `0928`. It does not cover growth roots, indirect calls, typed-function-reference calls, old-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-branch-loop-call-constructor-store.wat`.

Both functions build a fresh `$pair` where field 0 is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block $exit (result i32)
  (loop $loop
    (call $side)
    (i32.const 1)
    (br_if $exit)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 1 with a later `struct.set`, and read field 1.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-constructor-store.wat \
  -S -o .tmp/hso-probe-branch-loop-call-constructor-store.opt.wat

grep -n "call\|loop\|br_if\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-constructor-store.opt.wat
```

Observed grep summary:

```text
14:   (struct.new $pair
16:     (loop $loop
18:       (br_if $exit
19:        (call $side)
29:  (i32.store
33:  (struct.set $pair 1
44:   (struct.new $pair
46:     (loop $loop
48:       (br_if $exit
49:        (call $side)
59:  (table.set $0
63:  (struct.set $pair 1
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped direct call constructor operand, the unrelated `i32.store` / `table.set`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand call across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call constructor operands before unrelated stores` passed immediately and asserts that the call, `loop`, `br_if`, intervening store root, and later `struct.set` remain in order.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branch-containing loop-wrapped direct-call constructor operands before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a constructor operand before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots, indirect calls, typed-function-reference calls, old-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call constructor operands before unrelated stores'
# Total tests: 331, passed: 331, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
