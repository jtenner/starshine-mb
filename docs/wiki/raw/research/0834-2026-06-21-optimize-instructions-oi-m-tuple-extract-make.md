# Optimize-instructions OI-M tuple.extract(tuple.make)

_Date:_ 2026-06-21
_Status:_ completed first `[O4Z-AUDIT-OI-M]` implementation sub-slice

## Scope

This slice starts `[O4Z-AUDIT-OI-M]` with a narrow, locally representable tuple/multivalue rewrite:

- fold a direct one-use `tuple.extract(tuple.make(...))` to the selected tuple child;
- require every non-selected tuple child to be side-effect-free;
- keep effectful non-selected siblings unchanged until Starshine has a safe tuple-localizing lowering that can preserve the same evaluation effects Binaryen preserves with locals/drops.

This does not close the multivalue surface. It does not implement Binaryen's broader tee/drop reconstruction, multi-use tuple rewrites, effectful sibling localization, or interactions with neighboring `tuple-optimization` / `simplify-locals` cleanup.

## Binaryen oracle

Primary source ownership remains the `version_130` source/lit matrix: [`../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md), which maps `visitTupleExtract(...)` and the `optimize-instructions-multivalue.wast` lit family to `[O4Z-AUDIT-OI-M]`.

Local probe fixture: `.tmp/oi-m-tuple-probe.wat`.

```wat
(module
  (func $effect (import "m" "touch") (result i64))
  (func $pure (export "pure") (result i32)
    (tuple.extract 2 0
      (tuple.make 2
        (i32.const 7)
        (i64.const 9))))
  (func $effectful-sibling (export "effectful_sibling") (result i32)
    (tuple.extract 2 0
      (tuple.make 2
        (i32.const 7)
        (call $effect))))
)
```

Command:

```sh
wasm-opt .tmp/oi-m-tuple-probe.wat --enable-multivalue -S --optimize-instructions -o -
```

Observed `version_130` behavior: direct `--optimize-instructions` lowers both probed tuple extracts into local tee/drop reconstruction. For the pure case it emits a temp local, drops a `local.tee` of the selected value, then returns `local.get`; for the effectful-sibling case it also preserves the sibling `call $effect` with a `drop(call)` before returning the selected value. This proves upstream OI ownership and shows Binaryen's broader localizing capability.

Command:

```sh
wasm-opt .tmp/oi-m-tuple-probe.wat --enable-multivalue -S -O --optimize-instructions -o -
```

Observed `version_130` O4z-style behavior: after surrounding cleanup, the pure export returns `i32.const 7`, and the effectful-sibling export preserves `drop(call $effect)` before returning `i32.const 7`.

## Starshine change

Implementation: `src/passes/optimize_instructions.mbt` adds `optimize_instructions_try_fold_tuple_extract_tuple_make(...)` and wires it into the `TupleExtract` visitor arm.

The helper requires:

- a direct `TupleExtract` with one tuple child;
- a live direct `TupleMake` producer;
- exactly one use of the tuple producer;
- an in-range extract index;
- pure non-selected tuple children.

When those checks hold, Starshine replaces the extract with the selected tuple child. The selected value may be effectful because the tuple has one use and the selected value's evaluation remains represented by the replacement. Effectful non-selected siblings stay unchanged because dropping the tuple would otherwise drop or reorder effects.

## Tests

`src/passes/optimize_instructions_test.mbt` adds direct-HOT coverage:

- positive: `tuple.extract` index `0` over one-use `tuple.make(local.get 0, i64.const 9)` forwards the selected `local.get`;
- boundary: `tuple.extract` index `0` over one-use `tuple.make(local.get 0, local.tee 1 (i64.const 9))` remains a `TupleExtract`, explicitly preserving the effectful non-selected sibling until localization exists.

Red-first evidence: before implementation,

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*tuple.extract*'
```

failed the positive test with `expected tuple.extract(tuple.make) to forward selected local.get`; the boundary test passed.

After implementation, the same command passed `2/2`.

Additional signoff for the committed slice:

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `219/219`.
- `moon fmt` passed.
- `moon test src/passes` passed `2749/2749`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct count-1 compare smoke:

  ```sh
  rm -rf .tmp/pass-fuzz-optimize-instructions-oi-m-tuple-1 && \
    bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed \
      --out-dir .tmp/pass-fuzz-optimize-instructions-oi-m-tuple-1 --jobs auto \
      --starshine-bin target/native/release/build/cmd/cmd.exe
  ```

  compared `1/1`, with normalized matches `0`, cleanup-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, wasm-smith cache `0` hits / `0` misses, Binaryen cache `1` hit / `0` misses, and Binaryen failure cache `0` hits / `0` misses. Agent classification: unrelated raw output-shape mismatch; grepping the failure artifacts found no `tuple`, `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Remaining OI-M work

Open `[O4Z-AUDIT-OI-M]` work includes Binaryen's broader tuple tee/drop reconstruction, effectful non-selected sibling localization, multi-use tuple proofs where safe, public text/binary fixture coverage if Starshine gains a textual tuple surface, and interaction checks with `tuple-optimization` / `simplify-locals` neighbors.
