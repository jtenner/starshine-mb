# Optimize-instructions OI-G global bulk-memory raw gate

Date: 2026-06-25

## Scope

This OI-G slice widens the stack-carried tiny bulk-memory raw-gate escape for flat `memory.copy` / size-1 `memory.fill` functions. The newly covered operand form is `global.get` used directly as a bulk-memory address/value operand, or as the evaluated argument to a one-result direct call operand.

The change is deliberately limited to the tiny bulk-memory matcher. It does **not** classify `global.get` as a generic commutative stack-call binop operand, because reordering `global.get` across a call would be unsafe when the call may mutate the global.

## Binaryen oracle

Probe: `.tmp/oi-g-global-bulk-memory-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-global-bulk-memory-probe.wat -o -` lowers the probed mutable-global shape:

- `global.get $d; call $dst; global.get $s; call $src; i32.const 1; memory.copy` becomes `i32.load8_u` plus `i32.store8` while preserving the `global.get` before each call.
- `global.get $d; global.get $v; call $val; i32.const 1; memory.fill` becomes `i32.store8` while preserving address/value evaluation order.

## Starshine change

`src/passes/pass_manager.mbt` now uses a bulk-memory-specific stack operand predicate that accepts `global.get` in addition to the existing local/constant operands. The direct-call operand parser still requires a one-result call whose parameter count exactly matches the preceding run of accepted stack operands.

`src/passes/optimize_instructions_test.mbt` adds public-pipeline coverage:

- `optimize-instructions expands stack-carried global bulk-memory calls`

Red-first evidence: the focused test failed before implementation with `stack-carried-effect-optimize-instructions-noop`. After the raw-gate matcher change, the same test passes and the pretty output contains no `memory.copy` / `memory.fill`, contains `global.get`, and contains `i32.load8u` plus two `i32.store8` operations.

## Remaining boundaries

This does not close OI-G. Broader stack-carried result-bearing functions, control-bearing operands, nonconstant sizes, wider non-local `memory.fill`, zero-size trap-relaxed cleanup, non-flat/localizing bulk-memory forms, and additional load/store canonicalization families remain open. `global.get` in other raw-gate recognizers remains intentionally unclaimed until each recognizer proves order safety separately.
