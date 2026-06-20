---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ./0796-2026-06-20-heap-store-optimization-disappearing-bad-get.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../.tmp/hso-v130-refresh/heap-store-optimization-v130.wast
---

# `heap-store-optimization` external throw and return-call control

Question: how does Binaryen `version_130` classify external `throw` and `return_call` shapes in HSO set values, and does Starshine match that control-flow behavior?

## Answer

Binaryen folds conditional external-exit values into `struct.new` when the only skipped path exits the function. That includes an `if (result i32)` whose taken arm is an uncaught `throw`, and an `if (result i32)` whose taken arm is a `return_call`. Binaryen also folds the `return_call` conditional when the value appears inside an active `try_table`; unlike an ordinary `call`, Binaryen does not treat `return_call` as a catchable in-function throw hazard for HSO movement.

The paired ordinary-call negative from `0794` remains different: an ordinary `call` inside an active catchable region can throw to an in-function catch and skip the delayed local assignment, so Starshine still keeps that `struct.set`.

## Binaryen probes

Local probes against `wasm-opt version 130 (version_130)` used small WAT files under `.tmp/`:

- `.tmp/hso-probe-tail-throw-if.wat`: Binaryen folds both conditional external `throw` and conditional `return_call` set values into `struct.new`.
- `.tmp/hso-probe-return-call-if-catch.wat`: Binaryen folds a conditional `return_call` value even inside a `try_table` with a catch targeting the surrounding label.
- `.tmp/hso-probe-throw-if-catch.wat`: Binaryen keeps the `struct.set` for a conditional `throw` inside that active catch, matching the already-covered ordinary caught-call hazard.

One direct, unconditional `throw` / `return_call` probe did not become a focused contract test because the set operation is unreachable after the external exit and Starshine's HOT lowering can erase dead stack inputs. The source-backed HSO question for this slice is the conditional set-value behavior above, where the set can complete on the non-exiting arm.

## Starshine change

Before this slice, Starshine treated `return_call`, `throw`, `rethrow`, `throw_ref`, and `delegate` as always skipping the delayed fresh-struct local assignment. That was too conservative for function-external conditional exits: it blocked folding the conditional external `throw` and `return_call` positives that Binaryen folds.

The fix narrows two predicates:

- `hso_subtree_may_skip_local_set_from_root(...)` now treats `return`, `return_call*`, `throw*`, and `delegate` as function-external exits that do not create an in-function skipped-local-set hazard by themselves. `unreachable` remains a no-fold boundary.
- `hso_subtree_may_escape_to_active_catch(...)` no longer treats `return_call*` as an active-catch escape for HSO. Ordinary `call*` and `throw*` still block inside active catchable regions.

Focused tests now cover:

- conditional external `throw` folds into `struct.new`;
- conditional external `return_call` folds into `struct.new`;
- conditional `return_call` inside `try_table` folds into `struct.new`;
- the prior ordinary caught-call negative remains covered.

## Evidence

- Red-first focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` failed after adding the three positives. Starshine retained the `struct.set` in all three conditional external-exit shapes.
- Final focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `81/81`.
- `moon fmt` passed.
- `moon info` passed with existing `gen_valid` / `gen_valid_ssa` warnings.
- `moon test src/passes` passed `2709/2709`.
- `moon test` passed `6022/6022`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-external-exits-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, compare-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Remaining HSO-F risk

This closes the focused safe external `throw` / `return_call` classification gap from `0796`. HSO-F still needs broader in-function branch/catch negatives beyond the ordinary caught-call, caught-throw, and escaping branch-valued families already covered. In particular, `throw` inside an active catch remains a Binaryen negative and should be added as a focused guard before HSO-F is closed.
