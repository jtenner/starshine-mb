# Local-subtyping iterative refinalization slice

Date: 2026-07-04

## Question

Can Starshine close the source-backed Binaryen `local-subtyping` repeated-refinement gap where rewriting one local declaration sharpens the type of a later `local.get` assignment to another local?

## Binaryen source and probe

Binaryen `version_130` `test/lit/passes/local-subtyping.wast` includes `multiple-iterations`, `multiple-iterations-refinalize`, `multiple-iterations-refinalize-call-ref`, and `multiple-iterations-refinalize-call-ref-bottom` shapes. The simplest representable family is the local chain:

```wat
(local $x funcref)
(local $y funcref)
(local $z funcref)
(local.set $x (ref.func $callee))
(local.set $y (local.get $x))
(local.set $z (local.get $y))
```

A local oracle probe used Binaryen `version_130`:

```sh
wasm-opt --all-features --local-subtyping .tmp/ls-multiple-iterations-probe.wat -S -o .tmp/ls-multiple-iterations-probe.out.wat
```

Binaryen narrowed all three locals to `(ref (exact $callee_t))`. That requires repeated analysis: the first pass can see `$x` from `ref.func`, the second sees `$y` from the now-sharper `local.get $x`, and the third sees `$z` from the now-sharper `local.get $y`.

## Starshine failure before implementation

A focused Starshine test reduced the same family to two locals because that is enough to expose the missing iteration:

- local 1 starts as `funcref` and is assigned `ref.func`;
- local 2 starts as `funcref` and is assigned `local.get 1`;
- both locals are later read so non-null dominance must remain valid.

The red-first focused command was:

```sh
moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt
```

It failed `local-subtyping iterates after local.get assignment refinalization`: local 1 narrowed to non-null exact callee type, but local 2 stayed `funcref`.

## Implementation

`local_subtyping_run_module_pass` now repeats the whole module rewrite until no declarations change, bounded by one plus the original count of reference-typed body locals. Each iteration rebuilds the module and re-lifts functions, so HOT assignment collection sees the recomputed type of `local.get` after prior declaration rewrites. This is Starshine's representation-equivalent substitute for Binaryen's explicit `ReFinalize()` loop.

The implementation still rewrites body-local declarations only. It does not add explicit get/tee retagging because emitted Starshine lib instructions have no separate get/tee result-type field; later validation and HOT lifts recompute those expression types from the rebuilt declarations.

## Validation

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` failed with local 2 remaining `funcref` instead of the expected non-null exact callee reference.
- Post-implementation focused run: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` passed `66/66`.

Broader signoff remains required before final LS closeout because EH handler-flow and the two nondefaultable-local validator/tooling boundaries are still open.

## Classification

The simple iterative-refinalization family is now implemented for Starshine-representable local-get assignment chains. This is not a Starshine divergence or a Starshine win; it is Binaryen behavior parity for the local-get repeated-refinement surface.

`multiple-iterations-refinalize-call-ref` remains unclaimed by this note unless a focused Starshine test proves `call_ref` result sharpening after function-reference declaration narrowing. The new loop should enable any shape whose HOT type recomputation can observe the changed local declaration, but only the local-get assignment chain was reduced and tested in this slice.

## Reopening criteria

Reopen the iterative-refinalization family if a reduced Binaryen `local-subtyping` case still needs another declaration-rewrite round and Starshine either stops early, leaves a dependent local broad without a documented representation blocker, emits invalid wasm, or diverges on a `call_ref`, select/LUB, bottom-call-ref, or future typed-expression family not covered by the local-get chain test.
