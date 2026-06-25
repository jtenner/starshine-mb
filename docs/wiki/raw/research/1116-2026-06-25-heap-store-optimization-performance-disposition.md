---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1115-2026-06-25-heap-store-optimization-pure-default-chain-fast-path.md
  - ./1112-2026-06-25-heap-store-optimization-reorder-mask-fast-path.md
  - ./1111-2026-06-25-heap-store-optimization-post-refcast-performance.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO-I performance disposition proposal

## Question

After the `1115` pure-default chain fast path improved but did not close the allocation-heavy fixture, what is the precise HSO-I release disposition?

## Current evidence

The current allocation-heavy performance series is consistent and HSO-owned:

| Evidence | 1000-function Starshine median | 2000-function Starshine median | Binaryen 2000-function median | 2000-function ratio |
|---|---:|---:|---:|---:|
| `1111` post-refcast refresh | `5.465ms` | `10.765ms` | `2.028ms` | `~5.3x` |
| `1112` reorder-mask fast path | `5.155ms` | `11.083ms` | `2.028ms` | `~5.5x` |
| `1115` pure-default chain fast path | `4.285ms` | `8.934ms` | `2.028ms` | `~4.4x` |

The generated O4z predecessor artifacts remain a separate no-candidate/fast-skip case: latest slot replay in `1114` had exact/canonical and normalized-WAT equality, Starshine raw-fast-skipped HSO, and pass-local `0.000ms`. That evidence protects cheap no-candidate behavior, but it does not close the allocation-heavy candidate path.

## Disposition

Do **not** close or accept HSO-I yet.

Recommended release-gate wording:

- HSO-I remains an active performance blocker because the best current 2000-function synthetic candidate-heavy fixture is still about `4.4x` Binaryen pass-local time, above the repo target of `starshine_time <= 2 * binaryen_time`.
- The blocker is narrowed by `1115`; the open question is no longer whether cheap no-candidate O4z slots are slow, but why candidate-heavy per-function work still costs several microseconds per small function.
- Final HSO-J closeout should stay deferred until HSO-I is either improved to the target, explicitly accepted by the user with release rationale, or superseded by stronger artifact/neighborhood timing that justifies retiring this synthetic fixture as the release gate.

## Acceptance criteria to close HSO-I without user override

One of the following should be true:

1. **Target met on the existing synthetic fixture.** Rebuild native Starshine, rerun three traced Starshine passes on `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat`, validate outputs, rerun or cite a current Binaryen median for the same fixture, and show Starshine median `<= 2x` Binaryen.
2. **Synthetic fixture superseded.** Provide artifact/neighborhood evidence showing the allocation-heavy synthetic fixture is not representative of the release target, including exact commands, pass-local timings, and reopening criteria if a real artifact later exhibits HSO-owned candidate-heavy slowdown.
3. **Explicit acceptance.** User approves carrying the known HSO-I performance gap into the release, with the exact measured ratio and follow-up backlog owner preserved.

## Next structural targets

The next implementation slice should avoid more tiny effect-mask guards unless profiling proves they dominate. Higher-leverage candidates:

- reduce per-function fixed allocation/cache churn in `heap_store_optimization_run(...)`, especially small-function predicate/type cache setup and region-root copying;
- further batch simple local-set chains without skipping the existing safety path for branch/control/call/trap shapes;
- inspect generic chain bookkeeping around `hso_process_local_set_chain(...)` and repeated `next_roots` / `segment_roots` construction;
- add more detailed temporary timers only if they can isolate sub-microsecond buckets without becoming permanent telemetry.

## Validation

Docs/status-only. No tests were required because this note records a disposition proposal and does not change executable behavior.
