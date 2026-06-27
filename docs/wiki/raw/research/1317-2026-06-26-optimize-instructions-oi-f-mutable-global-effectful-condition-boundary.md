# Optimize-instructions OI-F mutable-global identical select arms across effectful conditions

## Slice

This OI-F correctness slice tightens the effectful-condition identical select-arm cleanup so Starshine no longer treats `global.get` leaves as safe to move across an effectful condition.

For a mutable global, the original `select (global.get $g) (global.get $g) (call ...)` reads both arms before the condition call. Rewriting that shape to `drop(call); global.get $g` can read the global after the call, which is not equivalent when the call may mutate the global. The fix removes `GlobalGet` from the shared cross-effect leaf predicate while keeping the existing side-effect-free-condition same-global fold.

## Binaryen oracle

Probe: `.tmp/oi-select-mutable-global-effectful-condition-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-mutable-global-effectful-condition-probe.wat -o .tmp/oi-select-mutable-global-effectful-condition-probe.out.wat
```

Result: passed. Binaryen `version_130` kept the `select`, both `global.get $g` arms, and the effectful condition call.

A second import-backed probe `.tmp/oi-select-mutable-global-import-condition-probe.wat` produced the same Binaryen keep-spelling result, but Starshine's WAT hot-lift test path does not accept missing imported function bodies for this focused fixture. The committed Starshine test therefore constructs the HOT shape directly with a call condition.

## Starshine implementation and coverage

Files:

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`

Focused test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*mutable global select arms*'
```

Red-first result: failed before the implementation because Starshine folded the select.

Post-fix result: passed `1/1` after `optimize_instructions_is_shared_cross_safe_leaf` stopped treating `GlobalGet` as cross-effect safe.

## Boundaries

This is a correctness narrowing, not a broad new identical-arm implementation.

Still covered:

- direct identical `global.get` select-arm folding when the condition is side-effect-free;
- direct local/constant/ref leaves and the already documented nontrapping reorderable expression shells for effectful-condition identical-arm cleanup.

Not claimed:

- moving mutable or potentially mutable global reads across effectful/trapping conditions;
- immutable-global-specific effect analysis;
- arbitrary structural expression equality;
- tuple-scratch localization for preserving pre-condition global reads through an effectful condition.
