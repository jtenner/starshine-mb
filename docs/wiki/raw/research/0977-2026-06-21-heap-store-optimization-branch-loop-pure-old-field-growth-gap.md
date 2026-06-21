# Heap-store-optimization branch-loop pure old-field growth gap

## Question

Does Binaryen `version_130` fold a later same-field `struct.set` when the overwritten constructor field is a pure branch-containing outer-block / inner-loop value and an unrelated growth root intervenes?

## Fixture shape

Local probe: `.tmp/hso-probe-branch-loop-pure-old-field-growth.wat`.

Shape:

- field `0` of a fresh `struct.new` is initialized from a value-producing outer `block (result i32)` containing an inner void `loop`;
- the loop has a value-carrying `br_if` to the outer block result and a fallthrough `drop`;
- an unrelated `memory.grow` root follows the constructor assignment;
- a later same-field `struct.set` overwrites field `0` with `i32.const 4`.

A companion table-side probe `.tmp/hso-probe-branch-loop-pure-old-field-table-grow.wat` uses an unrelated `table.grow` root instead of `memory.grow`.

## Binaryen `version_130` result

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-branch-loop-pure-old-field-growth.wat \
  -S -o .tmp/hso-probe-branch-loop-pure-old-field-growth.opt.wat
```

Observed grep evidence:

```text
10:   (memory.grow
11:    (i32.const 1)
15:   (struct.new $S
16:    (i32.const 4)
```

For the table-side companion:

```text
10:   (table.grow $0
12:    (i32.const 1)
16:   (struct.new $S
17:    (i32.const 4)
```

Binaryen drops the pure overwritten branch-loop old field, keeps the unrelated growth root, folds the later value into `struct.new`, and removes the later `struct.set`.

## Starshine result

Command:

```sh
target/native/release/build/cmd/cmd.exe --heap-store-optimization \
  --dump .tmp/hso-probe-branch-loop-pure-old-field-growth.star.wat \
  .tmp/hso-probe-branch-loop-pure-old-field-growth.wat
```

Observed grep evidence:

```text
10:      loop ;; label = @2
11:        i32.const 1
13:        br_if 1 (;@1;)
16:      i32.const 2
18:    struct.new $S
20:    i32.const 1
21:    memory.grow
24:    i32.const 4
25:    struct.set $S 0
```

For the table-side companion, Starshine similarly preserves the old branch-loop value, `table.grow`, and the later `struct.set`.

The stderr included `sh: 1: wat2wasm: not found` from dump formatting, but the command exited `0` and emitted the dumped WAT.

## Classification

This is an open HSO-D/G parity gap, not a Starshine win:

- Binaryen proves the overwritten branch-containing old field has no observable side effects or traps and can be dropped.
- Starshine preserves the pure branch-loop old field and later same-field `struct.set`, missing the fold.
- This growth-root family is distinct from the effectful branch-loop call/call_indirect/call_ref old-field boundaries in `0970`-`0975` and from the direct cross-family growth swap positives in earlier notes.

A focused MoonBit AST fixture attempted during this slice hit a local validation/test-surface issue for value-carrying `br_if` in the direct HSO test helper. The WAT/CLI probe is therefore the current durable repro until a WAT-backed focused test or local AST surface fix lands.

## Reopening / next step

Implement or expose a safe droppable-old-field proof for branch-containing pure values whose branches are contained inside the old-field expression, then add focused positive coverage for both unrelated `memory.grow` and `table.grow` roots. The implementation must not generalize to effectful call/call_indirect/call_ref old fields, trapping old fields, or branch/catch roots that can escape the old-field expression.
