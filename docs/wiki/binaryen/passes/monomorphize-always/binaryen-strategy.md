---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize/index.md
---

# Binaryen strategy for `monomorphize-always`

## What the pass really is

`monomorphize-always` is a **whole-module direct-call contextual-specialization pass** implemented by the same `Monomorphize.cpp` engine as ordinary [`../monomorphize/index.md`](../monomorphize/index.md).

The source-backed model is:

- `monomorphize` constructs `Monomorphize(true)` and keeps clones only when they are helpful enough
- `monomorphize-always` constructs `Monomorphize(false)` and skips that final usefulness rejection
- both variants share the same candidate scan, context builder, clone construction, nested optimization, and safety gates

## Public surface

`src/passes/pass.cpp` registers `monomorphize-always` as a separate public pass name. The reviewed description says the sibling creates specialized function versions even when they are unhelpful.

That public identity matters for Starshine because:

- users can request the sibling directly upstream
- the local registry already tracks the name separately
- future ports should keep two public entrypoints rather than hiding the sibling behind only a pass-arg recipe

## Shared algorithm

The shared engine still does the hard work:

1. Walk original defined functions and collect candidate direct calls.
2. Reject calls to imports, self-recursive calls, unreachable calls, and unsuitable tail/dropped-result forms.
3. Build a `CallContext` by reverse-inlining movable call operands into the future callee clone.
4. Reject contexts that are trivial after analysis.
5. Clone the target function.
6. Rebuild the clone signature from surviving dynamic `local.get` inputs.
7. Adjust result type to `none` for safe dropped-call cases.
8. Repair locals and local names in the clone.
9. Prepend context initialization statements to the clone body.
10. Run the nested optimizer on the clone.
11. Decide whether to keep the clone and retarget the original call.

`monomorphize-always` changes only step 11's usefulness policy.

## What “always” removes

Ordinary `monomorphize` measures the original and specialized forms and rejects a clone when the computed payoff is below `monomorphize-min-benefit`.

The always sibling removes that rejection. In beginner terms:

- ordinary mode asks: “legal, nontrivial, and helpful enough?”
- always mode asks: “legal and nontrivial?”

## What “always” does not remove

The sibling is less profitability-conservative, not less correctness-conservative.

It still refuses:

- imported callees
- recursive self-calls
- unreachable calls
- trivial passthrough contexts
- context expressions that cannot be moved inward safely
- unsupported tuple/control families
- too many surviving dynamic parameters
- unsafe dropped-result folds around return-call-sensitive code

## Lit-test correction

The 2026-04-24 source capture fixes one stale teaching shortcut:

- `monomorphize-types.wast` directly runs `--monomorphize-always` and is the best direct lit proof for the sibling.
- `monomorphize-benefit.wast` demonstrates threshold-sensitive ordinary `monomorphize` behavior; it supports the policy-axis explanation, but it does not itself run `--monomorphize-always`.

So cite `monomorphize-types.wast` for direct sibling execution and cite `monomorphize-benefit.wast` only for the neighboring usefulness-threshold story.

## Positive rewrite families

### Weak-benefit refined references

A callsite may pass a more specific reference type than the callee declares. The clone can expose the sharper type even when immediate code-size payoff is small. This is the clearest `monomorphize-always` teaching family.

### Weak-benefit constants

A constant argument can move into the clone and remove a parameter. If nested optimization does not shrink enough for ordinary mode, always mode still keeps the legal clone.

### Dropped result context

When the original call result is immediately dropped, the clone can safely become `none`-result in some cases and absorb the drop. Always mode keeps weak-payoff versions of that structure.

## Relationship to threshold tuning

Inference from sources:

`--monomorphize --pass-arg=monomorphize-min-benefit@0` is closely related to the sibling, and official tests compare these surfaces. But the wiki should still preserve the separate public pass name because Binaryen registers it separately and Starshine tracks it separately.

## What a Starshine port must preserve

A faithful port needs:

1. one shared specialization engine
2. separate public `monomorphize` and `monomorphize-always` entrypoints
3. the full legality/triviality/limit gates in both variants
4. nested optimization of the clone
5. an ordinary usefulness policy for `monomorphize`
6. no final usefulness rejection for `monomorphize-always`

See [`./starshine-strategy.md`](./starshine-strategy.md) for the current local boundary-only status.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
