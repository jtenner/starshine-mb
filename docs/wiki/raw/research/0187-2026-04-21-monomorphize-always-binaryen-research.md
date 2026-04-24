# Binaryen `monomorphize-always` research

Date: 2026-04-21
Status: superseded-for-provenance-and-lit-surface by `0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`; still useful for historical context
Pass: `monomorphize-always`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Neighbor dossier: `docs/wiki/binaryen/passes/monomorphize/`

## Why this pass was chosen

The original no-DWARF parity queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only registry wave were already dossier-covered before this thread started.

`docs/wiki/binaryen/passes/tracker.md` explicitly said a future thread should either:

1. justify a real new upstream-only expansion from the local registry, or
2. justify a source-backed major-gap fallback.

`src/passes/optimize.mbt` still exposes several public or test-oriented Binaryen pass names that do not yet have dedicated landing folders. `monomorphize-always` was the strongest candidate because:

- it is a real local boundary-only registry name, not just a comment or test flag
- Binaryen `version_129` registers it as a separate public pass in `src/passes/pass.cpp`
- the existing `monomorphize` dossier already proves it is not just a typo or alias, but there was still no canonical living folder focused on the sibling itself
- `agent-todo.md` has no dedicated `monomorphize-always` slice
- it teaches an easy-to-miss contract boundary: Binaryen's default `monomorphize` is usefulness-gated, while `monomorphize-always` is the same specialization engine with that gate disabled

So this thread is a justified tracker expansion for another real official/local-registry pass surface.

## Official upstream sources reviewed

### Main implementation and registration

- `src/passes/Monomorphize.cpp`
- `src/passes/pass.cpp`
- helper dependencies visible from `Monomorphize.cpp`:
  - `src/ir/cost.h`
  - `src/ir/effects.h`
  - `src/ir/find_all.h`
  - `src/ir/manipulation.h`
  - `src/ir/module-utils.h`
  - `src/ir/names.h`
  - `src/ir/properties.h`
  - `src/ir/return-utils.h`
  - `src/ir/type-updating.h`
  - `src/ir/utils.h`
  - `src/wasm-limits.h`

### Official lit tests reviewed or indexed

- `test/lit/passes/monomorphize-benefit.wast`
- `test/lit/passes/monomorphize-consts.wast`
- `test/lit/passes/monomorphize-context.wast`
- `test/lit/passes/monomorphize-drop.wast`
- `test/lit/passes/monomorphize-limits.wast`
- `test/lit/passes/monomorphize-mvp.wast`
- `test/lit/passes/monomorphize-types.wast`
- `test/lit/passes/no-inline-monomorphize-inlining.wast`

## High-level conclusion

`monomorphize-always` is not a different algorithm from `monomorphize`.
It is the same whole-module direct-call contextual-specialization machinery, but with the empirical "keep only if benefit is high enough" policy turned off.

That makes the best beginner summary:

- `monomorphize` = specialize, optimize, measure, keep only if helpful enough
- `monomorphize-always` = specialize whenever the context is nontrivial and legal, even if later optimization cannot prove a strong payoff

This distinction matters because a future Starshine port could easily implement only the core cloning machinery and accidentally erase the public contract boundary between:

- the careful production pass, and
- the testing/debugging sibling that intentionally keeps more speculative clones.

## Most important durable findings

1. `monomorphize-always` is a real official public Binaryen pass name, not just a hidden test mode.
2. It is separately registered in `pass.cpp` and separately named in the local registry.
3. The implementation still uses the same core `Monomorphize` engine and the same `CallContext` builder.
4. It still requires direct calls, legal movable context, nontrivial context, and the same parameter-count and structural safety checks.
5. It still rejects imported callees, recursive self-calls, unreachable calls, trivial contexts, and over-budget specialized signatures.
6. It still runs the same nested optimization on cloned callees; the difference is what happens **after** that optimization.
7. The main behavioral split is that the default `MinPercentBenefit` gate is not used to reject a nontrivial legal specialization in `monomorphize-always`.
8. `monomorphize-always` therefore exposes more clones in tests, especially on refined-reference and weak-benefit cases.
9. It is not equivalent to every thresholded `monomorphize` setting in every teaching context: the public contract is a separate sibling pass, not just a recommended pass-arg.
10. The official test surface uses that sibling to make the pass's hidden usefulness policy visible.

## What matters in `Monomorphize.cpp`

The main file already had to support two public variants, so the reviewed implementation separates:

- the shared specialization machinery
- from the usefulness policy

The shared machinery includes:

- call discovery (`CallFinder`)
- callsite-context extraction (`CallContext::buildFromCall`)
- effect-safe reverse-inlining of movable operands
- signature rebuilding for the specialized clone
- dropped-result specialization
- local remapping and name repair
- nested optimizer reruns
- parameter-limit enforcement
- memoization of both wins and losses

The variant split comes later:

- careful mode computes a benefit percentage and may discard the clone
- always mode keeps the clone once all earlier legality/nontriviality checks pass

That means the **gate removal happens after most of the hard work is already shared**.
It is not a tiny flag that skips half the algorithm.

## Main algorithm, phrased for the sibling

For `monomorphize-always`, the real pipeline is:

1. find a direct call
2. reject imported / recursive / unreachable / tail-call-sensitive bad fits
3. build movable callsite context
4. reject trivial context
5. clone a specialized function and rebuild its signature
6. reject signatures that still exceed the hard param cap
7. optimize the specialized clone with the same nested helper pipeline
8. retarget the original call even if the measured benefit would have been too small for normal `monomorphize`

So the pass is still conservative about **correctness**, but intentionally less conservative about **profitability**.

## Positive shapes that become easier to see in `monomorphize-always`

### 1. Refined-reference specializations with weak immediate payoff

The dedicated type-oriented test surface shows the best example.
A direct call may pass a reference operand whose dynamic information is more specific than the callee's declared param type.
Sometimes that unlocks obvious simplification; sometimes it mostly just sharpens the specialized signature.

- careful `monomorphize` may reject the weak-payoff case
- `monomorphize-always` keeps it

This is one reason the sibling is useful for teaching.
It shows the specialization machinery even when profitability is not dramatic enough for the default pass.

### 2. Constant or movable context that only slightly shrinks the body

The same is true for constants and movable constructor-like context.
A legal context may produce a valid specialized callee whose optimized body is only marginally better than the original-plus-callsite cost.

- careful mode may discard it
- always mode keeps it

### 3. Dropped-call specializations that are structurally cleaner but not profitable enough

The dropped-result path can still simplify the callee to a `none` result and remove explicit `drop` traffic at the callsite.
If the cost model does not deem that large enough, normal `monomorphize` may refuse it.
The sibling preserves it, which is useful in tests that want to show the exact rewrite shape.

## Negative shapes that remain negative in both variants

`monomorphize-always` is **not** "specialize everything."
It still inherits the main hard boundaries:

- no imported callees
- no recursive self-calls
- no unreachable calls
- no trivial passthrough contexts
- no context movement across illegal effect/order barriers
- no contexts that require unsupported local/control/tuple movement forms
- no specialized signature that still exceeds the hard cap (`MaxParams = 20` in the reviewed source)
- no dropped-result folding when return-call handling makes that unsafe

This is the most important beginner warning.
Removing the usefulness gate does **not** remove the legality gate.

## Relationship to `monomorphize --pass-arg=monomorphize-min-benefit@0`

Inference from sources:

- the lit surface clearly compares `monomorphize-always` with threshold-tuned `monomorphize`
- both are used to expose the benefit-policy surface
- the reviewed docs and source patterns strongly suggest they overlap in practical accepted cases once benefit threshold drops to zero

But the durable point to preserve is this:

- Binaryen publishes **two distinct public surfaces**
- one is a sibling pass name
- the other is a parameterized mode of the default pass

A future Starshine port should preserve that distinction in docs and CLI surface even if it later chooses to implement both using shared internals.

## Why the official tests matter

### `monomorphize-benefit.wast`

This file is the clearest proof that the sibling matters.
It varies the threshold and makes it obvious that:

- the careful pass is intentionally empirical
- different thresholds accept different clones
- `monomorphize-always` exists to bypass exactly that policy layer

### `monomorphize-types.wast`

This file is the strongest proof that the sibling is not just about constants.
It highlights reference-type refinement cases where specialization is semantically real even if the immediate cost improvement is modest.

### `monomorphize-context.wast` and `monomorphize-drop.wast`

These prove that the sibling still shares the same hard context-builder and dropped-result rules.
The pass family does not fork into separate rewrite engines.

## Interaction with nearby passes

`monomorphize-always` still depends on the same neighboring ideas as `monomorphize`:

- it is not ordinary `inlining`
- it still needs nested optimization to expose the value of specialization
- it still benefits from `precompute-propagate`-style cleanup inside the nested optimizer
- it still interacts conceptually with `inline-main` and the broader inlining family without being identical to them

The key scheduler/teaching boundary is:

- `inlining` clones callee code into the caller
- `monomorphize*` clones the callee and pulls caller context inward

## What a future Starshine port must preserve

1. Separate public registry/CLI identity for `monomorphize-always`.
2. Shared core specialization logic with `monomorphize`, not a divergent rewrite engine.
3. All the same legality and nontrivial-context checks.
4. The same parameter-limit bailout.
5. The same dropped-result and local-remap repair rules.
6. The same nested optimization dependency.
7. The explicit policy split: always mode skips usefulness rejection, not correctness rejection.

## Beginner-friendly one-sentence summary

`monomorphize-always` means “do the same direct-call contextual specialization as `monomorphize`, but keep legal nontrivial clones even when Binaryen's normal cost/benefit gate would say the payoff is too small.”

## Supersession note added 2026-04-24

`docs/wiki/raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md` supersedes this note for provenance, local Starshine status, and direct lit-test attribution.

The main correction is that `monomorphize-types.wast` is the direct `--monomorphize-always` lit proof, while `monomorphize-benefit.wast` should be cited only as supporting evidence for the threshold-policy axis of ordinary `monomorphize`.

## Open questions / uncertainty

1. I did not re-derive every exact constructor argument or class-level flag name from `Monomorphize.cpp` in this note; the living pages should stay the canonical place for source-structure details.
2. I am treating the public sibling split as semantically primary and the threshold-zero mode as a neighboring tuning surface. That is source-backed, but the exact equivalence or nonequivalence of those two user surfaces in every corner case should still be described carefully as an inference unless rechecked line-by-line in the implementation.
3. I did not find a dedicated `monomorphize-always.wast` file. The sibling's contract is instead exposed across the broader `monomorphize*` lit family; use `monomorphize-types.wast` for direct sibling execution and `monomorphize-benefit.wast` only for neighboring threshold-policy context.

## Living pages added from this research

- `docs/wiki/binaryen/passes/monomorphize-always/index.md`
- `docs/wiki/binaryen/passes/monomorphize-always/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize-always/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/monomorphize-always/usefulness-gate-and-sibling-split.md`
- `docs/wiki/binaryen/passes/monomorphize-always/wat-shapes.md`

## Sources

- Local registry source:
  - `src/passes/optimize.mbt`
- Existing neighboring dossier:
  - `docs/wiki/binaryen/passes/monomorphize/index.md`
  - `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/monomorphize/implementation-structure-and-tests.md`
  - `docs/wiki/binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md`
  - `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
