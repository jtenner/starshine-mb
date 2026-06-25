# Code-pushing memory/table read-mutation boundaries

Date: 2026-06-25

## Question

After the pure-value movement slices across `memory.store` and `table.set`, does Binaryen v130 move candidate values that read the same memory/table state across matching mutation before a later `br_if` push point?

## Probes

Reduced local probes:

- `.tmp/cp-probes/load-candidate-across-memory-store-before-brif.wat`
- `.tmp/cp-probes/table-get-candidate-across-table-set-before-brif.wat`

Shapes:

```wat
(module
  (memory 1)
  (func (param $p i32) (local $tmp i32)
    (block $exit
      i32.const 0
      i32.load
      local.set $tmp
      i32.const 0
      i32.const 42
      i32.store
      local.get $p
      br_if $exit
      local.get $tmp
      drop)))
```

```wat
(module
  (table 1 funcref)
  (func $f)
  (elem declare func $f)
  (func (param $p i32) (local $tmp funcref)
    (block $exit
      i32.const 0
      table.get 0
      local.set $tmp
      i32.const 0
      ref.func $f
      table.set 0
      local.get $p
      br_if $exit
      local.get $tmp
      drop)))
```

## Binaryen v130 result

Local `wasm-opt version 130 (version_130)` kept both state-reading candidate `local.set` roots before the matching mutation root and later `br_if`:

- `i32.load` stayed before `i32.store`;
- `table.get` stayed before `table.set`.

These are Binaryen-stationary boundaries. The positive pure-value movement across memory/table writes does not generalize to candidate values whose computed value reads the state being mutated.

## Starshine coverage

Added intentionally unsupported/Binaryen-stationary focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps load value before memory.store and br_if push point`
- `code-pushing boundary keeps table.get value before table.set and br_if push point`

The table fixture defines the tested function before helper `$f` so `pass_test_lift_first_func(...)` optimizes the intended function.

## Validation

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*value before*'
```

Result: `5/5` passed, covering this slice plus the earlier global/size boundary tests matched by the same filter.

## Conclusion

`[O4Z-AUDIT-CP]` should keep memory/table state reads distinct from pure values. An `i32.load` candidate remains before a matching `i32.store`, and a `table.get` candidate remains before a matching `table.set`, even when a later `br_if` would otherwise be a push point. Reopen only if future Binaryen probes move these shapes, if Starshine grows a more precise alias/effect proof, or if generated compare exposes a mismatch in a narrower read/write window.

This slice is characterization-only: no pass implementation or GenValid profile changed, and it does not refresh the required post-`0861` final matrix lanes.
