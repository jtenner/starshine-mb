# FUZ1037R3 descriptor-bearing const initializers

Date: 2026-05-31

## Slice

`[FUZ]1037R3` asked for a concrete valid initializer-expression fixture involving descriptor/describes GC reference types without inventing invalid descriptor behavior.

## Change

GenValid now covers the local custom-descriptor initializer surface by building a descriptor-bearing struct in a global initializer:

- coverage-forced imports reserve enough immutable globals for the existing `i32`, reference, `i64`, and descriptor-reference const-expression lanes when the import budget allows it;
- the coverage-forced global lane can choose an exact non-null reference to the descriptor-bearing described struct;
- `gen_valid_const_expr_for_global(...)` recognizes that described target and, when an immutable exact descriptor global is visible, emits `global.get <descriptor>; struct.new_default_desc <described>`.

This stays inside Starshine's existing local validator policy: `struct.new_default_desc` was already accepted in constant expressions, and the descriptor/describes pair is the already-supported struct metadata shape. No invalid descriptor semantics were added.

## TDD evidence

Focused tests in `src/validate/gen_valid_tests.mbt` were added before implementation:

- `gen-valid global initializer can build descriptor-bearing structs from descriptor globals` first failed because the helper returned a typed `ref.null` instead of the descriptor constructor sequence.
- `gen-valid coverage-forced globals include descriptor-bearing initializer` first failed because the generated module did not contain a `global.get; struct.new_default_desc` global initializer.

After implementation, `moon test src/validate` passed with `1501` tests.

## Classification

This closes `[FUZ]1037R3` for the current v0.1.0 GenValid surface. The fixture is a valid-generator widening, not a validator behavior change. Remaining FUZ1037 work is `[FUZ]1037R4` context/op feature-fact attribution and `[FUZ]1037R5` closeout.
