# Tuple Optimization Local-Set Root Elision Fast Path

Date: 2026-06-29

## Goal

Continue the `tuple-optimization` (`TO`) O4z audit performance work on the candidate-heavy pure/drop-only source-only elision surface. The targeted owner was rewrite-time per-group local-set root handling inside the already-narrow simple source elision path.

Before this slice, source-only elision still entered `tuple_optimization_try_elide_simple_drop_only_source_group_defs(...)` for every pure/drop-only source group. Even when every lane definition was a removable root `local.set`, the helper still went through the generic payload/replace-def path and performed per-definition root-slot lookup before recording the root for later batched removal.

## Change kept

`src/passes/tuple_optimization.mbt` now has a narrower fast path for source-only groups whose definitions are all live root `local.set`s:

- `tuple_optimization_root_regions_from_use_def(...)` gets the root region(s) directly from the existing pre-rewrite use-def facts.
- `tuple_optimization_try_elide_simple_drop_only_source_local_set_roots_fast_path(...)` validates that every definition is a live one-child `LocalSet`, records those roots and regions in the cleanup plan, and avoids the generic replacement path entirely.
- Source-only elision tries this local-set-root fast path before falling back to the generic simple drop-only source helper. Local-tee definitions and non-root/local-set boundaries still fall back to the existing behavior.
- The pass now emits the aggregate timer:
  - `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source:local-set-root-fast-path`

Safety rationale: this fast path only runs after the existing drop-only elision precompute has already proven the group is in the narrow simple pure/drop-only source-elision surface. For root `local.set` definitions, the existing rewrite's intended action is just to remove those roots later; no payload clone is needed unless the definition is a `local.tee` or non-root fallback. The cleanup plan still performs the actual mutation through the existing batched root-removal path.

## Validation

Red-first:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'`
  - failed before implementation because the new `local-set-root-fast-path` timer was absent and the old `replace-defs` timer still appeared for the pure local-set fixture.

After implementation:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'`
  - passed `1/1`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - passed `56/56`.
- `moon fmt`
  - passed.
- `moon test src/passes`
  - passed `3611/3611`.
- `moon build --target native --release src/cmd`
  - passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Compare-pass:

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-local-set-root-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-local-set-root-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80/100`, raw mismatches `80`, normalized matches `0`, validation/generator/property/command failures `0`, Binaryen cache `80/0`.
  - selected profiles and `profile_case_label` counts: spill `33`, tee `12`, copy-chain `35`.
  - input effect/trap counts are all zero.
  - agent classification unchanged: this remains the known simple type-indexed pure/drop-only scalar-spelling residual surface, not a broader TO classification or final closeout.

## Candidate-heavy pass-local timings

Command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-local-set-root-fast \
  --timing-only --tuple-optimization
```

First run Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.394ms` | `0.040ms` |
| 500 | `1.111ms` | `0.212ms` |
| 1000 | `2.693ms` | `0.308ms` |
| 2000 | `5.702ms` | `0.882ms` |

Spot reruns:

- 1000 pairs: `2.106/0.335`, `2.384/0.391`, `3.267/0.330` ms.
- 2000 pairs: `5.037/0.964`, `5.252/0.962`, `5.158/0.694` ms.

The 1000-pair detail trace in `.tmp/to-passlocal-candidate-heavy-1000-20260629-local-set-root-fast/starshine.stderr.txt` shows:

- `collect-seed-groups`: `0.617ms`
- `build-query-summary`: `0.229ms`
- `link-copy-groups`: `0.187ms`
- `precompute-drop-only-elision-mask`: `0.283ms`
- `rewrite-group-defs:source-only-elide-fast-path`: `0.404ms`
- `rewrite-group-defs:elide-simple-drop-only-source:local-set-root-fast-path`: `0.336ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.213ms`
- `pass:tuple-optimization`: `2.693ms`

Compared with the previous no-scalarized-prescan detail trace, the source-only rewrite subphase dropped from about `0.607ms` to `0.404ms` at 1000 pairs and targeted root removal from `0.284ms` to `0.213ms`, but overall pass-local timing remains noisy and outside the project target.

## Interpretation

This slice removes one generic replacement/root-slot path for the common pure root-local-set elision case. It is a valid internal performance simplification, but it does not close the pass-local blocker. On the candidate-heavy fixture, TO is still several times slower than Binaryen pass-local time, especially at 1000/2000 pairs.

Remaining material owners are still analysis setup (`collect-seed-groups`, query summary, copy/result-link scans), precompute/drop-only facts, root-removal cleanup, and untraced pass overhead. Further cleanup-only skips are unlikely to be enough; the next useful slice should either reduce analysis/linking scans for no-copy source-only shapes or batch root-region cleanup more directly.

## Remaining work

- Continue performance work before final TO closeout; this slice is not enough for the pass-local target.
- Keep the dedicated `tuple-optimization-all` profile's raw-red classification narrow to the measured simple pure/drop-only scalar-spelling residual surface.
- Exact-slot/neighborhood evidence and the required final closeout ladder, including 100k lanes, remain open.
