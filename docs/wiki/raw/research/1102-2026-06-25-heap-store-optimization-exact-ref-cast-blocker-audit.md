---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ./1048-2026-06-25-heap-store-optimization-exact-ref-cast-recheck.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1091-2026-06-25-heap-store-optimization-non-goal-audit.md
  - ./1096-2026-06-25-heap-store-optimization-descriptor-later-field-barrier-audit.md
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO exact descriptor `ref.cast` blocker audit

## Question

After the descriptor branch-result fix in `1041` and the later micro-audits through `1101`, can the exact descriptor `ref.cast` surface be reclassified from a broad HSO residual into a narrow local-surface blocker with explicit reopening criteria?

## Answer

Yes, but only as a **blocker**, not as a semantic non-goal or accepted drift. The exact Binaryen `version_130` behavior remains known from `0869` and `1048`: preserve `struct.new_desc`, preserve the exact descriptor `ref.cast` trap/order point, and keep the later call-valued `struct.set`. Starshine still cannot run that exact surface through direct HSO because binary/local instruction support does not currently expose the same probe to the pass.

This keeps HSO-D/E/F/G/H open for one narrow local-surface item instead of letting exact descriptor casts remain hidden in broad descriptor/control drift wording.

## Evidence map

| Surface | Evidence | Current classification |
| --- | --- | --- |
| Binaryen exact descriptor cast behavior | `0869`, `1048` | Source/probe-backed HSO negative: Binaryen preserves the later `struct.set` when the descriptor operand is `(ref.cast (ref (exact $desc)) (global.get $descg))` and the moved store value is a call. |
| Starshine binary decode | `0869`, `1048` | Blocked before HSO: the exact wasm input still fails with `DecodeAt(InvalidS33Range, 71, 34)`. |
| Local WAT/instruction surface | `0869`; local source spot-check of `src/wast/module_wast.mbt` and `src/wast/keywords.mbt` | The tree exposes descriptor equality spellings such as `ref.cast_desc_eq` / `ref.cast_desc_eq_null`, but prior direct fixture attempts did not validate as an equivalent exact `ref.cast (ref (exact $desc))` descriptor operand. |
| Descriptor branch-result sibling | `1041` | Closed separately: exact descriptor `br_on_non_null` / `struct.new_desc` generated candidates now run, validate, and compare-smoke green. This does not cover exact descriptor `ref.cast`. |
| Explicit non-goal status | `1091` | Not a non-goal: `1091` keeps exact descriptor `ref.cast` as the remaining HSO-H blocker after array-store, generic struct DSE/load-forwarding, direct unreachable, descriptor `br_on_non_null`, direct-root tail-call, and bottom-typed tail-call boundaries were narrowed. |
| Descriptor/later-field barrier audits | `1096`, `1100` | Not covered by nearby audits: pure/effectful/trapping `select` / `if` / block-`br_if`, descriptor `ref.as_non_null`, and result-wrapper surfaces are separate explicit matrices. |

## Narrow blocker statement

The remaining exact descriptor cast work is:

1. make Starshine decode or locally express the exact descriptor-cast operand accepted by Binaryen;
2. add a focused HSO negative proving the later call-valued `struct.set` is preserved like Binaryen; and
3. fix HSO if the newly runnable surface folds across the descriptor-cast trap/order point.

Until one of those happens, this is a tool/local-surface blocker only. It must not be used to approve broad descriptor-expression drift, and it must not be hidden behind the already closed descriptor `br_on_non_null`, descriptor `ref.as_non_null`, `select`/`if`/block-`br_if`, or result-wrapper audits.

## Reopening / closure criteria

Close this blocker only when Starshine can run the exact descriptor-cast probe through HSO and focused coverage proves Binaryen behavior parity. Reopen broader HSO-D/E/F/G/H wording if:

- Binaryen starts folding across exact descriptor `ref.cast`;
- Starshine gains decode support but folds unsafely;
- `ref.cast_desc_eq` becomes a validated equivalent for the exact descriptor-cast probe; or
- another exact descriptor-cast shape appears outside the single call-valued descriptor-operand negative from `0869`/`1048`.

## Validation

Docs/status-only audit. No code changed and no tests were required. The current command evidence is the `1048` recheck; this note only narrows and centralizes the blocker classification after inspecting the current descriptor-related source surface.
