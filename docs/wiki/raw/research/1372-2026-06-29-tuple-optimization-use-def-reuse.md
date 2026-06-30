# Tuple Optimization Rewrite Use-Def Reuse

Date: 2026-06-29

## Question

Can `tuple-optimization` avoid rebuilding use-def immediately before rewrite by reusing the same analysis-valid use-def that seeded group collection and query analysis?

## Change Kept

The kept implementation threads the pass-required `HotUseDef` from `tuple_optimization_run(...)` into `tuple_optimization_rewrite_good_components(...)` instead of rebuilding it inside the rewrite entry point. No mutation occurs between `pass_require_use_def(...)`, tuple group analysis, rewrite-mask construction, and the first rewrite mutation, so the existing analysis use-def is still the correct pre-rewrite snapshot. The rewrite logic already used one pre-mutation use-def throughout all mutations; this change only removes the duplicate construction.

This is a performance-only internal change. It does not broaden the supported transform surface or change the narrow pure/drop-only elision contract.

## Red-First Coverage

Added `tuple-optimization reuses analysis use-def during rewrite` in `src/passes/tuple_optimization_wbtest.mbt`.

The test first failed because the trace still emitted `perf:timer name=detail:tuple-optimization:rewrite-use-def-build`. After the implementation, the same fixture still emits `build-rewrite-mask` but no longer emits the duplicate rewrite use-def timer.

## Validation

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*reuses analysis use-def*'` — failed before implementation as intended, then passed `1/1`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — passed `54/54`.
- `moon test src/passes` — passed `3609/3609`.
- `moon build --target native --release src/cmd` — passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-use-def-reuse --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-use-def-reuse --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures` — stopped at the known raw-mismatch cap after `80/100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. This remains the documented narrow scalar-spelling residual surface; this slice did not broaden the classification.

## Candidate-Heavy Performance

Command pattern:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-use-def-reuse \
  --timing-only --tuple-optimization
```

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 0.505ms | 0.055ms |
| 500 | 4.132ms | 0.156ms |
| 1000 | 14.528ms | 0.330ms |
| 2000 | 49.278ms | 0.647ms |

Compared with the previous batched-root-removal slice (`0.845ms`, `7.000ms`, `19.080ms`, `70.095ms` for 100/500/1000/2000), this is a kept improvement at every measured size, but TO remains far outside the pass-local target.

1000-pair detail totals after this slice:

- `build-rewrite-mask`: `0.815ms`
- `ensure-split-locals`: `2.018ms`
- `rewrite-group-defs`: `4.917ms`
- `rewrite-group-defs:source`: `4.797ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `1.412ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.593ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots`: `5.223ms`
- `cleanup-post-rewrite`: `5.470ms`

The former `rewrite-use-def-build` detail timer is gone. The current 1000-pair timing still leaves real TO-owned costs in cleanup root removal, source rewrite, split-local preparation, and rewrite-mask construction.

## Remaining Work

- Continue TO performance work. The highest current owner is the batched root-removal cleanup traversal (`~5.2ms` at 1000 pairs), followed by source rewrite (`~4.8ms`), split-local preparation (`~2.0ms`), and rewrite-mask construction (`~0.8ms`).
- The dedicated `tuple-optimization-all` profile remains raw-red in the known narrow scalar-spelling family. Do not broaden the Starshine-win classification without fresh diff inspection and measured evidence.
- Final TO audit closeout remains incomplete: exact-slot/neighborhood evidence, refreshed larger general/dedicated lanes, the full required closeout ladder, and 100k lane(s) are still pending.
