---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0797-2026-06-20-heap-store-optimization-external-exits.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` active-catch `throw` negative coverage

Question: after `0797` relaxed safe external-exit handling for conditional `throw` / `return_call` values and for `return_call` inside active catches, does Starshine still match Binaryen `version_130` for a conditional `throw` inside an active `try_table` catch?

## Answer

Yes. This slice promotes the previously-probed Binaryen `version_130` active-catch `throw` negative into focused Starshine coverage.

Binaryen behavior from `0797` remains the current oracle:

- A conditional `throw` set value with no active in-function catch folds into `struct.new` because the taken throw exits the function.
- A conditional `return_call` set value folds, including inside an active `try_table`, because the return-call exits the function rather than transferring to an in-function catch.
- A conditional `throw` inside a `try_table` catchable by the same function keeps the later `struct.set`, because the thrown path can transfer to the catch and skip the delayed fresh-struct local assignment.

Starshine already preserved this negative after the `0797` implementation: `hso_subtree_may_escape_to_active_catch(...)` still treats `Throw`, `ThrowRef`, and ordinary `Call` / `CallRef` / `CallIndirect` as active-catch escapes while excluding `ReturnCall` / `ReturnCallRef` / `ReturnCallIndirect` from that catch-escape class.

## Local change

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set for throws caught inside the function`

The fixture builds:

- an outer `block`,
- an active `try_table` catching tag `0` to the outer block,
- a fresh `struct.new_default` stored in local `0`,
- a conditional set value whose then arm performs `throw 0`,
- a later `struct.set`,
- and an after-catch read of the target local field.

The expected Starshine/Binaryen behavior is to keep `struct.set` while preserving `try_table` and `throw` in the printed function.

## Evidence

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 82, passed: 82, failed: 0.
```

No implementation code changed in this slice, so no native rebuild or direct 10000-case compare was required for behavior signoff. The latest behavior-changing HSO slice remains `0797`, whose direct 10000-case compare normalized `10000/10000` with `0` mismatches/failures.

## Remaining HSO-F work

This closes the specific active-catch `throw` negative called out after `0797`, but HSO-F is not fully closed. Remaining work should still inspect broader in-function branch/catch negatives where expressible, such as `throw_ref` / legacy rethrow-like surfaces or branch-to-in-function owner labels not already covered by the escaping branch-valued store tests.
