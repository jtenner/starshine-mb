# Optimize-instructions OI-G nonconstant load/call boundary

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-G]` boundary coverage for mixed load/call functions beyond the exact constant-offset escape.

## Question

After the 2026-06-24 OI-G slice allowed the exact public/raw shape `i32.const; nonzero-offset scalar load; drop; call` to escape `load-call-optimize-instructions-noop`, should nonconstant pointer loads followed by calls be treated as the same implemented parity surface?

## Binaryen oracle

Probe file: `.tmp/oi-g-load-call-nonconst-offset-boundary-probe.wat`

```wat
(module
  (import "m" "touch" (func $touch))
  (memory 1)
  (func (param $ptr i32)
    local.get $ptr
    i32.load offset=4
    drop
    call $touch))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-load-call-nonconst-offset-boundary-probe.wat -o -
```

Result: Binaryen `version_130` kept the nonconstant `local.get $ptr` address, the `i32.load offset=4`, the `drop`, and the following `call $touch`. It did not fold the static offset into the nonconstant address.

## Starshine status

Added public-pipeline boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps nonconstant load-call offset boundary`

The test verifies that Starshine still reports `load-call-optimize-instructions-noop` for the nonconstant load/call mix, keeps the `local.get`, keeps `i32.load offset=4`, and keeps the following call. This locks the existing raw-gate decision as a source-backed boundary rather than treating the narrower constant-address escape as broad mixed load/call parity.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-load-call-nonconst-offset-boundary-probe.wat -o -` passed and kept the source spelling.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nonconstant load-call offset boundary*'` passed `1/1` immediately as boundary coverage.

## Remaining work

Broader mixed load/call functions still remain behind `load-call-optimize-instructions-noop`. The only implemented raw-gate escape in this family is the exact constant-address, nonzero-offset scalar-load/drop/direct-call shape; any additional escape class needs separate Binaryen/source evidence and safety proof.
