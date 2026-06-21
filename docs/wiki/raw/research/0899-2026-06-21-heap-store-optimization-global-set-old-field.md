# 0899 - Heap-store-optimization global-set old-field parity fix

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into `struct.new` when the overwritten constructor field is a value-producing block with a `global.set`, and an intervening root writes a different mutable global?

This extends the side-effectful old-field matrix after `0897`/`0898` from memory/table growth to exact mutable-global writes. The key distinction is that same-global writes/reads remain ordered barriers, while unrelated globals should not block the fold.

## Binaryen oracle probe

Temporary fixture: `.tmp/hso-probe-global-set-old-field.wat`.

Shape:

- construct `$s` with field `0` initialized by `(block (result i32) (global.set $g0 (i32.const 7)) (i32.const 2))` and field `1` initialized by `i32.const 3`;
- write unrelated mutable global `$g1`;
- overwrite field `0` with `i32.const 42`;
- return field `0` from the fresh local.

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-global-set-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-global-set-old-field.opt.wat && \
grep -E "global.set|struct.new|struct.set|drop|block" \
  .tmp/hso-probe-global-set-old-field.opt.wat && \
cat .tmp/hso-probe-global-set-old-field.opt.wat
```

Local oracle: `wasm-opt version 130 (version_130)`.

Result:

- Binaryen removed the later `struct.set`;
- Binaryen preserved the old field's `$g0` write under `drop` in a value-producing block whose result is the replacement value `42`;
- Binaryen kept the unrelated `$g1` root write before the constructor/local-set block;
- Binaryen did not treat unrelated mutable global writes as an ordering conflict.

Classification: this is a behavior-parity positive fold, not a Starshine win. Correct behavior may move the constructor local-set across an unrelated global write if exact-global conflict analysis proves the old field and blocker touch different globals, but same-global barriers remain blocking.

## Starshine change

Added focused red-first coverage in `src/passes/heap_store_optimization_test.mbt`:

- test `heap-store-optimization folds global-set old fields across unrelated global.set` builds the probed two-global shape;
- it asserts the old `$g0` side effect and intervening `$g1` write remain observable in optimized output, while the redundant later `struct.set` disappears.

Initial focused run failed: Starshine preserved the later `struct.set`. The root cause was `hso_global_only_ordering_can_be_ignored(...)`: it rejected all constructor operands containing any global write before consulting exact-global order conflict analysis, so an old-field write to `$g0` could not move across a blocker write to unrelated `$g1`.

Implementation:

- removed the broad `hso_struct_new_operand_has_global_write(...)` veto;
- made `hso_global_only_ordering_can_be_ignored(...)` rely on `hso_subtree_global_order_conflicts(...)` plus the existing constructor-global-read conflict check.

This keeps same-global write/read and write/write barriers closed while allowing unrelated global-write old-field preservation to match Binaryen.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Initial red-first run after adding the test: `256/257` passed; the new test failed with `struct.set` still present.

After the implementation fix:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-hso-global-write-old-field-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- focused HSO tests: `257/257` passed;
- native `src/cmd` release build completed with pre-existing `pass_manager.mbt` unused-function warnings;
- direct compare `.tmp/pass-fuzz-hso-global-write-old-field-10000`: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, `0` command failures; Binaryen cache `10000` hits / `0` misses.

## Durable conclusion

HSO now matches Binaryen for an overwritten old-field global-write positive: unrelated mutable global writes do not block folding when exact-global conflict analysis proves independence. This narrows HSO-D/G old-field and swap legality gaps without changing same-global ordering boundaries.

## Reopening criteria

Reopen this family if:

- a same-global `global.get`/`global.set` barrier starts folding across a constructor old-field write without Binaryen/source evidence;
- an unrelated-global old-field write regresses to preserving `struct.set` without a documented Starshine win;
- descriptor/default variants or nested wrapper variants with old-field global writes show different Binaryen behavior;
- Binaryen changes global-write movement rules in a newer release oracle.
