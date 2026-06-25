# Optimize-instructions OI-M tuple-optimization multivalue boundary

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-M]` neighbor boundary coverage for a public multivalue block under `--optimize-instructions --tuple-optimization`.

## Question

After the full `simplify-locals` neighbor boundary showed Binaryen reconstructing tuple scratch for a public multivalue block, does the dedicated `tuple-optimization` neighbor expose the same source-backed behavior, and what does Starshine currently do through the public WAT pipeline?

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-neighbor-probe.wat`

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
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-neighbor-probe.wat -o -
```

Result: Binaryen `version_130` localized the block result into tuple scratch plus scalar locals. The output introduced a `(local $scratch (tuple i32 i64))`, stored the selected first lane through `tuple.extract 2 0`, dropped `tuple.extract 2 1` from the scratch, and returned the scalar temp.

## Starshine status

Added public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps public multivalue block through tuple-optimization boundary`

Starshine currently succeeds for `optimize-instructions` followed by `tuple-optimization`, but keeps the public multivalue `block`, `drop`, `call`, and `local.get` spelling and does not introduce scalar temp locals. This keeps the tuple-optimization neighbor gap visible rather than reporting the existing one-use direct-HOT `tuple.extract(tuple.make(...))` subset as broader public tuple/multivalue reconstruction parity.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-neighbor-probe.wat -o -` passed and produced tuple scratch plus scalar-local reconstruction.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*tuple-optimization boundary*'` passed `1/1` immediately as boundary/status coverage.

## Remaining work

This slice does not implement tuple scratch localization. Public multivalue-block reconstruction, direct-HOT tuple scratch support for multi-result siblings/selected lanes, tee/drop reconstruction, and broader `tuple-optimization` / `simplify-locals` neighbor signoff remain open under `[O4Z-AUDIT-OI-M]`.
