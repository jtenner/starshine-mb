---
kind: research
status: supported
last_reviewed: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-F identical pure `select` arms

## Question

Does Binaryen `version_130` `--optimize-instructions` fold `select` when both value arms are the same pure expression, and can Starshine safely cover a narrow HOT subset?

## Oracle

Probes: `.tmp/oi-select-same-arms-probe.wat`, `.tmp/oi-select-float-arms-probe.wat`, `.tmp/oi-select-global-arms-probe.wat`, `.tmp/oi-select-refnull-arms-probe.wat`, `.tmp/oi-select-reffunc-arms-probe.wat`, `.tmp/oi-select-refi31-arms-probe.wat`, `.tmp/oi-select-refi31-add-arms-probe.wat`, `.tmp/oi-select-refi31-sub-arms-probe.wat`, `.tmp/oi-select-refi31-mul-arms-probe.wat`, `.tmp/oi-select-refi31-and-arms-probe.wat`, `.tmp/oi-select-refi31-or-xor-arms-probe.wat`, `.tmp/oi-select-refi31-shift-arms-probe.wat`, `.tmp/oi-select-refi31-unary-arms-probe.wat`, `.tmp/oi-select-refi31-signext-arms-probe.wat`, `.tmp/oi-select-refi31-truncsat-arms-probe.wat`, `.tmp/oi-select-refi31-reinterpret-arms-probe.wat`, and `.tmp/oi-select-refi31-wrap-arms-probe.wat`.

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-same-arms-probe.wat -o .tmp/oi-select-same-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-float-arms-probe.wat -o .tmp/oi-select-float-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-global-arms-probe.wat -o .tmp/oi-select-global-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refnull-arms-probe.wat -o .tmp/oi-select-refnull-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-reffunc-arms-probe.wat -o .tmp/oi-select-reffunc-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-arms-probe.wat -o .tmp/oi-select-refi31-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-add-arms-probe.wat -o .tmp/oi-select-refi31-add-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-sub-arms-probe.wat -o .tmp/oi-select-refi31-sub-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-mul-arms-probe.wat -o .tmp/oi-select-refi31-mul-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-and-arms-probe.wat -o .tmp/oi-select-refi31-and-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-or-xor-arms-probe.wat -o .tmp/oi-select-refi31-or-xor-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-shift-arms-probe.wat -o .tmp/oi-select-refi31-shift-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-unary-arms-probe.wat -o .tmp/oi-select-refi31-unary-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-signext-arms-probe.wat -o .tmp/oi-select-refi31-signext-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-truncsat-arms-probe.wat -o .tmp/oi-select-refi31-truncsat-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-reinterpret-arms-probe.wat -o .tmp/oi-select-refi31-reinterpret-arms-probe.out.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-refi31-wrap-arms-probe.wat -o .tmp/oi-select-refi31-wrap-arms-probe.out.wat
```

Result: Binaryen folds identical pure local, global, constant, `ref.null`, `ref.func`, and direct `ref.i31` arms to the selected value, but keeps the effectful-call-arm sibling spelling. The exact output used generated function names, but the behavioral point is that `(select (i32.const 7) (i32.const 7) cond)` becomes `i32.const 7`, `(select (local.get 1) (local.get 1) cond)` becomes `local.get 1`, `(select (global.get $g) (global.get $g) cond)` becomes `global.get $g`, a follow-up float probe folds identical f32/f64 constants when the condition is also pure, a follow-up null-reference probe folds identical `ref.null func` / `ref.null eq` arms to `ref.null nofunc` / `ref.null none`, a follow-up function-reference probe folds identical `ref.func $target` arms to that same `ref.func`, a follow-up i31 probe folds identical direct `ref.i31(i32.const 7)` arms to that same constructor, and later i31 probes fold identical direct `ref.i31(i32.add(local.get 0, i32.const 1))`, `ref.i31(i32.sub(local.get 0, i32.const 1))`, `ref.i31(i32.mul(local.get 0, i32.const 3))`, `ref.i31(i32.and(local.get 0, i32.const 7))`, `ref.i31(i32.or(local.get 0, i32.const 7))`, `ref.i31(i32.xor(local.get 0, i32.const 7))`, `ref.i31(i32.shl(local.get 0, i32.const 1))`, `ref.i31(i32.shr_u(local.get 0, i32.const 1))`, `ref.i31(i32.shr_s(local.get 0, i32.const 1))`, `ref.i31(i32.rotl(local.get 0, i32.const 1))`, `ref.i31(i32.rotr(local.get 0, i32.const 1))`, `ref.i31(i32.eqz(local.get 0))`, `ref.i31(i32.clz(local.get 0))`, `ref.i31(i32.ctz(local.get 0))`, `ref.i31(i32.popcnt(local.get 0))`, `ref.i31(i32.extend8_s(local.get 0))`, `ref.i31(i32.extend16_s(local.get 0))`, `ref.i31(i32.trunc_sat_f32_s(local.get 0))`, `ref.i31(i32.trunc_sat_f64_u(local.get 0))`, and later probes fold identical direct `ref.i31(i32.reinterpret_f32(local.get 0))` and `ref.i31(i32.wrap_i64(local.get 0))` arms to the same constructor shell.

## Starshine change

Added red-first coverage for direct local-get, direct global-get, direct float-constant, direct `ref.null`, direct `ref.func`, and direct `ref.i31` shapes:

- `optimize-instructions folds select with identical pure local arms`
- `optimize-instructions folds select with identical pure global arms`
- `optimize-instructions folds select with identical pure float constant arms`
- `optimize-instructions folds select with identical pure ref.null arms`
- `optimize-instructions folds select with identical pure ref.func arms`
- `optimize-instructions folds select with identical pure ref.i31 arms`
- `optimize-instructions keeps identical select arms when condition may trap`

The local-get test failed before the first implementation because Starshine kept the `select`. The float-constant test later failed before the narrower follow-up because Starshine only recognized local/i32/i64 identical arms. The global-get test later failed before the direct-global follow-up because the identity helper did not compare same-global arms. The `ref.null` test later failed before the direct-null follow-up because HOT `ref.null` arms carry different source heap immediates even when the selected result type is the same null value. The `ref.func` test later failed before the direct-function-reference follow-up because the helper did not compare same target functions. The `ref.i31` test later failed before the direct-i31 follow-up because the helper did not treat the i31 constructor as a pure direct comparable arm; the same test failed again before the add-payload follow-up because the direct-i31 helper only compared local and constant payloads, failed again before the sub-payload follow-up because the payload-shell proof only accepted `i32.add`, failed again before the mul-payload follow-up because the payload-shell proof only accepted add/sub, failed again before the and-payload follow-up because the payload-shell proof only accepted add/sub/mul, failed again before the or/xor follow-up because the payload-shell proof only accepted add/sub/mul/and, failed again before the shift/rotate follow-up because the payload-shell proof did not yet accept shift/rotate local-constant shells, failed again before the unary-payload follow-up because the direct-i31 helper did not accept `i32.eqz`, `i32.clz`, `i32.ctz`, or `i32.popcnt` local-payload shells, and failed again before the sign-extension-payload follow-up because the direct-i31 helper did not accept `i32.extend8_s` or `i32.extend16_s` local-payload shells, and failed again before the trunc-sat-payload follow-up because it did not accept direct nontrapping `i32.trunc_sat_f32_*` / `i32.trunc_sat_f64_*` local-payload shells, failed again before the reinterpret-payload follow-up because it did not accept direct nontrapping `i32.reinterpret_f32` local-payload shells, and failed again before the wrap-payload follow-up because it did not accept direct nontrapping `i32.wrap_i64` local-payload shells. The implementation now folds only when:

- the true and false arms are side-effect-free;
- the true and false arms are the same direct `local.get`, same direct `global.get`, same-result-type direct `ref.null`, same-target same-result-type direct `ref.func`, same direct `ref.i31` with identical pure local/i32-constant payloads, identical same-order `i32.add(local.get, i32.const)` / `i32.sub(local.get, i32.const)` / `i32.mul(local.get, i32.const)` / `i32.and(local.get, i32.const)` / `i32.or(local.get, i32.const)` / `i32.xor(local.get, i32.const)` / `i32.shl(local.get, i32.const)` / `i32.shr_u(local.get, i32.const)` / `i32.shr_s(local.get, i32.const)` / `i32.rotl(local.get, i32.const)` / `i32.rotr(local.get, i32.const)` payload shells, or identical `i32.eqz(local.get)` / `i32.clz(local.get)` / `i32.ctz(local.get)` / `i32.popcnt(local.get)` / `i32.extend8_s(local.get)` / `i32.extend16_s(local.get)` / `i32.trunc_sat_f32_s(local.get)` / `i32.trunc_sat_f32_u(local.get)` / `i32.trunc_sat_f64_s(local.get)` / `i32.trunc_sat_f64_u(local.get)` / `i32.reinterpret_f32(local.get)` / `i32.wrap_i64(local.get)` payload shells, i32 constant, i64 constant, f32 constant, or f64 constant;
- the condition is side-effect-free, so dropping it cannot remove a trap or effect.

This intentionally avoids broader expression structural equality, NaN-payload equality claims, non-null reference value equality beyond identical direct `ref.func` target constants and identical direct `ref.i31` payloads, global mutability/value-equivalence claims beyond same-index `global.get`, and effectful/trapping conditions until separately proven.

## Validation

- Red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*pure local arms*'` failed `0/1`.
- Float follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float constant arms*'` failed `0/1`.
- Global follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*global arms*'` failed `0/1`.
- Ref-null follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.null arms*'` failed `0/1`.
- Ref-func follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func arms*'` failed `0/1`.
- Ref-i31 follow-up red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1`.
- Oracle commands above passed, including `.tmp/oi-select-float-arms-probe.wat`, `.tmp/oi-select-global-arms-probe.wat`, `.tmp/oi-select-refnull-arms-probe.wat`, `.tmp/oi-select-reffunc-arms-probe.wat`, `.tmp/oi-select-refi31-arms-probe.wat`, and `.tmp/oi-select-refi31-add-arms-probe.wat`.
- Post-implementation focused local test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*identical*select*'` passed `1/1`.
- Post-implementation focused float test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*float constant arms*'` passed `1/1`.
- Post-implementation focused global test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*global arms*'` passed `1/1`.
- Post-implementation focused ref-null test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.null arms*'` passed `1/1`.
- Post-implementation focused ref-func test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func arms*'` passed `1/1`.
- Post-implementation focused ref-i31 test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` passed `1/1` after the direct const/local-payload change.
- Add-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation, then passed `1/1` after the narrow `i32.add(local.get, i32.const)` payload-shell comparison.
- Sub-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation, then passed `1/1` after adding the narrow same-order `i32.sub(local.get, i32.const)` payload-shell comparison.
- Mul-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation, then passed `1/1` after adding the narrow same-order `i32.mul(local.get, i32.const)` payload-shell comparison.
- And-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation, then passed `1/1` after adding the narrow same-order `i32.and(local.get, i32.const)` payload-shell comparison.
- Or/xor-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.or` payload case, then passed `1/1` after adding the narrow same-order `i32.or(local.get, i32.const)` and `i32.xor(local.get, i32.const)` payload-shell comparisons.
- Shift/rotate-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.shl` payload case, then passed `1/1` after adding the narrow same-order `i32.shl(local.get, i32.const)`, `i32.shr_u(local.get, i32.const)`, `i32.shr_s(local.get, i32.const)`, `i32.rotl(local.get, i32.const)`, and `i32.rotr(local.get, i32.const)` payload-shell comparisons.
- Unary-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.eqz` payload case, then passed `1/1` after adding the narrow direct `i32.eqz(local.get)`, `i32.clz(local.get)`, `i32.ctz(local.get)`, and `i32.popcnt(local.get)` payload-shell comparisons.
- Sign-extension-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.extend8_s` payload case, then passed `1/1` after adding the narrow direct `i32.extend8_s(local.get)` and `i32.extend16_s(local.get)` payload-shell comparisons. Binaryen oracle `.tmp/oi-select-refi31-signext-arms-probe.wat` passed and folded both shapes.
- Trunc-sat-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.trunc_sat_f32_s` payload case, then passed `1/1` after adding direct nontrapping `i32.trunc_sat_f32_s` / `i32.trunc_sat_f32_u` / `i32.trunc_sat_f64_s` / `i32.trunc_sat_f64_u` local-payload shell comparisons. Binaryen oracle `.tmp/oi-select-refi31-truncsat-arms-probe.wat` passed and folded the probed f32 and f64 shapes.
- Reinterpret-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.reinterpret_f32` payload case, then passed `1/1` after adding the direct nontrapping `i32.reinterpret_f32` local-payload shell comparison. Binaryen oracle `.tmp/oi-select-refi31-reinterpret-arms-probe.wat` passed and folded the probed shape.
- Wrap-payload follow-up red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.i31 arms*'` failed `0/1` before implementation on the `i32.wrap_i64` payload case, then passed `1/1` after adding the direct nontrapping `i32.wrap_i64` local-payload shell comparison. Binaryen oracle `.tmp/oi-select-refi31-wrap-arms-probe.wat` passed and folded the probed shape.

## Remaining work

This is an OI-F boolean/select shell sub-slice. It does not close broader `optimizeTernary` parity, structural-expression equality, or effectful-arm select rewrites.
