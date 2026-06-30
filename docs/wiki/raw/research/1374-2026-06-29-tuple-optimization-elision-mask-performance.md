# Tuple Optimization Elision Mask Performance Slice

Date: 2026-06-29

## Summary

This slice reduced candidate-heavy `tuple-optimization` pass-local time by precomputing the narrow pure/drop-only source-elision decision once per rewrite pass. Before this change, the same simple type-indexed pure/drop-only source groups were scanned during split-local preparation and then scanned again during source rewrite. The implementation now builds a `precompute-drop-only-elision-mask` after collecting rewrite order, uses the mask to skip split-local decision work for groups that will be elided, and passes the same decision into rewrite so the hot source-rewrite loop no longer emits or reruns the per-group `can-elide` timer.

This is a performance-only internal-path change for the already-narrow pure/drop-only source-elision family. It does not broaden the accepted residual parity surface.

## Red-first invariant

Updated `src/passes/tuple_optimization_wbtest.mbt` so the perf-detail fixture requires the new `detail:tuple-optimization:precompute-drop-only-elision-mask` timer and rejects the old per-rewrite `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source:can-elide` timer on the pure/drop-only fixture.

Initial command:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'
```

Initial result: failed as intended. The trace still had `ensure-split-locals` and the old `rewrite-group-defs:elide-simple-drop-only-source:can-elide` timer, but no `precompute-drop-only-elision-mask` timer.

## Implementation

Changed `src/passes/tuple_optimization.mbt`:

- added `tuple_optimization_precompute_drop_only_elision_mask(...)` over the collected rewrite order;
- threaded the resulting bitset into `tuple_optimization_ensure_split_locals(...)`;
- made split-local preparation immediately reuse original lane locals for precomputed elision groups;
- removed the duplicate `tuple_optimization_can_elide_simple_drop_only_source_group(...)` call from `tuple_optimization_group_needs_dedicated_split_locals(...)`;
- made `tuple_optimization_rewrite_group_defs(...)` take the precomputed `elide_simple_drop_only_source` decision and only enter the simple drop-only elision helper for groups marked by the mask;
- removed the old per-group `can-elide` rewrite sub-timer.

## Validation

Commands run after implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-elide-mask --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-elide-mask --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures
```

Results:

- focused perf-detail tuple test: `1 / 1` passed;
- full tuple white-box file: `54 / 54` passed;
- `moon test src/passes`: `3609 / 3609` passed;
- native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`;
- ordinary direct GenValid smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-elide-mask`: compared `1000 / 1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000 / 0`;
- bounded dedicated profile smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-elide-mask`: stopped at the mismatch cap after `80 / 100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`; selected/profile labels over compared cases were spill `33`, tee `12`, copy-chain `35`.

The dedicated profile classification is unchanged: these are the known simple type-indexed pure/drop-only scalar-spelling residuals, not new behavior evidence and not final closeout.

## Candidate-heavy performance

Command pattern:

```sh
for n in 100 500 1000 2000; do
  bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-elide-mask \
    --timing-only --tuple-optimization
done
```

Final Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.408ms` | `0.038ms` |
| 500 | `2.285ms` | `0.152ms` |
| 1000 | `7.097ms` | `0.292ms` |
| 2000 | `21.286ms` | `0.618ms` |

This is a kept improvement over the previous targeted-root-removal / fast-root-replace timings (`0.454ms / 0.032ms`, `2.907ms / 0.152ms`, `8.606ms / 0.345ms`, `30.561ms / 0.880ms`) but still far outside the project pass-local target.

The 1000-pair detail trace now shows:

- `build-rewrite-mask`: `0.936ms`
- `precompute-drop-only-elision-mask`: `0.214ms`
- `ensure-split-locals`: `0.019ms`
- `rewrite-group-defs`: `4.175ms`
- `rewrite-group-defs:source`: `4.073ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `0.685ms`
- `rewrite-group-defs:elide-simple-drop-only-source:payload`: `0.197ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.333ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.200ms`
- `cleanup-post-rewrite`: `0.398ms`

The previous `ensure-split-locals` owner is largely eliminated for this fixture. Remaining owners are still TO-owned source rewrite, rewrite-mask construction, and cleanup/root-removal overhead.

## Remaining work

TO remains open. This slice does not satisfy final pass closeout because:

- pass-local time is still much slower than Binaryen on candidate-heavy fixtures;
- the dedicated profile remains raw-red under the known scalar-spelling residual classification;
- exact-slot/neighborhood evidence is still missing;
- the required final closeout ladder and 100k lanes have not been run.

Recommended next performance directions:

1. Reduce source rewrite itself: avoid repeated payload extraction/root-slot checks, or add a more direct batched root-removal/source-elision path for pure/drop-only source groups.
2. Reduce `build-rewrite-mask` scans now that the candidate-heavy fixture spends nearly 1ms there at 1000 groups.
3. Keep any performance-only change covered by a red-first timer/shape invariant and rerun direct `--pass tuple-optimization` smoke after implementation.
