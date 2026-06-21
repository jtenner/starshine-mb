# 0968 - Heap-store-optimization branch-loop call_ref constructor store boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle a typed-function-reference `call_ref` in a value-producing, branch-containing loop wrapper used as a fresh `struct.new` constructor operand when an unrelated store root appears before a later `struct.set` to another field?

This extends the branch-containing direct-call and `call_indirect` constructor store boundaries in `0964` and `0966`, plus the branchless loop-wrapped `call_ref` constructor store boundary in `0962`. It does not cover growth roots, ordinary direct calls, indirect calls, old-field operands, loop backedges, descriptor interactions, `return_call_ref`, or arbitrary branch/catch wrappers.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe files:

- `.tmp/hso-probe-branch-loop-call-ref-constructor-store.wat`
- `.tmp/hso-probe-branch-loop-call-ref-constructor-table-store.wat`

Both functions build a fresh `$pair` where field 0 is produced by a block result containing a loop with a branch to the outer result block:

```wat
(block $exit (result i32)
  (loop $loop
    (call_ref $callee (local.get $f))
    (i32.const 1)
    (br_if $exit)
    (drop)
  )
  (i32.const 3)
)
```

Then they execute either an unrelated `i32.store` or `table.set`, write field 1 with a later `struct.set`, and read field 1.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-constructor-store.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-constructor-store.opt.wat

grep -n "call_ref\|loop\|br_if\|i32.store\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-constructor-store.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-call-ref-constructor-table-store.wat \
  -S -o .tmp/hso-probe-branch-loop-call-ref-constructor-table-store.opt.wat

grep -n "call_ref\|loop\|br_if\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-branch-loop-call-ref-constructor-table-store.opt.wat
```

Observed grep summary:

```text
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
27:  (i32.store
31:  (struct.set $pair 1
10:   (struct.new $pair
12:     (loop
14:       (br_if $block
15:        (call_ref $callee
27:  (table.set $0
31:  (struct.set $pair 1
```

## Finding

Binaryen preserves the branch-containing loop wrapper, the wrapped `call_ref` constructor operand, the unrelated `i32.store` / `table.set`, and the later `struct.set` to another field. It does not fold the later store into `struct.new` because doing so would move the constructor operand `call_ref` across an unrelated store root.

Starshine already matched this behavior. The focused test `heap-store-optimization keeps branch-containing loop call_ref constructor operands before unrelated stores` passed immediately and asserts that the typed-function-reference call, `loop`, `br_if`, intervening store root, and later `struct.set` remain in order.

The focused module fixture now adds an explicit memory to the `call_ref` table helper so memory-store variants validate alongside existing table-side variants.

## Coverage impact

- Adds HSO-D constructor shallow-effect ordering coverage for branch-containing loop-wrapped `call_ref` constructor operands before unrelated store roots.
- Adds HSO-G wrapper/no-swap evidence for a branch-containing loop/block wrapper around a typed-function-reference call constructor operand before unrelated `i32.store` and `table.set` roots.
- Does not generalize to growth roots, direct calls beyond `0964`, indirect calls beyond `0966`, old-field operands, loop backedges, branch/catch wrappers beyond this exact outer-block/inner-loop `br_if` shape, descriptor interactions, `return_call_ref`, or all HOT wrapper forms.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'branch-containing loop call_ref constructor operands before unrelated stores'
# Total tests: 335, passed: 335, failed: 0.
```

No native rebuild or direct compare was required for this coverage/classification-only slice because Starshine behavior already matched Binaryen and no implementation changed.
