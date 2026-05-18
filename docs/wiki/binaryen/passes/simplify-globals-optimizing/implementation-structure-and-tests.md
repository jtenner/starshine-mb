---
kind: concept
status: supported
last_reviewed: 2026-05-18
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
---

# `simplify-globals-optimizing` implementation structure and tests

This page maps the reviewed Binaryen owner files and shipped lit tests for `simplify-globals-optimizing`.
Use it with the raw source manifest in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md).

## One shared implementation family

Binaryen `version_129` does not implement `simplify-globals-optimizing` in a separate standalone file.
The pass is part of the shared `SimplifyGlobals.cpp` family:

- `simplify-globals`
- `simplify-globals-optimizing`
- `propagate-globals-globally`

That shared-engine fact is the main thing to remember when reading source or tests.
Most examples named `simplify-globals-*` prove behavior used by both public `simplify-globals` siblings, while the optimizing-specific difference is the nested changed-function cleanup step.

## Source ownership map

| Source | What it owns for this pass | Why readers should care |
| --- | --- | --- |
| Binaryen `src/passes/SimplifyGlobals.cpp` | The shared module/global algorithm, including global-use scanning, single-use initializer folding, useless-write removal, immutable-copy canonicalization, startup propagation, runtime trace propagation, changed-function tracking, and the optimizing-only nested rerun hook. | This is the primary owner file. Do not look for a separate `SimplifyGlobalsOptimizing.cpp`. |
| Binaryen `src/passes/pass.cpp` | Public pass registration and default optimizer scheduling. | This is where the public names and late post-pass placement are exposed. |
| Binaryen `src/pass.h` | `PassRunner` mechanics used by nested pass execution. | The optimizing sibling depends on rerunning ordinary function optimization passes over changed functions. |
| Binaryen `src/ir/effects.h` | Effect summaries for calls, writes, traps, and other side effects. | The `read-only-to-write` legality checks use effects for safety, but still require actual `global.get` / `global.set` syntax for the rewrite itself. |
| Binaryen `src/ir/find_all.h` | Parent / child discovery helpers. | The source uses structural walks to find concrete global reads and writes. |
| Binaryen `src/ir/linear-execution.h` | Cheap linear-trace reasoning for runtime propagation. | This is why runtime substitution is conservative around calls and nonlinear control instead of becoming a full dominator analysis. |
| Binaryen `src/ir/properties.h` | Constant-expression and literal-equivalence helpers. | Same-as-init writes and startup constants rely on these helpers. |
| Binaryen `src/ir/utils.h` | General IR helper surface used by the pass family. | It is part of the source-backed helper set for readers following the owner file. |

## Optimizing-specific structure

The optimizing sibling is best read as:

1. run the shared global simplification algorithm with the optimizing mode enabled,
2. remember which functions changed because global reads were replaced or writes were removed,
3. rerun Binaryen's default function optimization pipeline over those changed functions,
4. do **not** use the `dae-optimizing` / `inlining-optimizing` helper that prepends `precompute-propagate`.

That is why the pass belongs beside other late boundary passes in the default optimizer, but its nested rerun behavior is not interchangeable with the optimizing DAE or inlining siblings.

## Shipped test map

Binaryen's tests for this family are clustered rather than one exact `simplify-globals-optimizing.wast` file.
The important reviewed files are:

| Test file | Main proof surface |
| --- | --- |
| `simplify-globals-dominance.wast` | Runtime propagation through cheap linear traces, including call and control-flow barriers. |
| `simplify-globals-gc.wast` | GC/reference-type cases, type-compatibility boundaries, and refinalization-sensitive behavior. |
| `simplify-globals-nested.wast` | Nested self-guard / repeated-iteration families for `read-only-to-write` cleanup. |
| `simplify-globals-non-init.wast` | Difference between same-as-init writes, non-init writes, and dead writes. |
| `simplify-globals-offsets.wast` | Startup propagation into active data and element offsets. |
| `simplify-globals-prefer_earlier.wast` | Immutable-copy-chain canonicalization toward earlier compatible globals. |
| `simplify-globals-read_only_to_write.wast` | The largest exact matcher surface: actual-node matching, effect filtering, value-flow danger, and bailout examples. |
| `simplify-globals-single_use.wast` | One-time initializer folding into later global initializers and the multi-use / function-use / import / export bailouts. |
| `simplify-globals_func-effects.wast` | Distinction between function-effect summaries and concrete AST `global.get` / `global.set` nodes. |
| `propagate-globals-globally.wast` | Startup-only propagation subset shared with, but smaller than, full `simplify-globals*`. |

## What the tests do not isolate cleanly

The shipped lit roster is strong for the shared global rewrite rules, but it is less beginner-obvious for the optimizing wrapper itself.
In practice:

- many `simplify-globals-*` tests demonstrate the shared engine, not the optimizing-only rerun,
- the optimizing nested-rerun contract is easier to confirm from `SimplifyGlobals.cpp` plus `pass.h` / `pass.cpp` than from one standalone lit filename,
- future Starshine tests should therefore add explicit local scheduler tests for the nested rerun rather than relying only on shape tests for global rewrites.

## Current-main drift note

The 2026-04-24 spot check recorded in the raw source manifest reviewed both `version_129` and current `main` URLs for the owner file, registration file, helper headers, and lit roster.
The 2026-04-25 focused bridge rechecked current-main `SimplifyGlobals.cpp`, `pass.cpp`, and `pass.h` for port-readiness. The 2026-05-18 refresh rechecked official Binaryen `main` at commit `d3029d2b975488acdf9253eb2994a3fc55bd3549` and diffed the SGO owner, nested-runner header, and key lit tests against `version_129`; no SGO semantic drift was found.
Treat those as provenance and implementation-readiness refreshes, not full upstream audits.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
