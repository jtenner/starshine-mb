---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../binaryen/passes/code-pushing/index.md
---

# Code-pushing `br_on_null` prefix-payload boundary

## Question

Does Binaryen v130 treat a two-value stack prefix before `br_on_null` to a result block as a `code-pushing` movement point for an earlier pure single-first-assignment local set?

## Probe

Local tool:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Reduced input saved locally as `.tmp/o4z-audit-cp-uu/br-on-null-prefix.wat`:

```wat
(module
  (func (param $p externref) (result i32) (local $x i32)
    (block $exit (result i32)
      i32.const 7
      local.set $x
      i32.const 42
      local.get $p
      br_on_null $exit
      drop
      drop
      local.get $x
      drop
      i32.const 13)))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-uu/br-on-null-prefix.wat \
  -o .tmp/o4z-audit-cp-uu/br-on-null-prefix.wasm
wasm-tools validate --features all \
  .tmp/o4z-audit-cp-uu/br-on-null-prefix.wasm
wasm-opt --all-features \
  .tmp/o4z-audit-cp-uu/br-on-null-prefix.wat \
  --code-pushing -S \
  -o .tmp/o4z-audit-cp-uu/br-on-null-prefix.opt.wat
```

All commands passed.

## Finding

Binaryen validates the shape but keeps the pure `local.set $x` before the `br_on_null` prefix-payload/control rewrite. The optimized text introduces scratch locals and an inner control wrapper for the branch, with `local.set $x` still before the scratch/control sequence.

Classification: narrow Binaryen-stationary boundary, not a positive movement gap.

## Starshine status

Starshine already supports dropped zero-arity-label `br_on_null` movement for the narrower aggregate-safe family. This probe does not widen that positive family. The repo WAT parser/HOT test surface does not currently provide a simple public fixture for this exact multi-value `br_on_null` prefix-payload shape, so this slice records source-backed oracle evidence without adding a focused boundary test. Reopen if a HOT/lower fixture can represent the exact branch/fallthrough stack shape, or if a future Binaryen version moves the pure set in this probe.

## Reopening criteria

- Binaryen v130-equivalent source/probe evidence shows movement for this exact `br_on_null` prefix-payload shape.
- Starshine grows a reliable public/HOT fixture surface for multi-value `br_on_null` branch/fallthrough payloads and the no-mutation boundary can be locked directly.
- A generated compare lane exposes a semantic mismatch attributable to `br_on_null` prefix-payload movement rather than local-cleanup/lowering debris.
