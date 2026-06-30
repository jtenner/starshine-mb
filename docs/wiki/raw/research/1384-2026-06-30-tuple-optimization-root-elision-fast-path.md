# Tuple Optimization Simple Root-Elision Fast Path

Date: 2026-06-30

## Context

The previous `tuple-optimization` candidate-heavy performance slice showed that the no-copy/source-only fixture still paid the full TO analysis/rewrite pipeline even when every seed group was a simple pure/drop-only `i32, i64` block spill whose lane locals are only read by direct `drop`s. The kept no-copy-payload slice measured first-run pass-local Starshine/Binaryen timings of `0.349/0.046`, `1.114/0.238`, `2.242/0.311`, and `4.507/0.673` ms at 100/500/1000/2000 pairs, with spot reruns at 1000 pairs `2.111/0.287`, `1.980/0.302` and at 2000 pairs `4.290/0.658`, `4.196/0.709`.

The 1000-pair detail trace attributed remaining work to `collect-seed-groups` (`0.612ms`), `build-query-summary` (`0.443ms`), drop-only elision precompute (`0.263ms`), source-only rewrite (`0.298ms`), targeted root cleanup (`0.201ms`), cleanup (`0.229ms`), and untraced pass overhead.

## Change

Added a narrow direct fast path for groups that are all:

- source groups, not copy groups;
- no-host `local.set` lane definitions;
- simple `i32, i64` type-indexed block producers with exactly one simple payload root per lane;
- single-write lane locals;
- lane locals read only by live direct `local.get` -> `drop` uses.

When every collected seed group satisfies those gates, TO skips the full query-summary, copy-linking, rewrite-mask, drop-only precompute, split-local, and generic rewrite phases. It directly records the source `local.set` roots as removable and runs the existing post-rewrite cleanup. The fast path is deliberately narrower than the already-classified pure/drop-only Starshine-win residual: tees, copy groups, non-`i32/i64` carriers, non-drop uses, missing reads, multi-write locals, and non-exact block payload roots all fall back to the existing full analysis path.

A small exact-root payload helper was also added so simple block payload checks avoid the generic trailing-payload splitter when the block body is exactly the lane payload. This helper is used by the direct fast-path gate and by the existing drop-only precompute fallback.

## Red-first guard

`src/passes/tuple_optimization_wbtest.mbt` changed the pure/drop-only perf-detail fixture to require:

- `detail:tuple-optimization:simple-drop-only-root-elision-fast-path` is emitted;
- `build-query-summary`, copy-linking, rewrite-mask, drop-only precompute, and generic `rewrite-group-defs` timers are absent.

Before implementation, that focused test failed because the generic analysis/rewrite timers were still emitted and the new fast-path timer was absent. After implementation, the tuple white-box file passed `56/56`.

The existing aggregate rewrite-timer fixture was adjusted to use direct-dropped `local.tee` host lanes so it intentionally stays on the full-analysis path and continues to cover aggregate source/rewrite timers.

## Validation

Commands run:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'`
  - failed before implementation as expected;
  - passed after implementation.
- `moon fmt && moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - passed, `56 / 56`.
- `moon test src/passes && moon build --target native --release src/cmd`
  - pass tests passed, `3611 / 3611`;
  - native build passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-root-elision-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000 / 1000`;
  - normalized matches `1000`;
  - validation/generator/property/command failures `0`;
  - mismatches `0`;
  - Binaryen cache hits/misses `1000 / 0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-root-elision-fast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at mismatch cap after `80 / 100` compared;
  - raw mismatches `80`;
  - validation/generator/property/command failures `0`;
  - selected/profile labels: spill `33`, tee `12`, copy-chain `35`;
  - input effect/trap facts all false across the 80 cases;
  - Binaryen cache hits/misses `80 / 0`.

## Candidate-heavy timing

Command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-root-elision-fast \
  --timing-only --tuple-optimization
```

First-run pass-local Starshine/Binaryen timings:

| pairs | Starshine ms | Binaryen ms |
| ---: | ---: | ---: |
| 100 | 0.165 | 0.040 |
| 500 | 0.676 | 0.192 |
| 1000 | 1.522 | 0.316 |
| 2000 | 2.933 | 0.762 |

The 1000-pair detail trace at `.tmp/to-passlocal-candidate-heavy-1000-20260630-root-elision-fast/starshine.stderr.txt` reports:

- `collect-seed-groups`: `0.468ms`
- `simple-drop-only-root-elision-fast-path`: `0.723ms`
- targeted removable-root cleanup: `0.220ms`
- remove-elided roots total: `0.225ms`
- `pass:tuple-optimization`: `1.522ms`

This is a clear improvement over the prior no-copy-payload first-run timings (`2.242ms` at 1000 and `4.507ms` at 2000) and spot reruns (`1.980-2.111ms` at 1000 and `4.196-4.290ms` at 2000), but it remains outside the pass-local target: Starshine is still roughly `4.8x` Binaryen at 1000 pairs and `3.8x` Binaryen at 2000 pairs on this fixture.

## Interpretation

The direct fast path is safe because a simple pure source `local.set` whose only subsequent observations are direct drops may be removed without changing observable behavior: the later `local.get` values are still dropped, and `local.get` itself has no trapping/effect behavior. The gates reject shapes where the source write could be observed, where tee results must be preserved, or where copy/host semantics require the full TO component analysis.

Remaining candidate-heavy owners after this slice are seed collection, the direct fast-path's own validation/root-region lookup, targeted root cleanup, and untraced pass overhead. Query-summary construction, copy-linking, rewrite-mask building, drop-only precompute, split-local preparation, and generic rewrite are no longer owners for this exact simple root-elision fixture.

This slice does not broaden the dedicated-profile residual classification. The bounded dedicated profile remains raw-red in the known simple scalar-spelling family; broader type/lane-count/effect/non-drop surfaces and final full closeout remain open.
