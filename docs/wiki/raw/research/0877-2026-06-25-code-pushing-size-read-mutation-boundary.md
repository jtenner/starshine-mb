# Code-pushing size-read/mutation boundaries

Date: 2026-06-25

## Question

After the pure-value movement slices across dropped `memory.grow`, `table.grow`, `memory.size`, and `table.size` roots, does Binaryen v130 move a candidate value that reads memory/table size across matching growth before a later `br_if` push point?

## Probes

Reduced local probes:

- `.tmp/cp-probes/memory-size-candidate-across-memory-grow-before-brif.wat`
- `.tmp/cp-probes/table-size-candidate-across-table-grow-before-brif.wat`

Shapes:

```wat
(module
  (memory 1)
  (func (param $p i32) (local $tmp i32)
    (block $exit
      memory.size
      local.set $tmp
      i32.const 1
      memory.grow
      drop
      local.get $p
      br_if $exit
      local.get $tmp
      drop)))
```

```wat
(module
  (table 1 funcref)
  (func (param $p i32) (local $tmp i32)
    (block $exit
      table.size 0
      local.set $tmp
      ref.null func
      i32.const 1
      table.grow 0
      drop
      local.get $p
      br_if $exit
      local.get $tmp
      drop)))
```

Commands:

```sh
wasm-tools parse .tmp/cp-probes/memory-size-candidate-across-memory-grow-before-brif.wat -o .tmp/cp-probes/memory-size-candidate-across-memory-grow-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/memory-size-candidate-across-memory-grow-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/memory-size-candidate-across-memory-grow-before-brif.wat --code-pushing -S -o -
wasm-tools parse .tmp/cp-probes/table-size-candidate-across-table-grow-before-brif.wat -o .tmp/cp-probes/table-size-candidate-across-table-grow-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/table-size-candidate-across-table-grow-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/table-size-candidate-across-table-grow-before-brif.wat --code-pushing -S -o -
```

## Binaryen v130 result

Local `wasm-opt version 130 (version_130)` kept both size-reading candidate `local.set` roots before the matching growth root and later `br_if`.

These are Binaryen-stationary boundaries: the positive pure-value movement across dropped size reads and dropped growth roots does not generalize to candidate values whose computed value depends on the size being mutated.

## Starshine coverage

Added intentionally unsupported/Binaryen-stationary focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps memory.size value before memory.grow and br_if push point`
- `code-pushing boundary keeps table.size value before table.grow and br_if push point`

The tests assert that the size-reading `local.set` remains before the dropped growth root and later `br_if`.

## Validation

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*size value before*'
```

Result: `2/2` passed.

## Conclusion

`[O4Z-AUDIT-CP]` should keep the current distinction between pure values that do not observe memory/table size and size-dependent candidate values. A `memory.size` candidate stays before `memory.grow`, and a `table.size` candidate stays before `table.grow`, even when a later `br_if` would otherwise be a push point. Reopen only if future Binaryen probes move these shapes, if Starshine grows a more precise size/growth effect proof, or if generated compare exposes a mismatch in a narrower size-read/growth window.

This slice is characterization-only: no pass implementation or GenValid profile changed, and it does not refresh the required post-`0861` final matrix lanes.
