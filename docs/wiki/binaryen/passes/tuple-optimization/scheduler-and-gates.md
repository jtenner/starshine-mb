---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
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
- exact preset-level multivalue slot coverage once the surrounding Binaryen neighbors are present in-tree

## Why Presets Still Omit The Pass

Starshine has an explicit helper:

- `tuple_optimization_exact_slot_prereqs_ready()`

Today that helper requires:

- `code-pushing` to exist as a real hot pass
- `simplify-locals-no-structure` to exist as a real hot pass

Current result:

- that helper does not unlock preset inclusion yet
- the `optimize` and `shrink` preset builders still intentionally ignore it and return a pass list without tuple-opt

Why this is the correct temporary behavior:

- approximate placement would give false confidence about Binaryen pathway parity
- tuple-opt is unusually order-sensitive because it is meant to sit between an earlier tuple-removing peephole neighborhood and later local cleanup passes
- correctness proof on the explicit pass surface is valuable, but it is not the same thing as preset parity

## Current Starshine Gate Behavior

Starshine already enforces the most important practical gate on the explicit pass surface:

- scalar-only functions do not rewrite
- a focused test in `src/passes/optimize_test.mbt` proves explicit tuple-opt is a true no-op there

This is not yet the same as final preset-level multivalue scheduling parity, but it does preserve the intended safety envelope for direct invocation.

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

