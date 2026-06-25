# Optimize-instructions OI-G multi-use wrap-store boundary

_Date:_ 2026-06-25
_Status:_ completed boundary sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Does Binaryen's direct `i32.wrap_i64` stored-value widening apply when the wrapped value is local-carried or shared with another use?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-g-wrap-store-multiuse-probe.wat`.

```wat
(module
  (memory 1)
  (func (param $ptr i32) (param $x i64) (result i32) (local $w i32)
    local.get $ptr
    local.get $x
    i32.wrap_i64
    local.tee $w
    i32.store8
    local.get $w))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-wrap-store-multiuse-probe.wat -o -
```

Observed behavior: Binaryen keeps the `local.tee`-carried `i32.wrap_i64` value and the `i32.store8` spelling. It does not introduce a separate widened `i64.store8` while preserving the other `i32` use.

## Starshine behavior

`src/passes/optimize_instructions_test.mbt` now includes:

- `optimize-instructions intentionally keeps multi-use i32.wrap_i64 store boundary`

No pass implementation changed in this sub-slice. Starshine's direct stored-value widening helper remains one-use-only, matching the probed Binaryen keep-spelling behavior for a shared/local-carried wrap.

This is boundary/status coverage, not red-first behavior-failure evidence: the focused test passed immediately after being added.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-wrap-store-multiuse-probe.wat -o -` passed and kept the `i32.wrap_i64` / `local.tee` / `i32.store8` shape.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-use i32.wrap_i64 store boundary*'` passed `1/1`.

## Remaining work

This closes only the local-carried/shared boundary for the direct `i32.wrap_i64` store-widening subset. Broader `optimizeStoredValue` shapes, additional effect/trap negatives, wider raw-gate escapes, and non-local memory/load-store canonicalization remain tracked under `[O4Z-AUDIT-OI-G]`.
