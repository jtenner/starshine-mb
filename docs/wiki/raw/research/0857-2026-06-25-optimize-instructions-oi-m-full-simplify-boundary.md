# Optimize-instructions OI-M full simplify-locals multivalue boundary

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-M]` neighbor/boundary coverage for a public multivalue block under `--optimize-instructions --simplify-locals`.

## Question

Can Starshine claim that the covered direct-HOT single-result `tuple.extract(tuple.make(...))` localization survives the full `simplify-locals` neighbor, not just `simplify-locals-nostructure`?

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-full-simplify-neighbor-probe.wat`

```wat
(module
  (func $side (result i64)
    i64.const 9)
  (func (param $x i32) (result i32)
    (block (result i32 i64)
      local.get $x
      call $side)
    drop))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --simplify-locals .tmp/oi-m-tuple-full-simplify-neighbor-probe.wat -o -
```

Result: Binaryen `version_130` localizes the multivalue block result through a `(tuple i32 i64)` scratch local and a scalar `i32` scratch local, drops the non-selected tuple lane, and returns the scalar scratch. This is the broader tuple-scratch reconstruction family, not the narrow direct-HOT single-result tuple child helper Starshine currently implements.

## Starshine status

Added public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block through full simplify-locals boundary`

The test runs `pass_test_run_pipeline` on the public WAT shape with `optimize-instructions` followed by `simplify-locals`. Starshine succeeds but keeps the multivalue `block` / `drop` / `call` / `local.get` spelling and does not introduce the Binaryen-style scalar temp local. This prevents the existing `simplify-locals-nostructure` neighbor coverage from being overstated as full `simplify-locals` tuple-scratch parity.

A direct-HOT replay of the OI-localized tuple block was also checked during the slice and failed before full `simplify-locals` with `verify before simplify-locals: InvalidChildRef(3, 0, 0)`. Treat that as a separate verifier/fixture boundary, not as successful full-neighbor evidence.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --simplify-locals .tmp/oi-m-tuple-full-simplify-neighbor-probe.wat -o -` passed and produced tuple-scratch plus scalar-local reconstruction.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*full simplify-locals neighbor*'` first failed on the direct-HOT replay with `InvalidChildRef(3, 0, 0)`, confirming the attempted fixture was not valid full-neighbor evidence.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*public multivalue block through full simplify-locals boundary*'` passed `1/1` after the slice was reframed as public-pipeline boundary coverage.

## Remaining work

Full tuple-scratch localization remains open. A future implementation should either add a safe public/HOT tuple-scratch localizer that reconstructs selected values and drops non-selected lanes like Binaryen, or fix the direct-HOT verifier/fixture path before claiming full `simplify-locals` neighbor parity. The earlier `simplify-locals-nostructure` coverage remains only a covered single-result effectful-sibling subset.
