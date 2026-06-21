# Heap-store-optimization call_indirect table-set constructor boundary

## Question

Does Binaryen `version_130` preserve a `call_indirect` constructor operand before an unrelated `table.set`, matching the existing global-set constructor-operand boundary?

## Probe

Fixture: `.tmp/hso-probe-call-indirect-constructor-table-set.wat`.

Shape:

- construct `$pair` with field `0` from `call_indirect (type $callee) (i32.const 0)` and field `1` from `i32.const 2`;
- store the fresh struct in a local;
- execute an unrelated `table.set`;
- later write field `1` with `struct.set`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-constructor-table-set.wat \
  -S -o .tmp/hso-probe-call-indirect-constructor-table-set.opt.wat
```

Grep evidence:

```text
8:   (struct.new $pair
9:    (call_indirect $0 (type $callee)
15:  (table.set $0
19:  (struct.set $pair 1
```

## Result

Binaryen preserves the `call_indirect`, the unrelated `table.set`, and the later `struct.set`. It does not fold by moving the later store value before the indirect call / table-store ordering boundary.

Starshine already matched this behavior. Added focused HSO-G coverage:

- `heap-store-optimization keeps call_indirect constructor operands before unrelated table.set`

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_indirect'
```

Result: `286/286` passed after this and the companion old-field coverage were present.

## Classification

HSO-G coverage-only Binaryen parity boundary. No implementation behavior changed; no native rebuild or direct compare was required.

## Reopening criteria

Reopen if Binaryen changes this `call_indirect` / `table.set` ordering behavior, if Starshine begins folding this shape, or if a narrower proof shows the indirect-call constructor operand can move across the unrelated table store without changing observable behavior and Binaryen also accepts that movement.
