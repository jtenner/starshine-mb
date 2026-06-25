# Optimize-instructions OI-G local-carried representation-load boundary

Date: 2026-06-25

## Question

Should Starshine's representation-load rewrites cover load results that have been carried through a local or shared with another use?

## Binaryen `version_130` evidence

Probes:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-shared-reinterpret-load-probe.wat -o -
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-carried-extend-load-probe.wat -o -
```

Binaryen keeps the probed local-carried spellings:

- `local.tee` around an `i32.load` followed by `f32.reinterpret_i32` remains a reinterpret of the tee/local value.
- `local.tee` around an `i32.load` followed by `i64.extend_i32_u`, then a later `local.get` plus `i64.extend_i32_s`, keeps the extend operations.

This differs from the already implemented direct one-use child forms, where Binaryen and Starshine rewrite full-width reinterpret loads to representation loads and `i64.extend_i32_*` over i32 loads to `i64.load32_*` / narrow i64 loads.

## Starshine status

Starshine's OI-G implementation intentionally requires the load child to be live, direct, and one-use before rewriting a reinterpret or `i64.extend_i32_*` load result. A new public-pipeline boundary test covers the local-carried/shared spelling:

- `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps local-carried representation-load boundary`

The test asserts that `local.tee`, `f32.reinterpret_i32`, `i64.extend_i32_u`, `i64.extend_i32_s`, and the original `i32.load` remain, and that Starshine does not introduce `f32.load` or `i64.load32*` for the local-carried forms.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-shared-reinterpret-load-probe.wat -o -` passed and kept the local-carried reinterpret spelling.
- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-carried-extend-load-probe.wat -o -` passed and kept the local-carried extend spelling.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local-carried representation-load*'` passed `1/1`.

## Classification

Boundary-only OI-G slice. Local-carried/shared representation-load rewrites are not counted as current parity gaps for the probed shapes. Reopen only if a future Binaryen source/oracle refresh rewrites these local-carried forms, or if Starshine adds a proven local/load ownership analysis that can rewrite them without duplicating or reordering load effects.
