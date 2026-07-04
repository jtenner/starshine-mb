# Local-subtyping select/LUB refinalization slice

Date: 2026-07-04

## Question

Can Starshine close the Binaryen `local-subtyping` `multiple-iterations-refinalize` shape where rewriting two function-reference local declarations sharpens an untyped `select` to a non-null common function-reference LUB, which then lets a dependent local narrow?

## Binaryen source and probe

Binaryen `version_130` `test/lit/passes/local-subtyping.wast` includes this source-backed shape:

```wat
(func $multiple-iterations-refinalize (param $i i32)
  (local $x funcref)
  (local $y funcref)
  (local $z funcref)
  (local.set $x (ref.func $i32))
  (local.set $y (ref.func $i64))
  (local.set $z
    (select
      (local.get $x)
      (local.get $y)
      (local.get $i))))
```

A local oracle probe used Binaryen `version_130`:

```sh
wasm-opt --version
wasm-opt --all-features --local-subtyping .tmp/ls-select-lub-probe.wat -S -o .tmp/ls-select-lub-probe.out.wat
```

The local tool reported `wasm-opt version 130 (version_130)`. The optimized probe narrows `$x` to `(ref $i32_func)`, `$y` to `(ref $i64_func)`, rewrites the `select` to `(select (result (ref func)) ...)`, and narrows `$z` to `(ref func)`.

## Starshine failure before implementation

The focused Starshine reduction uses imported `$i32` and `$i64` functions declared in a declarative element segment so `ref.func` is valid. The source body keeps the Binaryen lit-style untyped `select` and declares all three body locals as `funcref`.

The red-first focused command was:

```sh
moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt
```

Before the implementation, the new `local-subtyping iterates after select LUB refinalization` test failed: after using a typed-select staging version to get past Starshine's HOT lift boundary, `$x` and `$y` narrowed to exact imported function refs but `$z` stayed broad `funcref` instead of the expected non-null `(ref func)`. The untyped source-shaped version also exposed that Starshine needed a pre-lift typed-select repair for this refinalization family.

## Implementation

`src/passes/local_subtyping.mbt` now has a narrow select-refinalization repair before HOT assignment collection:

- compute a reference LUB for adjacent `local.get`, `local.get`, condition, `select` stack patterns;
- annotate untyped reference selects, or sharpen a typed select annotation, when the inferred LUB is a subtype of the existing annotation;
- support the function-reference LUB needed by the Binaryen lit shape, with small generic fallbacks for extern/eq/any abstract heaps;
- recurse through block, loop, if, and try_table bodies without claiming broader CFG or handler-flow propagation;
- rely on the existing bounded module rewrite/re-lift loop so the first iterations can narrow `$x`/`$y`, a later iteration can sharpen the `select` annotation to non-null `(ref func)`, and the final iteration can narrow `$z` from the updated select result type.

This is deliberately not a broad expression-retag pass. It handles a source-backed adjacent-local-get select/LUB shape needed by Binaryen's `multiple-iterations-refinalize` lit test.

## Validation

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` failed the new select/LUB test with `$z` remaining broad `funcref` after `$x` and `$y` narrowed.
- Binaryen probe: `wasm-opt --version` reported `wasm-opt version 130 (version_130)`; `wasm-opt --all-features --local-subtyping .tmp/ls-select-lub-probe.wat -S -o .tmp/ls-select-lub-probe.out.wat` narrowed `$x`, `$y`, and `$z` as described above.
- Post-implementation focused run: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` passed `67/67`.
- Slice signoff: `moon fmt` passed; `moon info` passed with pre-existing warnings; focused LS tests passed `67/67`; full `moon test` passed `7383/7383`.

No native `src/cmd` build or compare-pass lanes were run in this slice because LS still has open residuals and final closeout evidence must be refreshed after the remaining behavior families are resolved or classified.

## Classification

The `multiple-iterations-refinalize` select/LUB family is now implemented for the source-backed adjacent-local-get shape from Binaryen's lit test. This is Binaryen behavior parity, not a Starshine divergence or Starshine win.

The remaining repeated-refinalization residual is now focused on `call_ref` and bottom-call-ref shapes. This note does not claim those are fixed: they may require `call_ref` type-immediate/result repair or a precise Starshine representation/tooling blocker.

## Reopening criteria

Reopen the select/LUB refinalization family if a reduced Binaryen `local-subtyping` case needs a select result to sharpen after local declaration rewrites and Starshine leaves the dependent local broad, emits invalid wasm, fails to type an untyped reference select that Binaryen handles, or requires a non-adjacent/select-control shape outside the documented local-get LUB subset.
