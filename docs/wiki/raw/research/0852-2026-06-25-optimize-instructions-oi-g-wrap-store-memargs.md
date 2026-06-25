# Optimize-instructions OI-G wrap-store memarg preservation

_Date:_ 2026-06-25
_Status:_ completed coverage sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

When `optimize-instructions` widens direct `i32.store*` values fed by `i32.wrap_i64`, do the source store memargs survive the rewrite?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-g-wrap-store-memarg-probe.wat`.

```wat
(module
  (memory 1)
  (func $wrap8 (param $ptr i32) (param $x i64)
    local.get $ptr
    local.get $x
    i32.wrap_i64
    i32.store8 offset=4 align=1)
  (func $wrap16 (param $ptr i32) (param $x i64)
    local.get $ptr
    local.get $x
    i32.wrap_i64
    i32.store16 offset=8 align=1)
  (func $wrap32 (param $ptr i32) (param $x i64)
    local.get $ptr
    local.get $x
    i32.wrap_i64
    i32.store offset=12 align=1))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-wrap-store-memarg-probe.wat -o -
```

Observed behavior: Binaryen rewrites the stores to `i64.store8 offset=4`, `i64.store16 offset=8 align=1`, and `i64.store32 offset=12 align=1`, preserving the source offsets and alignments while dropping the `i32.wrap_i64` child.

## Starshine behavior

`src/passes/optimize_instructions_test.mbt` now includes:

- `optimize-instructions preserves memargs when widening i32.wrap_i64 stores`

No pass implementation changed in this sub-slice. Starshine's existing direct one-use stored-value rewrite already copied the original store memarg into the widened `i64.store8` / `i64.store16` / `i64.store32` forms.

This is coverage/status evidence, not red-first behavior-failure evidence: the focused test passed immediately after being added.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-wrap-store-memarg-probe.wat -o -` passed and preserved memargs on all three widened stores.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memargs when widening i32.wrap_i64 stores*'` passed `1/1`.

## Remaining work

This closes only the memarg-preservation evidence for the already-implemented direct `i32.wrap_i64` store-widening subset. Broader `optimizeStoredValue` families, non-direct/local-carried stored values, and broader raw-gate escapes remain tracked under `[O4Z-AUDIT-OI-G]`.
