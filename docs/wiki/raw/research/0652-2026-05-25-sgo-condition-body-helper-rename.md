# SGO condition body helper rename

## Scope

Refactor-only `[SGO]003O2` condition matcher naming slice for `simplify-globals-optimizing`.

This slice renames the shared helper that combines a block/no-catch-`try_table` body extraction with a precomputed external-condition `if` index. The old name was tied to one call family (`external_pure_read_with_index`) even though the helper is used by direct and reverse external-condition readers and by both direct-set and `if return; set` tail counters.

## Change

- Renamed `sgo_count_block_condition_external_pure_read_with_index(...)` to `sgo_count_block_or_try_condition_body_with_if_index(...)`.
- Updated the four direct/reverse external-condition reader call sites to use the clearer name.

The new name makes the wrapper contract explicit:

- the wrapper source may be a `block` or a no-catch `try_table`;
- the condition `if` index is supplied by the caller;
- the helper only exposes the body plus index to a counting callback.

## Behavior

No optimizer behavior changed.

Preserved boundaries:

- accepted external-condition shapes are unchanged;
- direct and reverse `if` index finders are unchanged;
- same-global checks are still performed by the existing tail/body counters;
- catch-bearing `try_table` remains rejected by `sgo_block_or_no_catch_try_table_body(...)`;
- guard-tail dispatch for direct-set and `if return; set` tails is unchanged.

## Validation

- `moon test src/passes` — `1600/1600` passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-condition-body-helper-rename-10k` — `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `25` Binaryen/tool command failures.

## Status

`[SGO]003O2` is complete. `[SGO]003O` remains open for `[SGO]003O3` and `[SGO]003O4`. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
