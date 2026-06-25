# Optimize-instructions OI-G local-carried reinterpret-store boundary

Date: 2026-06-25

## Question

Should Starshine's direct reinterpret-store representation rewrite also rewrite local-carried or shared stored-value forms such as `f32.store(local.tee(f32.reinterpret_i32 x))`?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-g-local-carried-reinterpret-store-probe.wat`

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-carried-reinterpret-store-probe.wat -o -
```

Binaryen keeps the probed local-carried/shared forms:

- `f32.store` of a `local.tee` whose value is `f32.reinterpret_i32(local.get $bits)`;
- `local.set` of the reinterpreted value followed by `f32.store(local.get $tmp)`.

It does not rewrite those shapes to `i32.store` under direct `--optimize-instructions`.

## Starshine status

Starshine's current OI-G representation-store rewrite remains deliberately direct and one-use: `f32.store(f32.reinterpret_i32 x)` rewrites to `i32.store x`, and the other direct reinterpret-store pairs follow the same rule. Local-carried/shared forms are kept because rewriting them would require changing local types or duplicating/removing local traffic beyond the direct stored-value proof.

Test added:

- `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps local-carried reinterpret-store boundary`

No pass implementation changed.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-carried-reinterpret-store-probe.wat -o -` passed and kept the local-carried `f32.reinterpret_i32` / `f32.store` spellings.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local-carried reinterpret-store*'` passed `1/1`.

## Classification

Boundary-only OI-G slice. Local-carried/shared reinterpret-store spellings are source-backed keep-spelling boundaries for the probed forms, not hidden representation-store parity gaps. Reopen only with new Binaryen evidence or after Starshine has a safe local-type-changing/local-traffic localization proof for shared stored values.
