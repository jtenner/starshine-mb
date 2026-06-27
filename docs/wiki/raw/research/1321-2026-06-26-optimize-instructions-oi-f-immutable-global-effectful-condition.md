# Optimize-instructions OI-F immutable-global identical select arms across effectful conditions

## Slice

This OI-F parity slice adds the immutable-global half of the effectful-condition identical select-arm rule.

For an immutable global, Binaryen `version_130` rewrites `select (global.get $g) (global.get $g) (call ...)` to `drop(call); global.get $g`. Unlike mutable globals, the condition call cannot change the immutable global value, so reading the global after the dropped condition preserves observable behavior. Starshine now admits this narrow same-global case only when the current module context proves the target global is immutable.

## Binaryen oracle

Probe: `.tmp/oi-select-immutable-global-effectful-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-immutable-global-effectful-probe.wat -o .tmp/oi-select-immutable-global-effectful-probe.out.wat
```

Result: passed. Binaryen folded the immutable-global function to a dropped effect call followed by one `global.get $g`, while the mutable-global comparison function kept the original `select` with both `global.get $m` arms.

## Starshine implementation and coverage

Files:

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*immutable global select arms*'
```

Red-first result: failed before the implementation because Starshine kept the `select` and both immutable `global.get` arms.

Post-fix result: passed `1/1` after `optimize_instructions_select_identical_immutable_global_arms` started consulting `HotModuleContext` and admitting only same-index immutable `global.get` arms for the effectful-condition fold.

## Boundaries

This is a narrow immutable-global proof, not a general global-read or structural-expression rule.

Still kept:

- mutable `global.get` arms across effectful conditions, covered by `docs/wiki/raw/research/1317-2026-06-26-optimize-instructions-oi-f-mutable-global-effectful-condition-boundary.md`;
- unknown-module-context global arms, because the pass cannot prove immutability;
- arbitrary global expressions or reordered trapping/effectful arms.

Still open:

- broader immutable-global effect analysis for nested expressions;
- tuple-scratch localization or pre-condition local capture for mutable globals;
- public text/pipeline coverage for the call-condition variant once HOT call result typing through the local WAT path is suitable for this exact shape.
