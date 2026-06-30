# 1383 - 2026-06-30 - Tuple optimization no-copy-payload fast path

## Question

Can `tuple-optimization` avoid the exact-copy group linker on source-only pure/drop-only candidate-heavy fixtures that have no block payload lane shaped like a copy from existing tuple-lane locals?

## Change

Starshine now records a conservative `has_copy_payload_candidate` fact on seed groups during seed collection. The fact is true only for block seed groups whose trailing payload roots can cheaply be recognized as lane-count many `local.get` or `local.tee(local.get)` payload lanes. When no seed group has that fact, `tuple_optimization_analyze_with_groups(...)` skips `tuple_optimization_link_copy_groups(...)` and emits:

```text
perf:timer name=detail:tuple-optimization:link-copy-groups:no-copy-payload-fast-path
```

instead of the generic `detail:tuple-optimization:link-copy-groups` timer.

The cheap precheck deliberately does not call the full `hot_region_split_trailing_payload_roots(...)` splitter. A first implementation did, and the extra seed-collection work could offset the skipped linker. The kept version walks only the block body's trailing root slots, accumulates result arity up to the seed lane count, and accepts only roots already accepted by `tuple_optimization_try_payload_source_read(...)`. This can produce false positives only by still running the normal linker; false negatives would be unsafe, so the precheck mirrors the linker's required source-read payload shape for exact block copy groups.

## Red-first test

Updated `src/passes/tuple_optimization_wbtest.mbt` in the existing pure/drop-only performance detail fixture. Before implementation, the focused test failed because the trace still contained the generic link-copy timer and lacked the new fast-path timer:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'
```

Failure evidence included:

```text
perf:timer name=detail:tuple-optimization:link-copy-groups elapsed_us=0 total_us=0
```

After implementation, the same focused test passed and the fixture now requires the fast-path timer while rejecting the generic timer.

## Safety rationale

`tuple_optimization_link_copy_groups(...)` can add an exact copy edge only after:

1. the seed group's producer is a `block`,
2. the block's trailing payload has the same lane count as the seed group,
3. every payload lane is a `local.get` or `local.tee(local.get)` accepted by `tuple_optimization_try_payload_source_read(...)`, and
4. those source locals resolve through current local-group facts to one source tuple group.

The new precheck only proves whether any seed group can satisfy the required payload-source-read surface. If none can, the linker cannot add an exact copy group, so `copy_read_nodes` and `copy_write_nodes` should remain empty for that linker. Result-block and scalar-forward linkers still run or skip under their own independent query-summary fast paths. If the precheck sees a possible source-read payload, Starshine still runs the existing full linker, so broader copy-chain behavior remains unchanged.

## Validation

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'` failed before implementation and passed after implementation.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` passed `56/56`.
- `moon test src/passes` passed `3611/3611`.
- `moon build --target native --release src/cmd` passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct GenValid smoke:
  - command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-copy-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - result: compared `1000/1000`, normalized `1000`, zero mismatches, zero validation/generator/property/command failures, Binaryen cache `1000/0`.
- Dedicated bounded profile smoke:
  - command: `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-copy-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - result: stopped at mismatch cap after `80/100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification remains the known narrow simple type-indexed pure/drop-only scalar-spelling residual surface.

## Pass-local performance evidence

Candidate-heavy timing command:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-no-copy-fast-cheap --timing-only --tuple-optimization
```

First run after the cheap precheck:

| pairs | Starshine pass ms | Binaryen pass ms |
|---:|---:|---:|
| 100 | 0.349 | 0.046 |
| 500 | 1.114 | 0.238 |
| 1000 | 2.242 | 0.311 |
| 2000 | 4.507 | 0.673 |

Spot reruns:

| pairs | Starshine pass ms | Binaryen pass ms |
|---:|---:|---:|
| 1000 | 2.111 | 0.287 |
| 1000 | 1.980 | 0.302 |
| 2000 | 4.290 | 0.658 |
| 2000 | 4.196 | 0.709 |

Representative 1000-pair detail trace from `.tmp/to-passlocal-candidate-heavy-1000-20260630-no-copy-fast-cheap/starshine.stderr.txt`:

- `collect-seed-groups`: `0.612ms`
- `build-query-summary`: `0.443ms`
- `link-copy-groups:no-copy-payload-fast-path`: `0.000ms`
- `link-result-block-copy-groups:no-single-result-block-fast-path`: `0.000ms`
- `link-scalar-forward-copy-groups:no-scalar-forward-fast-path`: `0.001ms`
- `precompute-drop-only-elision-mask`: `0.263ms`
- source-only rewrite: `0.298ms`
- targeted root cleanup: `0.201ms`
- `cleanup-post-rewrite`: `0.229ms`
- `pass:tuple-optimization`: `2.242ms`

Interpretation: the exact-copy linker is no longer a candidate-heavy owner for no-copy/source-only fixtures. The retained change improves the best/spot 1000-pair band and keeps 2000-pair timings near the previous best band, but TO remains outside the pass-local target. Remaining owners are seed collection, query-summary construction, drop-only elision precompute, rewrite/root cleanup, and untraced pass overhead.

## Open follow-up

- Candidate-heavy performance is still an audit closeout blocker.
- Do not broaden the dedicated-profile residual classification from this performance-only fast path.
- Future work should target seed/query-summary scans or remaining rewrite/cleanup owners with red-first timer invariants.
