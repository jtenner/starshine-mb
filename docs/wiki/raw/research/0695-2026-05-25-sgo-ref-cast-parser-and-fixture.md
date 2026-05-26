# SGO ref.cast parser prerequisite and fixture

## Scope

`[SGO]003F` prerequisite slice for reference / GC / refinalization breadth in `simplify-globals-optimizing`.

The goal was to remove the previously documented parser-side blocker for ordinary `ref.cast` fixtures and add a minimal validating SGO fixture where a typed `ref.func` global replacement feeds a `ref.cast`.

## Sources checked

- Active backlog: `agent-todo.md` `[SGO]003F`.
- Prior blocker audit: `docs/wiki/raw/research/0656-2026-05-25-sgo-gc-refinalization-blocker-audit.md`.
- Parser/lowering/rendering files:
  - `src/wast/types.mbt`
  - `src/wast/keywords.mbt`
  - `src/wast/lexer.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/wast/module_wast.mbt`
- SGO tests: `src/passes/simplify_globals_optimizing_test.mbt`.

## Changes

- Added ordinary `ref.cast` to the WAST opcode classification path.
- Added `RefCast(ValueType)` to the parsed WAST instruction model.
- Parsed ordinary `ref.cast` reftype immediates with the same immediate grammar already used by ordinary `ref.test`.
- Lowered parsed `RefCast` to `@lib.Instruction::ref_cast(nullable, heap_type)` after verifying the immediate is a reference type.
- Rendered parsed WAST `RefCast` back as `ref.cast <reftype>`.
- Extended the existing ordinary `ref.test` parser and text/binary roundtrip tests to cover `ref.cast (ref i31)` and `ref.cast (ref null eq)`.
- Added a focused SGO regression where `(global.get $g)` from a `(ref null $t)` global initialized with `ref.func $f` feeds `ref.cast (ref $t)`; after SGO, the function body contains `ref.func` and `ref.cast` but no `global.get`, and the pass pipeline validates the result.

## TDD evidence

- Before implementation, `moon test src/wast` failed because the new parser test referenced the missing parsed-instruction constructor `RefCast`.
- After implementation, `moon test src/wast` passed: `378/378`.
- After adding the SGO fixture, `moon test src/passes` passed: `1642/1642` with only the existing DAE/pass-manager unused warnings.
- Standard Moon signoff passed: `moon fmt`, `moon info` (existing DAE unused warnings), and full `moon test` (`3718/3718`, with existing DAE/pass-manager unused warnings).
- Direct SGO fuzz passed the slice criteria at `.tmp/pass-fuzz-sgo-ref-cast-0695-10000`: `6759/10000` compared before the configured 20 Binaryen/tool command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures. The command failures are classified as tool/Binaryen failures because no Starshine output validation failure or semantic mismatch was reported before the configured stop.

## Current boundary

This slice removes blocker item (1) from the 0656 audit and provides a minimal parser-supported validating fixture for the simple `ref.func`-through-`ref.cast` replacement path. It does not claim full `[SGO]003F` completion.

Still deferred:

- broader type-changing replacement and refinalization surfaces;
- typed element item-expression replacement;
- less-refined alias widening;
- object-identity-sensitive GC allocation duplication;
- descriptor-operation and module-wide retagging-sensitive cases.

Those remain under `[SGO]003F` and need separate exact Binaryen-positive fixtures plus paired guardrails.
