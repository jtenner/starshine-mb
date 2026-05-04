---
kind: concept
status: working
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization` Scheduler And Gates

## Confirmed Binaryen Slot

Binaryen `version_129` runs the pass:

- after `code-pushing`
- before `simplify-locals-nostructure`
- only when multivalue is enabled

The upstream scheduler comment is unusually explicit about why:

- tuple-opt should run after at least `optimize-instructions`, because that earlier pass can already remove some tuple traffic
- tuple-opt should still run before the local cleanup passes, because splitting tuple scratch locals helps those local passes do real work

In the documented no-DWARF function pipeline, the relevant neighborhood is:

```text
... -> precompute -> code-pushing -> tuple-optimization
-> simplify-locals-nostructure -> vacuum -> reorder-locals -> ...
```

## Binaryen Feature Gate

Binaryen has a hard multivalue gate:

- if multivalue is off, `tuple-optimization` does not run
- if multivalue is on but the function has no tuple locals, the pass becomes a no-op quickly

Why the gate is exact and important:

- the pass is semantically about tuple and multivalue carriers
- running it outside that feature envelope would just add analysis overhead and potential false positives

## Current Starshine Surface

For the in-tree code map, see [`./starshine-strategy.md`](./starshine-strategy.md) and [`./implementation-map.md`](./implementation-map.md).

Starshine currently has two different truths at once:

- the explicit pass exists and is fully registered
- the public presets still omit it

What is already live:

- `tuple-optimization` is a real hot pass registry entry in `src/passes/optimize.mbt`
- `run_hot_pipeline(..., ["tuple-optimization"])` works
- CLI invocation through `--tuple-optimization` works
- pass-manager dispatch exists in `src/passes/pass_manager.mbt`

What is intentionally still missing:

- preset inclusion in `optimize`
- preset inclusion in `shrink`
- exact preset-level multivalue slot coverage and ordered replay proof for the surrounding Binaryen neighborhood

## Why Presets Still Omit The Pass

Starshine has an explicit helper:

- `tuple_optimization_exact_slot_prereqs_ready()`

Today that helper checks the two neighbor passes and now resolves true in-tree:

- `code-pushing`
- `simplify-locals-no-structure` / `simplify-locals-nostructure`

Current result:

- the helper no longer blocks on pass availability
- the `optimize` and `shrink` preset builders still intentionally ignore it pending ordered-neighborhood replay and exact slot proof

Why this is the correct temporary behavior:

- approximate placement would give false confidence about Binaryen pathway parity
- tuple-opt is unusually order-sensitive because it is meant to sit between an earlier tuple-removing peephole neighborhood and later local cleanup passes
- correctness proof on the explicit pass surface is valuable, but it is not the same thing as preset parity

## Current Starshine Gate Behavior

Starshine already enforces the most important practical gate on the explicit pass surface:

- scalar-only functions do not rewrite
- a focused test in `src/passes/optimize_test.mbt` proves explicit tuple-opt is a true no-op there

This is not yet the same as final preset-level multivalue scheduling parity, but it does preserve the intended safety envelope for direct invocation.

## Current Function-Local Candidate Gate

The practical runtime gate inside `src/passes/tuple_optimization.mbt` changed materially on `2026-04-10`.

The old structure was:

- run a weak whole-function screen looking only for any live multivalue node plus any local write
- inside analysis, run that same weak screen again
- then run a full seed-group collection walk

Why that was bad:

- unchanged functions paid multiple whole-function walks before tuple-opt could prove there was nothing to do
- the weak screen was not specific to actual Binaryen-style tuple seeds
- seed discovery itself rebuilt temporary arrays and used linear duplicate-local checks per producer, which turned high-arity or candidate-heavy functions into avoidable GC churn

The current structure is:

- build or reuse `use-def`
- run one precise seed scan
- bail out immediately if the scan finds no seed groups
- reuse those already-collected groups for the rest of analysis and rewrite

The precise scan now matches the real seed contract:

- producer result arity must be `> 1`
- use count must equal result arity
- every use must be child slot `0`
- every user must be `local.set` or `local.tee`
- lane locals must be unique

The current collector also uses stamped local marks instead of repeated linear searches, so the per-producer duplicate-local check is no longer quadratic in lane count.

Practical consequence on the debug artifact:

- tuple-opt still visits `4462` functions and changes only `18`
- and the cleaned direct pass trace is now `277790 us`, down from the old `960971 us` band
- the old unchanged-function hot quartet mostly disappeared, so the remaining runtime debt is no longer dominated by obvious no-op screening churn
- the newer per-function trace split also clarified that the remaining tuple-pass cost and the surrounding pipeline cost are not the same thing:
  - inside `pass:tuple-optimization`, `Func 1673` now dominates at roughly `101831 us`, with the next tier far behind (`148` at `14719 us`, `2389` at `10152 us`, `1905` at `6557 us`, `3660` at `5725 us`, `147` at `5556 us`)
  - outside the pass timer, `analysis:use-def` still spends most of its time in different functions (`3612`, `1553`, `1525`), so future tuple runtime work should keep those two costs separate instead of treating aggregate wall time as pure tuple-pass debt

## Required Future Conditions Before Preset Enablement

Before tuple-opt should move into public presets, the branch still needs all of:

- exact `code-pushing -> tuple-optimization -> simplify-locals-nostructure` slot representation
- feature-off preset coverage
- direct pass parity proof still green
- artifact replay evidence from the real preset neighborhood, not just the isolated explicit pass

## Practical Rule

- Treat explicit-pass success as a prerequisite, not as final scheduler signoff.
- Do not sneak tuple-opt into a nearby preset slot just because the direct pass is mostly correct.
- If a future parity bug appears only under the real preset neighborhood, classify it as a scheduler-neighbor bug first, not automatically as a tuple rewrite bug.

## Sources

- Archived project note: [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Current Starshine registry and preset surface: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Explicit scheduler dispatch: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Canonical Binaryen no-DWARF pathway page: [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
