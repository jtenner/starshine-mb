# 1574 - `merge-locals` Binaryen v131 parity closeout

## Scope

Close Starshine's active-partial `merge-locals` implementation against Binaryen `version_131`, add family-owned GenValid generation, schedule the O4z slot after `heap2local`, and restore pass-local performance.

## Source contract

Reviewed `version_131/src/passes/MergeLocals.cpp`, `src/ir/local-graph.h`, and `test/lit/passes/merge-locals.wast`. The complete upstream algorithm:

1. instruments each `local.set` or `local.tee` copy with a temporary source-local tee;
2. builds an eager LocalGraph and set influences;
3. prefers source-use retargeting to the copy destination when every influenced get has one source and an exact target-local type;
4. otherwise tries destination-use retargeting to the source when the source remains live;
5. rebuilds the graph and rolls back an entire sibling influence set when the new target has another reaching write; and
6. removes all temporary tees.

## Implementation

- Converted `merge-locals` to a HOT pass backed by Starshine's CFG and `HotLocalGraph`.
- Added exact v131 temporary-tee instrumentation, both orientations, exact local type checks, post-graph verification, and sibling rollback.
- Added `hot_local_node_id_set(...)` as the validated public HOT mutation primitive for local get/set/tee identity changes.
- Added a linear raw LocalGraph-equivalent fast path for straight-line functions. It snapshots virtual source writes and actual copy writes, computes influences once, applies candidates against the immutable snapshot, builds one post-source table, and rolls back failed candidates. Structured control falls back to the full CFG/HOT implementation.
- Added a raw no-candidate bypass so direct execution does not introduce unrelated lift/lower representation drift.
- Scheduled `merge-locals` exactly between `heap2local` and `optimize-casts` in `optimize` and `shrink`.

## Tests and generation

Focused pass tests cover:

- forward source-to-destination retargeting;
- reverse destination-to-source retargeting when the source has a merge influence;
- cross-`if` graph influence;
- `local.tee` copy candidates;
- destination-write rollback;
- control-boundary invalidation; and
- exact O4z slot placement.

Added seven leaf GenValid profiles plus `merge-locals-all`:

- `merge-locals-forward`
- `merge-locals-reverse`
- `merge-locals-control` (rotates block, if, and loop cases)
- `merge-locals-tee`
- `merge-locals-merge-boundary`
- `merge-locals-type-boundary` (GC strict subtype mismatch)
- `merge-locals-rollback`

Manifest tests prove deterministic composite selection and generator tests prove every leaf emits a valid copy-shaped module.

## Signoff

Fresh native release binary: `_build/native/release/build/cmd/cmd.exe`.

- Regular GenValid: `100000/100000` normalized matches, zero mismatches/failures.
- Dedicated `merge-locals-all`: `10000/10000` normalized matches, all seven leaves selected, zero mismatches/failures.
- Random all profiles: `10000/10000` normalized matches, zero mismatches/failures.
- Immediate scheduled neighborhood `heap2local -> merge-locals -> optimize-casts`: `10000/10000` dedicated-profile normalized matches, zero mismatches/failures.
- wasm-smith: `9956` compared from `10000`; `9955` normalized matches, `44` Binaryen/tool command failures, and one raw mismatch at case `9332`.

The wasm-smith mismatch is not pass-owned: the input has no local copy candidates, and Starshine's no-pass output is byte-identical to its `--merge-locals` output (SHA-256 `548cc8e99c3e5a413344aaa0d135945fa2e524899b8b1ce6c3c7fbcd3bfff8fb`). Binaryen's reader/writer removes one unreachable stack-debris drop while Starshine's codec preserves it. Keep this under `[TOOL]001`; it does not reopen a merge-locals transform family.

A broader six-pass probe through `local-subtyping -> coalesce-locals -> local-cse` exposed downstream local-numbering shape mismatches. On a reduced representative, adding or removing `merge-locals` changes neither tool's output byte: Starshine is identical with/without the pass, and Binaryen is identical with/without it. This is therefore a pre-existing downstream neighborhood parity gap, not evidence against the exact slot or merge-locals behavior; no Starshine-win claim is made for that shape.

## Performance

Representative copy-heavy workload: 200 functions, 50 copy/use groups per function, 118 KiB wasm; seven measured iterations after two warmups.

- Binaryen v131 median whole command: `10.819 ms`.
- Starshine median whole command: `13.787 ms`.
- Ratio: `1.27x` Binaryen.

The raw immutable-snapshot path replaced an initial `10.8x` HOT-only gap and meets the requested near-1x target while structured functions retain full graph parity.

## Conclusion

`merge-locals` is closed for v0.1.0 at Binaryen-v131 behavior parity, scheduled in its O4z neighborhood, and performance-qualified. The only external-lane raw mismatch is a proven no-pass codec baseline difference owned by tooling, not the pass.
