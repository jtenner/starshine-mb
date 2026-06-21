# Heap-store-optimization `try_table` / `global.set` swap gap

Date: 2026-06-21

## Question

Do the HSO-G `try_table` wrapper no-fold boundaries from `0910`-`0913` generalize to an unrelated mutable `global.set` root, or does Binaryen still treat the `try_table` as reorderable when its body cannot throw?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture shape:

- a fresh `$pair` is assigned to local `$x`;
- the constructor has a `table.size` field operand;
- an intervening `block` contains `try_table (catch_all $done)` whose body only executes `global.set $g`;
- a later `struct.set $pair 1` writes the fresh object.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-try-table-table-size-global-set.wat \
  -S -o .tmp/hso-probe-try-table-table-size-global-set.opt.wat
```

Observed Binaryen output preserves the `try_table` / `global.set`, but moves the constructor after that wrapper and removes the later `struct.set` by folding the field value into `struct.new`:

```wat
(block $done
  (try_table (catch_all $done)
    (global.set $g (i32.const 9))))
(local.set $x
  (struct.new $pair
    (i32.const 0)
    (i32.const 7)))
```

## Starshine finding

An attempted focused Starshine test for the same family initially failed as a parity gap: the current HOT HSO path leaves the later `struct.set` in the block-wrapped `try_table` / `global.set` shape. A direct CLI probe on a hand-written WAT variant also exposed local `try_table` label/lowering fragility (`hot_lower_impl_label_depth` / abort) when experimenting with root movement around the catch target.

No behavior change landed in this note. The attempted test was not committed because a green boundary test would have encoded a known required Binaryen behavior gap as accepted behavior.

## Classification

Open HSO-G parity gap / local HOT surface blocker, not a Starshine win and not an accepted semantic non-goal.

The existing `0910`-`0913` no-fold boundaries remain narrow: they cover `try_table` wrappers around ordinary table/memory stores, same-effect bulk roots, and cross-family growth roots. They do **not** justify preserving `struct.set` for an unrelated `global.set` body whose `try_table` cannot catch anything in its body.

## Reopening / implementation criteria

Reopen this when implementing broader `try_table` wrapper peeling/reordering. The fix should:

1. distinguish non-throwing `try_table` bodies from wrappers whose catch handlers can be reached;
2. preserve catch-label validity when swapping or lifting roots around the wrapper;
3. add focused positive coverage for at least the table-size/global-set shape above and the memory-size counterpart;
4. keep the existing `0910`-`0913` no-fold boundaries green; and
5. run native `src/cmd` plus a direct 10000-case `--pass heap-store-optimization` compare if behavior changes.
