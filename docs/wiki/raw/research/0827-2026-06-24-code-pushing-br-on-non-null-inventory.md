---
kind: research
status: supported
last_reviewed: 2026-06-24
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_verify.mbt
---

# Code-pushing `br_on_non_null` inventory

## Question

Can the next `[O4Z-AUDIT-CP]` slice safely mirror the just-landed dropped `br_on_null` movement for `br_on_non_null`?

## Short answer

Binaryen `wasm-opt version 130` does move pure SFA sets after a `br_on_non_null` push point when the value is only used on the fallthrough suffix, and it preserves adjacent multi-set order. A guard-read probe remains stationary.

Starshine should **not** implement this by simply adding `HotOp::BrOnNonNull` to the current code-pushing conditional-branch gate. `br_on_non_null` is branch-payload-carrying even when it has only a guard child: the target label receives the non-null reference on the taken edge. The current HOT verifier computes branch payload arity for `BrOnNonNull` as `child_count - 1`, so a one-child `BrOnNonNull` targeting a one-result block is a broader HOT representation/verification surface than the code-pushing gate alone. Treat this as a prerequisite IR/HOT branch-payload slice or a carefully tested pass+IR slice, not as a code-pushing-only one-line widening.

## Binaryen probes

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Single-set probe:

```wat
(module
  (func (param $r externref) (local $tmp i32)
    (block $exit (result externref)
      (local.set $tmp (i32.const 7))
      (local.get $r)
      (br_on_non_null $exit)
      (drop (local.get $tmp))
      (ref.null extern))
    drop))
```

Observed `wasm-opt --code-pushing -S --all-features -o -` shape:

```wat
(block $exit (result externref)
  (br_on_non_null $exit
    (local.get $r))
  (local.set $tmp
    (i32.const 7))
  (drop
    (local.get $tmp))
  (ref.null noextern))
```

Adjacent multi-set probe:

```wat
(module
  (func (param $r externref) (local $a i32) (local $b i32)
    (block $exit (result externref)
      (local.set $a (i32.const 7))
      (local.set $b (i32.const 9))
      (local.get $r)
      (br_on_non_null $exit)
      (drop (local.get $a))
      (drop (local.get $b))
      (ref.null extern))
    drop))
```

Observed shape moves `$a` then `$b` after `br_on_non_null`, preserving source order.

Guard-read probe:

```wat
(module
  (func (local $tmp externref)
    (block $exit (result externref)
      (local.set $tmp (ref.null extern))
      (local.get $tmp)
      (br_on_non_null $exit)
      (drop (local.get $tmp))
      (ref.null extern))
    drop))
```

Observed shape keeps the `local.set $tmp` before the `br_on_non_null`, so guard reads must remain a movement boundary.

## Starshine implications

Current `src/passes/code_pushing.mbt` already recognizes `BrOnNonNull` as a diagnostic conditional-branch kind, and branch-bearing helpers include it. The mutating conditional-branch support gate currently admits:

- `BrIf` to void block/loop labels with no branch values;
- `BrIf` to one-result block labels with one explicit branch payload;
- dropped `BrOnNull` to zero-arity block/loop labels with one guard child.

A correct `br_on_non_null` slice needs additional HOT/IR proof because the branch-carried reference is implicit in the guard, not an extra payload child. Relevant local surfaces:

- `src/ir/hot_lift.mbt` lowers `Instruction::BrOnNonNull` by computing `payload_count = branch_arity - 1`, popping the guard, and storing children as explicit payload prefix plus guard.
- `src/ir/hot_verify.mbt` currently verifies `BrOnNonNull` using the generic conditional-branch payload rule `actual_arity = child_count - 1` against the target label branch arity.
- Therefore a one-child `BrOnNonNull` targeting a one-result block is not equivalent to a one-child zero-arity `BrOnNull` in HOT verification/accounting.

## Decision for this slice

Do not widen `code_pushing_single_set_conditional_branch_push_point_supported(...)` to `BrOnNonNull` in isolation. Keep `[O4Z-AUDIT-CP]` active with a new explicit blocker: `br_on_non_null` is Binaryen-positive but requires a source-backed HOT branch-payload representation/verification slice before code-pushing mutation and GenValid aggregation.

## Suggested next implementation path

1. Add an IR/HOT red-first fixture that lifts or manually builds the `br_on_non_null` one-result-block shape and proves the intended branch arity/accounting.
2. Fix HOT verification/lowering if needed so `br_on_non_null`'s implicit taken-edge non-null payload is modeled correctly.
3. Add code-pushing red-first tests for single-set, adjacent multi-set, and guard-read boundary movement.
4. Only then consider a targeted GenValid leaf; keep it out of `code-pushing-all` until compare output is aggregate-safe.
