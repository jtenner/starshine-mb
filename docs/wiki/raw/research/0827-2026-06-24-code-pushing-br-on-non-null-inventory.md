---
kind: research
status: supported
last_reviewed: 2026-06-24
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/ir/hot_verify.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing `br_on_non_null` movement

## Question

Can `[O4Z-AUDIT-CP]` mirror Binaryen `version_130` movement after `br_on_non_null` without losing the implicit taken-edge reference payload?

## Short answer

Yes, for a bounded one-result block-label subset. Binaryen `wasm-opt version 130` moves pure SFA sets after a `br_on_non_null` push point when the moved locals are only used on the fallthrough suffix, and it preserves adjacent multi-set order. A guard-read probe remains stationary.

Starshine now implements the same bounded subset after fixing HOT branch payload arity for `BrOnNonNull`: the guard child itself accounts for the implicit final taken-edge non-null reference payload. The code-pushing mutating gate admits only `BrOnNonNull` with one guard child targeting a one-result block label; broader loop labels, explicit prefix payloads, `br_on_cast`, and other reference-carrying branch forms remain open.

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

Observed shape keeps the `local.set $tmp` before the `br_on_non_null`, so guard reads remain a movement boundary.

## Starshine implementation

The enabling IR fix is in `src/ir/hot_verify.mbt`: `hot_verify_branch_payload_arity(...)` now treats `BrOnNonNull` specially. For conditional branches in general, the last child is a guard and not a branch payload. For `BrOnNonNull`, the last child is both the tested guard and the implicit final taken-edge payload, so the actual branch arity is `child_count`, not `child_count - 1`.

The code-pushing widening is in `src/passes/code_pushing.mbt`: `code_pushing_single_set_conditional_branch_push_point_supported(...)` now accepts `BrOnNonNull` only when it targets a block label with branch arity `1` and exactly one child. Existing whole-root local accounting rejects guard operands that read moved locals, and the ordered multi-set helper reuses the same gate to preserve source order.

Focused HOT tests were added because the WAT parser surface still cannot cover the comparable `br_on_*` shapes reliably in the pass tests:

- single pure SFA set moves after one-result-block `BrOnNonNull`;
- two adjacent local-independent SFA sets move after it in source order;
- guard-read boundary remains stationary.

The dedicated GenValid profile now includes aggregate-safe `code-pushing-br-on-non-null`, and `code-pushing-all` grows from 14 to 15 leaves.

## Retained boundaries

- `BrOnNonNull` loop labels are not widened in this slice.
- Prefix payload variants for labels with more than one result are not widened.
- `br_on_cast`, `br_on_cast_fail`, and other reference-carrying conditional branch forms remain open.
- WAT parser coverage for these pass fixtures remains a future improvement; the committed pass tests use direct HOT construction.
- The separate value-`br_if` HOT-lowering temporary-local representation gap remains open, so `code-pushing-br-if-value` stays targeted-only and excluded from `code-pushing-all`.

## Evidence

- Red-first focused `moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_non_null*'` failed before implementation with `InvalidBranchArity(... actual 0, expected 1)`, proving the HOT payload accounting gap.
- After the HOT verifier and code-pushing gate changes, focused `*br_on_non_null*` passed `3/3`.
- Focused `moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'` passed `3/3` after adding the GenValid leaf.
- `moon fmt`, `moon info --target native`, full focused `moon test src/passes/code_pushing_test.mbt --target native`, and `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Aggregate-safe `code-pushing-all` compare with `--normalize local-cleanup-debris` in `.tmp/pass-fuzz-code-pushing-br-on-non-null-aggregate-1000` compared `1000/1000`, normalized `473`, cleanup-normalized `527`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, and selected `code-pushing-br-on-non-null: 59` plus every other aggregate-safe leaf.
