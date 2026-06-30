# Tuple Optimization Source Fast Path Performance Slice

Date: 2026-06-29

## Summary

This slice reduced candidate-heavy `tuple-optimization` pass-local time by adding two performance-only fast paths for the narrow simple type-indexed pure/drop-only source-elision family:

- source-only elision rewrite now uses one bulk source/elision timer path and avoids the old per-group source/copy-consumer scans when every rewritten group is a source group already marked by the precomputed drop-only elision mask;
- no-copy rewrite-mask construction now skips copy-family suppression scans and uses the base `tuple_optimization_group_should_rewrite(...)` predicate after the existing nested-root-wrapper global guard proves no group has that unsupported wrapper shape.

This is a performance-only internal-path change. It does not broaden the accepted residual parity surface and does not change the current dedicated-profile mismatch classification.

## Red-first invariants

Updated `src/passes/tuple_optimization_wbtest.mbt` with two timer/shape invariants:

1. the multi-source pure/drop-only fixture must emit `detail:tuple-optimization:rewrite-group-defs:source-only-elide-fast-path` while still aggregating the source/elision timers to one emitted line;
2. the perf-detail pure/drop-only fixture must emit `detail:tuple-optimization:build-rewrite-mask:no-copy-fast-path`.

Initial focused commands failed as intended before implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*rewrite detail timers aggregate many source groups*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'
```

The first failure lacked `source-only-elide-fast-path`; the second lacked `build-rewrite-mask:no-copy-fast-path`.

## Implementation

Changed `src/passes/tuple_optimization.mbt`:

- added `tuple_optimization_rewrite_order_is_source_only_elide_fast_path(...)`;
- added `tuple_optimization_rewrite_source_only_elide_fast_path(...)`, which directly runs the simple drop-only source elision helper for source-only rewrite orders and accumulates source/elision timing once instead of starting source timers around every group;
- added `tuple_optimization_groups_have_copy_source(...)` and `tuple_optimization_build_no_copy_group_rewrite_mask(...)`;
- threaded `ctx.perf` into `tuple_optimization_build_group_rewrite_mask(...)` so the no-copy fast path is visible in perf traces;
- removed the redundant per-group nested-root-wrapper check from `tuple_optimization_group_should_rewrite_in_func(...)` because `tuple_optimization_build_group_rewrite_mask(...)` already performs the all-groups nested-root-wrapper guard before asking for per-group decisions.

## Validation

Commands run after implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*rewrite detail timers aggregate many source groups*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-source-fast-mask --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-source-fast-mask --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures
moon fmt && git diff --check
```

Results:

- focused source-fast timer test: `1 / 1` passed;
- focused no-copy-mask timer test: `1 / 1` passed;
- full tuple white-box file: `54 / 54` passed;
- `moon test src/passes`: `3609 / 3609` passed;
- native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`;
- ordinary direct GenValid smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-source-fast-mask`: compared `1000 / 1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000 / 0`;
- bounded dedicated profile smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-source-fast-mask`: stopped at the mismatch cap after `80 / 100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`; selected/profile labels over compared cases were spill `33`, tee `12`, copy-chain `35`;
- `moon fmt && git diff --check`: passed.

Agent classification of the dedicated raw-red lane is unchanged: this remains the known simple type-indexed pure/drop-only scalar-spelling residual surface, not new broad behavior evidence and not final closeout.

## Candidate-heavy performance

Command pattern:

```sh
for n in 100 500 1000 2000; do
  bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-source-fast-mask \
    --timing-only --tuple-optimization
done
```

Final Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.344ms` | `0.052ms` |
| 500 | `1.183ms` | `0.148ms` |
| 1000 | `2.605ms` | `0.280ms` |
| 2000 | `4.498ms` | `0.608ms` |

This is a kept improvement over the prior elision-mask timings (`0.408ms / 0.038ms`, `2.285ms / 0.152ms`, `7.097ms / 0.292ms`, `21.286ms / 0.618ms`), especially at larger group counts, but TO still misses the pass-local target by a wide margin.

The 1000-pair detail trace now shows:

- `collect-seed-groups`: `0.338ms`
- `build-query-summary`: `0.142ms`
- `link-copy-groups`: `0.154ms`
- `link-result-block-copy-groups`: `0.078ms`
- `build-rewrite-mask:no-copy-fast-path`: `0.003ms`
- `build-rewrite-mask`: `0.022ms`
- `precompute-drop-only-elision-mask`: `0.189ms`
- `ensure-split-locals`: `0.021ms`
- `rewrite-group-defs:source-only-elide-fast-path`: `0.535ms`
- `rewrite-group-defs:source`: `0.535ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `0.535ms`
- `rewrite-group-defs:elide-simple-drop-only-source:payload`: `0.234ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.210ms`
- `rewrite-group-defs`: `0.562ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.295ms`
- `cleanup-post-rewrite`: `0.561ms`

The previous rewrite-mask owner is largely eliminated for no-copy candidate-heavy fixtures. Remaining owners are source-elision payload/replacement work, cleanup/root-removal and scalarized-local cleanup scans, and analysis/seed/query setup.

## Remaining work

TO remains open. This slice does not satisfy final pass closeout because:

- candidate-heavy pass-local time is still substantially slower than Binaryen (`2.605ms` vs `0.280ms` at 1000 pairs and `4.498ms` vs `0.608ms` at 2000 pairs);
- the dedicated profile remains raw-red under the narrow scalar-spelling residual classification;
- exact-slot/neighborhood evidence is still missing;
- the required final closeout ladder and 100k lanes have not been run.

Recommended next performance directions:

1. Reduce source-elision helper work by precomputing or caching simple block payload lanes and removable root facts, or by adding a more direct batched source-elision rewrite path.
2. Reduce cleanup cost for pure/drop-only elision, especially targeted root-region removal and scalarized-local cleanup pre-scans.
3. Investigate analysis setup cost (`collect-seed-groups`, query summary, copy/link scans) on no-copy candidate-heavy fixtures without weakening behavior parity for copy-chain/tee surfaces.
