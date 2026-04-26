---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0416-2026-04-26-monomorphize-port-readiness.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize-always/index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
  - ./clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize-always/index.md
---

# Starshine port-readiness and validation for `monomorphize`

Use this page after the overview in [`./index.md`](./index.md), the Binaryen strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the shape catalog in [`./wat-shapes.md`](./wat-shapes.md), and the current Starshine status map in [`./starshine-strategy.md`](./starshine-strategy.md).
This page answers a narrower question: **what is the safest route from today's boundary-only Starshine status to a validated future port?**

## Current local hold point

Starshine does **not** implement `monomorphize` today.
The current code surfaces are still only:

- boundary-only registry names: [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
- CLI flag parsing for `--monomorphize-min-benefit`: [`src/cli/cli.mbt#L994-L1023`](../../../../../src/cli/cli.mbt#L994-L1023)
- JSON config aliases `monomorphizeMinBenefit` and `monomorphize-min-benefit`: [`src/cmd/cmd.mbt#L1114-L1123`](../../../../../src/cmd/cmd.mbt#L1114-L1123)
- CLI/env/config merge order: [`src/cmd/cmd.mbt#L1488-L1495`](../../../../../src/cmd/cmd.mbt#L1488-L1495)
- defaulting and option forwarding into `OptimizeOptions`: [`src/cmd/cmd.mbt#L3498-L3517`](../../../../../src/cmd/cmd.mbt#L3498-L3517)
- command-summary proof for a nondefault CLI value: [`src/cmd/cmd_wbtest.mbt#L4362-L4415`](../../../../../src/cmd/cmd_wbtest.mbt#L4362-L4415)

There is still no `src/passes/monomorphize.mbt`, no active module dispatcher case, no default preset role, and no dedicated `agent-todo.md` slice.

## Binaryen oracle lanes to preserve

The upstream pass is not a simple local peephole.
A Starshine port should preserve the source-backed lanes from [`../../../raw/binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md):

1. scan direct calls in the original defined-function snapshot
2. reject imported targets, recursive self-calls, unreachable calls, and indirect calls
3. build executable call-context operands only when movement is effect-safe
4. reject trivial contexts and too-wide specialized signatures
5. clone a specialized callee and rebuild its signature from surviving dynamic inputs
6. convert old params to locals and shift local indexes/names safely
7. handle caller-side dropped results only when return-call-sensitive behavior is not broken
8. run nested optimization and cost comparison for ordinary `monomorphize`
9. reuse the same legality pipeline for `monomorphize-always`, changing only the usefulness rejection policy

The lit lanes in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) and shape families in [`./wat-shapes.md`](./wat-shapes.md) should become the reduced local test matrix.

## Recommended implementation sequence

### Slice 0: registry honesty and option semantics

Before mutation, decide and test the public policy:

- keep `monomorphize` boundary-only until a real implementation exists, or
- introduce an explicit active-but-no-rewrite analyzer only behind an internal/debug lane

Required tests:

- explicit `--monomorphize` must not silently no-op under the current boundary-only state
- `--monomorphize-min-benefit` must keep parsing and config/env/CLI merge behavior
- docs and CLI help must not imply the option is active until a pass consumes it

Important caveat: Binaryen's current source treats the minimum benefit as a percent-like threshold with a default of `95`; Starshine currently stores an inert default of `5`.
A faithful port must resolve that mismatch before claiming Binaryen-compatible usefulness gating.

### Slice 1: no-rewrite direct-call analyzer

Build a deterministic analyzer that reports candidate classes but returns the original module unchanged.

It should classify:

- direct defined-function calls
- imported-target calls
- recursive self-calls
- indirect `call_ref` / table-call families as non-candidates
- calls whose result is immediately wrapped in `drop`
- calls with scalar literal operands
- calls that exceed the future `MaxParams = 20` specialized-param cap

Validation:

- byte-for-byte no output change
- stable candidate counters in focused tests
- no accidental activation in presets

### Slice 2: scalar literal specialization without operand movement

The first mutating slice should choose the narrowest positive:

```wat
(call $target (local.get $x) (i32.const 7))
```

into a cloned callee that receives only the dynamic input and initializes the old constant parameter in the clone prelude.
Do not yet move effectful operand subtrees across siblings.

Required repairs:

- function list insertion and unique clone naming
- function type rebuild
- old-param-to-local conversion
- local index remap
- call retargeting and operand deletion
- validation of locals, result types, and body shape

Required negatives:

- imported target
- recursive self-call
- indirect call
- too many surviving params
- nonliteral or effectful operands until the movement proof exists

### Slice 3: dropped-result specialization

Handle `(drop (call $target ...))` only after the clone pipeline is reliable.
The pass may make the specialized clone return `none` and remove the caller-side `drop` wrapper, but it must reject targets where return-call-sensitive behavior makes this unsafe.

Tests should include:

- plain dropped-call positive
- explicit-return repair inside the clone
- return-call-sensitive negative
- validation after caller-side wrapper removal

### Slice 4: context movement and refined reference types

Only after scalar and dropped-result slices are green, add the harder Binaryen families:

- effect-safe operand movement from the caller into the clone prelude
- movable GC allocation context
- refined reference parameter types
- context memoization for repeated successes and failures

These are the shapes most likely to break validation or reorder effects if implemented too early.
Use [`./call-context-benefit-and-boundaries.md`](./call-context-benefit-and-boundaries.md) as the safety checklist.

### Slice 5: usefulness gate and `monomorphize-always`

A complete ordinary `monomorphize` port needs nested optimization and cost comparison.
Until then, prefer either:

- an internal always-mode test lane, or
- a local `monomorphize-always` slice that shares legality with ordinary `monomorphize` but intentionally skips usefulness rejection.

Do not implement the sibling as a separate shortcut: it should share scan, context, clone, repair, and validation code with the ordinary pass.

## Validation ladder

Use a widening ladder rather than jumping straight to artifact fuzzing:

1. analyzer no-change tests for every candidate and rejection class
2. scalar literal clone positives and negatives
3. dropped-result positives and return-call-sensitive negatives
4. GC/refined-type and effect-movement cases
5. `monomorphize-always` weak-benefit cases beside ordinary usefulness-gated non-specializations
6. Binaryen oracle comparison with `--monomorphize` and `--monomorphize-always`
7. broader pass-fuzz only after the module-level clone/retarget machinery has local validation coverage

For each mutating slice, validate both text/WAT fixtures and binary roundtrips because this pass changes function declarations, call operands, locals, and sometimes result types.

## Read-along map

- Upstream strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Source/test owner map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Call-context safety: [`./call-context-benefit-and-boundaries.md`](./call-context-benefit-and-boundaries.md)
- Clone/signature repair: [`./clone-construction-signature-rebuild-and-dropped-call-rewrites.md`](./clone-construction-signature-rebuild-and-dropped-call-rewrites.md)
- Concrete WAT shapes: [`./wat-shapes.md`](./wat-shapes.md)
- Current Starshine status: [`./starshine-strategy.md`](./starshine-strategy.md)
- Sibling policy: [`../monomorphize-always/index.md`](../monomorphize-always/index.md)

## Open questions to keep explicit

- How should Starshine map its currently inert `monomorphize_min_benefit = 5` default to Binaryen's current default threshold of `95` once the option becomes active?
- Should nested optimization be required before any public mutating `monomorphize` slice, or should a narrow `monomorphize-always` debug lane land first to prove clone/retarget mechanics?
- Which module-pass dispatcher should own whole-module function cloning once more boundary-only passes graduate beyond HOT-local transformations?
