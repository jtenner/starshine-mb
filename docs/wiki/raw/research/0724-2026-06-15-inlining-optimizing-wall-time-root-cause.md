# `inlining-optimizing` wall-time root cause and reachability fix

Date: 2026-06-15

## Question

Why did Starshine's `inlining-optimizing` pass spin for minutes during self-optimization, and which subphase owned the time?

## Artifact and commands

Primary replay artifact:

- input: `_build/wasm/debug/build/cmd/cmd.wasm`
- output: `tests/node/dist/starshine-self-optimized-wasi.wasm`
- command shape: `_build/native/release/build/cmd/cmd.exe --tracing pass --debug-serial-passes --optimize -O4z --out tests/node/dist/starshine-self-optimized-wasi.wasm _build/wasm/debug/build/cmd/cmd.wasm`

Instrumented logs:

- before reachability cache: `.tmp/self-opt-inlining-detail.stderr`
- after reachability cache: `.tmp/self-opt-inlining-reach.stderr`

Focused compare after the fix:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass inlining-optimizing --normalize drop-consts --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-inlining-optimizing-reachability-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `7606/10000` compared, `3793` normalized matches, `3813` compare-normalized matches, `0` mismatches, `0` validation failures, `20` command failures.

## Root cause

The severe wall-time bug was in `inl_original_reachable_private_cycle_funcs(...)`, specifically repeated recursive reachability queries over the same function call graph.

Before the fix, that helper repeatedly called `inl_graph_reaches(graph, a, b, Array::make(total, false))` from root-reachability, SCC membership, and Starshine-only unreachable-cycle prediction paths. On the self-optimization debug CLI artifact this meant repeated fresh `seen` allocation and graph traversal across thousands of functions. The artifact entered `inlining-optimizing` with `6556` defined functions, then iterated through `4701`, `3605`, `3309`, `3278`, and `3277` defined-function states. Even when later iterations touched only a handful of functions, each iteration still rescanned reachability for the whole module.

The safe fix is to build an iteration-local transitive reachability table once from the direct-call graph (`inl_build_graph_reachability`) and answer all local reachability questions with `inl_reachability_reaches`. This preserves the old cycle-only self-reachability semantics: a function reaches itself only if a non-empty path returns to it, not merely because `start == target`.

## Timing attribution before the fix

From `.tmp/self-opt-inlining-detail.stderr`:

| Timer | Total |
| --- | ---: |
| `pass:inlining-optimizing` | `690.716s` |
| `detail:inlining:iteration` | `471.064s` |
| `detail:inlining:once:original-reachable-private-cycle-funcs` | `449.151s` |
| `detail:inlining:initial-original-reachable-private-cycle-funcs` | `219.543s` |
| `detail:inlining:once:preserve-root-cycle-check` | `11.433s` |
| `detail:inlining:once:collapse-unreachable-roots` | `8.479s` |
| `detail:inlining:once:rewrite-all-calls` | `0.590s` |
| `detail:inlining:once:remove-dead-inlined-helpers` | `0.448s` |
| `detail:inlining:once:build-function-infos` | `0.267s` |
| `detail:inlining:once:prepare-multivalue-block-types` | `0.254s` |
| `detail:inlining:once:nested-cleanup` | effectively `0s` |

Iteration counts and touched counts before the fix:

- iteration `0`: `6556` defined funcs, `1933` touched, `2270` inlined-from;
- iteration `1`: `4701` defined funcs, `465` touched, `1122` inlined-from;
- iteration `2`: `3605` defined funcs, `70` touched, `295` inlined-from;
- iteration `3`: `3309` defined funcs, `6` touched, `31` inlined-from;
- iteration `4`: `3278` defined funcs, `1` touched, `1` inlined-from;
- iteration `5`: `3277` defined funcs, no changes.

Nested cleanup was not the culprit. It was skipped every changing iteration by the existing large-module guard: `defined > 80`.

## Timing attribution after the fix

From `.tmp/self-opt-inlining-reach.stderr`:

| Timer | Total |
| --- | ---: |
| `pass:inlining-optimizing` | `41.091s` |
| `detail:inlining:iteration` | `37.666s` |
| `detail:inlining:once:original-reachable-private-cycle-funcs` | `14.592s` |
| `detail:inlining:once:preserve-root-cycle-check` | `12.274s` |
| `detail:inlining:once:collapse-unreachable-roots` | `8.835s` |
| `detail:inlining:initial-original-reachable-private-cycle-funcs` | `3.321s` |
| `detail:inlining:once:rewrite-all-calls` | `0.580s` |
| `detail:inlining:once:remove-dead-inlined-helpers` | `0.434s` |
| `detail:inlining:once:build-function-infos` | `0.258s` |
| `detail:inlining:once:prepare-multivalue-block-types` | `0.250s` |
| `detail:inlining:once:nested-cleanup` | effectively `0s` |

The pass-local improvement is about `690.716s -> 41.091s` (`~16.8x` faster). The original graph helper dropped from `219.543s` initial plus `449.151s` iterative total to `3.321s` initial plus `14.592s` iterative total.

## Remaining hotspots

The severe multi-minute spin is fixed, but `inlining-optimizing` is still not cheap on the debug CLI artifact. The next owners are:

1. `inl_has_same_sig_root_cycle_dead_suffix(...)` / `inl_should_preserve_same_sig_root_cycle_dead_suffix(...)`, visible as `detail:inlining:once:preserve-root-cycle-check` at `12.274s` after the reachability fix.
2. `inl_collapse_unreachable_roots(...)`, visible as `detail:inlining:once:collapse-unreachable-roots` at `8.835s`.
3. The repeated whole-module iteration shape: iteration `4` touched one original function but still paid multi-second whole-graph cleanup costs.

Potential next patch: cache or short-circuit the same-signature root-cycle dead-suffix preservation checks per iteration, and avoid re-running full-module unreachable-root collapse when touched counts are tiny and no relevant unreachable-cycle scaffolding is present.

## Code changes

- Added persistent perf timers/counters for inlining subphases in `src/passes/inlining.mbt`, wired to the existing `HotPerfSession` from `src/passes/pass_manager.mbt`.
- Added trace lines for iteration count, touched function count, inlined-from count, helper-removal count, and large-module nested-cleanup skips.
- Replaced repeated recursive `inl_graph_reaches(...)` queries inside `inl_original_reachable_private_cycle_funcs(...)` and its prediction helpers with an iteration-local transitive reachability table.
- Added a white-box test that locks the reachability table's cycle-only self-reachability semantics.
