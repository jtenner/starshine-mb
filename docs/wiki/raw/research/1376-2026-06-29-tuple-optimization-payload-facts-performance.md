# Tuple Optimization Payload-Facts Performance Slice

Date: 2026-06-29

## Summary

This slice reduced one remaining source-elision rewrite subphase for the narrow simple type-indexed pure/drop-only source-elision surface. The previous source-only fast path still re-read each group's simple block payload lanes during `rewrite-group-defs:elide-simple-drop-only-source:payload`, even though the precompute mask had already proven the same payload shape. Starshine now carries those payload lanes in precomputed drop-only elision facts and lets the source-only fast path reuse them.

This is a performance-only internal-path change. It does not broaden the accepted dedicated-profile residual classification and does not change `tuple-optimization` behavior intent.

## Red-first invariant

Updated `src/passes/tuple_optimization_wbtest.mbt` so the multi-source pure/drop-only source-elision fixture must no longer emit the per-rewrite payload timer:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*rewrite detail timers aggregate many source groups*'
```

Before implementation this failed as intended because `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source:payload` was still emitted from the rewrite loop.

## Implementation

Changed `src/passes/tuple_optimization.mbt`:

- added `HotTupleOptimizationDropOnlyElisionFacts`, containing the existing elision mask plus `payload_lanes_by_group`;
- replaced the mask-only precompute helper with `tuple_optimization_precompute_drop_only_elision_facts(...)`;
- factored `tuple_optimization_simple_drop_only_source_payload_lanes(...)` so eligibility and payload extraction happen once during precompute;
- threaded the facts through split-local preparation, source-only fast-path detection, and source-only elision rewrite;
- added an optional `precomputed_payload_lanes` argument to `tuple_optimization_try_elide_simple_drop_only_source_group_defs(...)`, avoiding the rewrite-time payload scan/timer when facts are available.

## Validation

Commands run after implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*rewrite detail timers aggregate many source groups*'
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-payload-facts --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-payload-facts --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures
moon fmt && git diff --check
```

Results:

- focused payload-facts timer test: `1 / 1` passed;
- full tuple white-box file: `54 / 54` passed;
- `moon test src/passes`: `3609 / 3609` passed;
- native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`;
- ordinary direct GenValid smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-payload-facts`: compared `1000 / 1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000 / 0`;
- bounded dedicated profile smoke `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-payload-facts`: stopped at the mismatch cap after `80 / 100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`; selected/profile labels over compared cases were spill `33`, tee `12`, copy-chain `35`;
- `moon fmt && git diff --check`: passed.

Agent classification of the dedicated raw-red lane is unchanged: this is still the known simple type-indexed pure/drop-only scalar-spelling residual surface, not new broad behavior evidence and not final closeout.

## Candidate-heavy performance

Command pattern:

```sh
for n in 100 500 1000 2000; do
  bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-payload-facts \
    --timing-only --tuple-optimization
done
```

Initial Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.386ms` | `0.037ms` |
| 500 | `1.274ms` | `0.151ms` |
| 1000 | `2.595ms` | `0.334ms` |
| 2000 | `4.710ms` | `0.704ms` |

Because those are noisy at smaller sizes, three additional spot reruns were taken:

| pairs | Starshine reruns | Binaryen reruns |
| ---: | --- | --- |
| 100 | `0.379ms`, `0.337ms`, `0.343ms` | `0.034ms`, `0.034ms`, `0.034ms` |
| 500 | `1.174ms`, `1.252ms`, `1.179ms` | `0.146ms`, `0.137ms`, `0.137ms` |
| 1000 | `2.205ms`, `2.444ms`, `2.187ms` | `0.277ms`, `0.325ms`, `0.409ms` |
| 2000 | `4.475ms`, `5.195ms`, `5.007ms` | `0.605ms`, `0.619ms`, `0.706ms` |

The 1000-pair detail trace confirms the intended attribution change:

- `precompute-drop-only-elision-mask`: `0.269ms` (up from `0.189ms`, now also carries payload facts)
- `rewrite-group-defs:source-only-elide-fast-path`: `0.319ms` (down from `0.535ms`)
- `rewrite-group-defs:elide-simple-drop-only-source:payload`: absent from the rewrite trace
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.254ms`
- `rewrite-group-defs`: `0.351ms` (down from `0.562ms`)
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.192ms`
- `cleanup-post-rewrite`: `0.375ms`
- total `pass:tuple-optimization`: `2.595ms` on the initial 1000-pair run, with spot reruns down to `2.187ms` / `2.205ms`.

This reduces the rewrite-local payload owner but does not close the pass-local gap. TO remains outside the project target by a wide margin.

## Remaining work

TO remains open. This slice does not satisfy final pass closeout because:

- candidate-heavy pass-local time is still much slower than Binaryen;
- analysis setup and cleanup/root-removal still dominate large parts of the candidate-heavy trace;
- the dedicated profile remains raw-red under the narrow scalar-spelling residual classification;
- exact-slot/neighborhood evidence is still missing;
- the required final closeout ladder and 100k lanes have not been run.

Recommended next performance directions:

1. Reduce cleanup cost for pure/drop-only elision, especially targeted root-region removal and scalarized-local cleanup pre-scans.
2. Investigate analysis setup cost (`collect-seed-groups`, query summary, copy/link scans) on no-copy candidate-heavy fixtures.
3. Revisit a direct batched source-elision rewrite path only if it avoids the per-root splice regression documented in `1368` and is protected by a red-first shape/timer invariant.
