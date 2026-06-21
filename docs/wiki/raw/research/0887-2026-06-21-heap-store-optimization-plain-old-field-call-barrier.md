# Heap-store-optimization plain old-field call barrier

Date: 2026-06-21

## Question

Does Binaryen `version_130` preserve a later `struct.set` for a plain `struct.new` when the overwritten old field has call side effects, a later constructor field also calls, and the replacement store value is a call?

This is the plain-constructor counterpart to the descriptor old-field/later-field interaction captured in `0886`.

## Binaryen oracle

Local oracle:

```sh
wasm-opt --version
```

Result:

```text
wasm-opt version 130 (version_130)
```

Probe fixture written to `.tmp/hso-probe-plain-old-field-call-barrier.wat`:

```wat
(module
  (type $s (struct (field (mut i32)) (field (mut i32))))
  (func $side (result i32)
    (i32.const 7)
  )
  (func (export "f") (local $s (ref null $s))
    (local.set $s
      (struct.new $s
        (call $side)
        (call $side)
      )
    )
    (struct.set $s 0
      (local.get $s)
      (call $side)
    )
  )
)
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-plain-old-field-call-barrier.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-plain-old-field-call-barrier.opt.wat \
  && grep -E "struct.set|struct.new|call|drop|i32.const" \
    .tmp/hso-probe-plain-old-field-call-barrier.opt.wat
```

Relevant result:

```text
  (i32.const 7)
   (struct.new $s
    (call $side)
    (call $side)
  (struct.set $s 0
   (call $side)
```

Binaryen preserves the `struct.new`, preserves the later `struct.set`, and preserves all calls. It does not introduce an old-field `drop` because no fold happens.

## Interpretation

The plain constructor follows the same later-field ordering rule as the descriptor case from `0886`: old-field side-effect preservation does not override a later-field effect barrier. Folding the later call-valued store would move the replacement call before the later constructor-field call, so Binaryen keeps the `struct.set`.

## Starshine coverage

Added focused test:

- `src/passes/heap_store_optimization_test.mbt`
  - `heap-store-optimization keeps plain old field call behind later field call barrier`

The test uses the existing call-import fixture, constructs a two-field plain `struct.new` whose overwritten field and later field are both call-valued, then writes a call-valued replacement into field `0`. The expected output keeps both `struct.new` and `struct.set` and does not introduce `drop`.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 244, passed: 244, failed: 0.
```

The new focused test passed on the first run. This slice was coverage-only: Starshine already matched Binaryen, no implementation behavior changed, and no native rebuild or direct compare was required.

## Classification

- HSO-D/E coverage-only progress.
- Binaryen behavior: preserve `struct.set` for plain old-field call plus later-field call barriers.
- Starshine behavior: already matches.
- Not a Starshine-vs-Binaryen divergence.

## Reopening criteria

Reopen this family if:

- Binaryen changes HSO to fold this shape while preserving call order through another mechanism;
- Starshine starts folding this shape and cannot prove the later-field call still precedes the replacement call;
- broader old-field/default/descriptor work changes the side-effect preservation logic in a way that could conflate old-field preservation with later-field movement barriers.
